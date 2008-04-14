#!perl

use strict;
no warnings;
use Test::More;
use Net::XMPP2::TestClient;
use Net::XMPP2::IM::Message;
use Net::XMPP2::Util qw/bare_jid/;

my $cl =
   Net::XMPP2::TestClient->new_or_exit (
      tests => 2,
      two_accounts => 1,
      finish_count => 2
   );
my $C = $cl->client;

my $src;
my $recv_message = "";
my $dconmsg      = "";

$C->reg_cb (
   two_accounts_ready => sub {
      my ($C, $acc, $jid1, $jid2) = @_;
      my $con = $C->get_account ($jid1)->connection;

      $src  = bare_jid $jid1;

      my $msg = Net::XMPP2::IM::Message->new (
         body    => "test body",
         type    => 'normal',
         to      => $jid2,
      );

      $msg->send ($con);
      $con->drain;
      $con->disconnect ("done sending");
   },
   disconnect => sub {
      my ($C, $acc, $h, $p, $msg) = @_;
      $dconmsg = $msg;
      $cl->finish;
   },
   message => sub {
      my ($C, $acc, $msg) = @_;

      if (bare_jid ($msg->from) eq $src) {
         is ($msg->any_body, 'test body', "message body");
         $cl->finish;
      }
   }
);

$cl->wait;

is ($dconmsg, "done sending", "disconnect message was ok");
