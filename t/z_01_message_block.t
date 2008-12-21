#!perl

use strict;
no warnings;
use Test::More;
use AnyEvent::XMPP::TestClient;
use AnyEvent::XMPP::IM::Message;
use AnyEvent::XMPP::Util qw/bare_jid/;

my $cl =
   AnyEvent::XMPP::TestClient->new_or_exit (
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

      my $msg = AnyEvent::XMPP::IM::Message->new (
         body    => "test body",
         type    => 'normal',
         to      => $jid2,
      );

      $C->reg_cb (send_buffer_empty => sub {
         my ($C) = @_;
         $C->unreg_me;
         $con->disconnect ("done sending");
      });

      $msg->send ($con);
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
