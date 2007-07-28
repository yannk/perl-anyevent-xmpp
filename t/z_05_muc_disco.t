#!perl

use strict;
no warnings;
use Test::More;
use Net::XMPP2::TestClient;
use Net::XMPP2::IM::Message;
use Net::XMPP2::Util qw/bare_jid/;
use Net::XMPP2::Ext::MUC;

my $cl =
   Net::XMPP2::TestClient->new_or_exit (tests => 1, two_accounts => 1, finish_count => 2);
my $C     = $cl->client;
my $disco = $cl->instance_ext ('Net::XMPP2::Ext::Disco');
my $muc;

$C->reg_cb (
   session_ready => sub {
      my ($C, $acc) = @_;
      my $con = $acc->connection;
      $con->add_extension (
         $muc = Net::XMPP2::Ext::MUC->new (disco => $disco, connection => $con)
      );
      $cl->finish;
   }
);

$cl->wait;

ok ($muc, "MUC extension initialized");
