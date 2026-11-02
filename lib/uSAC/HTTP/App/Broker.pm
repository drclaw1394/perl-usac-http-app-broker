# FastPack application (web client)
#package uSAC::FastPack::Broker::App;
package uSAC::HTTP::App::Broker;
=head1 NAME

uSAC::HTTP::App::Broker - Web server interface  and files for uSAC::HTTP::App::Broker

=cut

use v5.36;

use feature ":all";
our $VERSION="v0.1.0";


##############
# Server side
# ############
use uSAC::HTTP::Middleware::Bridge::WS;
use uSAC::HTTP;
use uSAC::HTTP::Site;
use uSAC::HTTP::Rex;
use uSAC::IO;

# Server side

use Object::Pad;

class uSAC::HTTP::App::Broker;

field $_parent :param;

field $_site;
field $_clients_list;
field $_clients
field $_broker;


BUILD {
  $_clients_list=[];
  $_clients={};


  # Create a site to add to parent
  $_site=uSAC::HTTP::Site->new(id=>"FastPack", delegate=>$self, prefix=>"fastpack/");
  $_parent->add($_site);

  $_broker=$_site->build_broker;

  $_site->add("ws", "_ws");

}

method _ws {
  sub {
    (
      uhm_bridge_ws(),
      sub {
        my $bridge= $_[PAYLOAD][0]; 
        my $broker= $_[PAYLOAD][1]; 
        $broker->broadcast(undef, "bridge_ws", $bridge);

        asay $STDERR, "CREATED BRIDGE TO CLIENT VIA WEBSOCKET broker: $broker  with bridge $bridge";

        # Forward local generated messages that match this to the client
        $broker->listen(undef, "test",    $bridge);
        $broker->listen(undef, "return",  $bridge);

        $broker->listen(undef,  "test", sub {
            adump $STDERR, "from broker on ws $bridge! ", @_;
            #$bridge->forward_message_sub->([undef,[[time, "return", pack "D", 1234]]]);
            $broker->broadcast(undef, "return", pack "D", 1234);
          }
        );                                                                                                               #
        undef;
      }


    )
  }

}



sub app {
  sub {
    my $parent_site=shift;
    my %options=@_;
    #uSAC::FastPack::Broker::App->new(parent=>$parent_site, %options);
    uSAC::HTTP::App::Broker->new(parent=>$parent_site, %options);
  }
}




##################
# Client side 
##################

use Data::JPack;
#use uSAC::HTTP::App::Broker;
use Template::Plexsite;

use uSAC::HTTP::App::FastPack;

use File::Path qw<make_path>;
use File::Basename qw<dirname>;

use File::ShareDir ":ALL";
my $share_dir=dist_dir "uSAC-HTTP-App-Broker";


# Return the paths of sourse files
sub js_paths {
  asay $STDERR, "GETTING JS PATHS FOR ".__PACKAGE__;
  grep !/test/, <$share_dir/js/*>;
}

# or we add the file to the dir directly
sub add_to_jpack_container {
  my $html_container=shift;



  # Given the html_container encode the js and resource files into the next available position
  #
  my $jpack=Data::JPack->new(jpack_compression=>"DEFLATE", jpack_type=>"app", html_container=>$html_container);


  $jpack->set_prefix("app/jpack/main");

  my @outputs;
  for(js_paths){
    asay $STDERR, __PACKAGE__ . " adding js: ", $_;
    my $out_path=$jpack->next_file_name($_);
    next unless $out_path;

    asay $STDERR, __PACKAGE__." OUTPUT PATH IS (broker app) $out_path";

    $jpack->encode_file($_,$out_path);
    push @outputs, $out_path;    #
  }
  @outputs;
}

sub add_to_container {
  my (undef, $t, $options)=@_;

  # We don't want recusion here
  return if $options->{__shared_count__};

  return unless $t isa Template::Plexsite;
  asay $STDERR, "----CALLED add_to_container in Broker $options";
  
  uSAC::HTTP::App::FastPack->add_to_container($t, $options);
  

  # Add shared broker support
  #use uSAC::HTTP::App::Broker::Shared;
  
  #uSAC::HTTP::App::Broker::Shared->add_to_container($t, $options);

  uSAC::HTTP::App::JPack->localize_table ($t, sub {

    my ($t, $opts)=@_;
    
    my @paths=(js_paths);
    for(@paths){
      asay $STDERR, "--adding path for broker: $_";
      adump $STDERR,$opts;

      $t->add_resource($_,  $opts);
    }
  },
  $options
);
}

sub template_path {
  (undef, $share_dir);
}

__PACKAGE__

