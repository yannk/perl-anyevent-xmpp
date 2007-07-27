#!perl

use strict;
no warnings;
use Test::More;
use Net::XMPP2::TestClient;
use Net::XMPP2::IM::Message;
use Net::XMPP2::Util qw/bare_jid/;

my $cl =
   Net::XMPP2::TestClient->new_or_exit (tests => 6, two_accounts => 1, finish_count => 2);
my $C = $cl->client;

my ($src, $dest);
my $recv_message = "";

$C->reg_cb (
   two_accounts_ready => sub {
      my ($C, $acc, $jid1, $jid2) = @_;
      my $con = $C->get_account ($jid1)->connection;

      $src  = bare_jid $jid1;
      $dest = bare_jid $jid2;

      my $msg = Net::XMPP2::IM::Message->new (
         body    => "test body",
         to      => $jid2,
         subject => "Just a test",
         type    => 'headline',
      );

      $msg->send ($con);
      $cl->finish;
   },
   message => sub {
      my ($C, $acc, $msg) = @_;

      if (bare_jid ($msg->from) eq $src) {
         is ($acc->bare_jid,        $dest,         "arriving destination");
         is (bare_jid ($msg->from), $src,          "message source");
         is (bare_jid ($msg->to),   $dest,         "message destination");
         is ($msg->type,            'headline',    "message type");
         is ($msg->any_subject,     'Just a test', "message subject");
         is ($msg->any_body,        'test body',   "message body");

         $cl->finish;
      }
   }
);

$cl->wait;
