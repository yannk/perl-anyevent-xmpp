#!perl

use strict;
no warnings;
use Test::More;
use Net::XMPP2::TestClient;
use Net::XMPP2::IM::Message;
use Net::XMPP2::Util qw/bare_jid prep_bare_jid split_jid cmp_jid/;
use Net::XMPP2::Ext::MUC;

my $MUC = $ENV{NET_XMPP2_TEST_MUC};

unless ($MUC) {
   plan skip_all => "environment var NET_XMPP2_TEST_MUC not set! Set it to a conference!";
   exit;
}

my $ROOM = "test_netxmpp2@".$MUC;

my $cl =
   Net::XMPP2::TestClient->new_or_exit (
      tests => 1, finish_count => 1
   );
my $C     = $cl->client;
my $disco = $cl->instance_ext ('Net::XMPP2::Ext::Disco');

my $muc_is_conference     = 0;
my $muc;

$C->reg_cb (
   before_session_ready => sub {
      my ($C, $acc) = @_;
      my $con = $acc->connection;
      $con->add_extension (
         $muc = Net::XMPP2::Ext::MUC->new (disco => $disco, connection => $con)
      );
   },
   session_ready => sub {
      my ($C, $acc, $jid1, $jid2) = @_;
      $muc->is_conference ($MUC, sub {
         my ($conf, $err) = @_;
         if ($conf) { $muc_is_conference = 1 }
         $cl->finish
      });
   }
);


$cl->wait;

ok ($muc_is_conference           , "detected a conference");
