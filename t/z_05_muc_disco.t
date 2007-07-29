#!perl

use strict;
no warnings;
use Test::More;
use Net::XMPP2::TestClient;
use Net::XMPP2::IM::Message;
use Net::XMPP2::Util qw/bare_jid prep_bare_jid/;
use Net::XMPP2::Ext::MUC;

my $MUC = $ENV{NET_XMPP2_TEST_MUC};

unless ($MUC) {
   plan skip_all => "environment var NET_XMPP2_TEST_MUC not set! Set it to a conference!";
   exit;
}

my $cl =
   Net::XMPP2::TestClient->new_or_exit (tests => 2, two_accounts => 1, finish_count => 1);
my $C     = $cl->client;
my $disco = $cl->instance_ext ('Net::XMPP2::Ext::Disco');

my %muc;

my $muc_is_conference     = 0;
my $recv_presence_for_muc = 0;
my $muc_join_error        = '';
my $muc_joined_cb         = 0;
my $muc_joined_ev         = 0;

$C->reg_cb (
   before_session_ready => sub {
      my ($C, $acc) = @_;
      my $con = $acc->connection;
      $con->add_extension (
         $muc{$acc->bare_jid} =
            Net::XMPP2::Ext::MUC->new (disco => $disco, connection => $con)
      );
   },
   two_accounts_ready => sub {
      my ($C, $acc, $jid1, $jid2) = @_;
      $muc{$acc->bare_jid}->is_conference ($MUC, sub {
         my ($conf, $err) = @_;
         if ($conf) { $muc_is_conference = 1 }

         step_join_rooms ($C, \%muc, $jid1, $jid2);
      });
   },
   presence_xml => sub {
      my ($C, $acc, $node) = @_;
      if (prep_bare_jid ($node->attr ('from')) eq prep_bare_jid $MUC) {
         $recv_presence_for_muc = 1
      }
   }
);

sub step_join_rooms {
   my ($C, $mucs, $jid1, $jid2) = @_;

   $mucs->{prep_bare_jid $jid1}->reg_cb (
      room_enter => sub {
         $muc_joined_ev++;
      }
   );

   $mucs->{prep_bare_jid $jid1}->join_room ("test@".$MUC, 'occupant1', sub {
      my ($error) = @_;
      if ($error) {
         $muc_join_error = $error->string;
      } else {
         $muc_joined_cb++;
      }
   });
}



$cl->wait;

is ((scalar keys %muc), 2,   "MUC extensions initialized");
ok ($muc_is_conference,      "detected a conference");
ok (!$recv_presence_for_muc, "no presence for the room in the main handlers");
is ($muc_join_error, '',     "no join error");
is ($muc_joined_cb, 1,       "joined MUC two times (callback)");
is ($muc_joined_ev, 1,       "joined MUC two times (event)");
