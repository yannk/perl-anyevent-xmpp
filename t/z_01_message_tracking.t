#!perl

use strict;
no warnings;
use Test::More;
use Net::XMPP2::TestClient;
use Net::XMPP2::IM::Message;
use Net::XMPP2::Util qw/prep_bare_jid bare_jid cmp_bare_jid/;

my $cl =
   Net::XMPP2::TestClient->new_or_exit (tests => 1, two_accounts => 1, finish_count => 2);
my $C = $cl->client;

my ($src, $dest, $src_full, $dest_full);
my $message_conv = "";

my @seq = (
   sub {
      my ($srcacc, $destacc, $msg, $msg_from_src) = @_;

      if ($msg_from_src) {
         my $repl = $msg->make_reply;
         $repl->add_body ($msg->any_body () . $msg->to . "\n");
         $destacc->send_tracked_message ($repl);
      }
   },
   sub {
      my ($srcacc, $destacc, $msg, $msg_from_src) = @_;

      if (!$msg_from_src) {
         my $repl = $msg->make_reply;
         $repl->add_body ($msg->any_body () . $msg->to . "\n");
         $srcacc->send_tracked_message ($repl);
      }
   },
   sub {
      my ($srcacc, $destacc, $msg, $msg_from_src) = @_;

      if ($msg_from_src) {
         my $repl = $msg->make_reply;
         $repl->add_body ($msg->any_body () . $msg->to . "\nend\n");
         $destacc->send_tracked_message ($repl);
      }
   },
   sub {
      my ($srcacc, $destacc, $msg, $msg_from_src) = @_;

      if (!$msg_from_src) {
         $message_conv = $msg->any_body;
         $cl->finish;
      }
   },
);

$C->reg_cb (
   two_accounts_ready => sub {
      my ($C, $acc, $jid1, $jid2) = @_;
      my $srcacc = $C->get_account ($jid1);

      $src  = prep_bare_jid $jid1;
      $dest = prep_bare_jid $jid2;
      $src_full  = $jid1;
      $dest_full = $jid2;

      my $msg = Net::XMPP2::IM::Message->new (
         body    => "start\n",
         to      => $dest,
         type    => 'chat',
      );

      $srcacc->send_tracked_message ($msg);
      $cl->finish;
   },
   message => sub {
      my ($C, $acc, $msg) = @_;
      my $sacc = $C->get_account ($src);
      my $dacc = $C->get_account ($dest);

      if (my $seq = shift @seq) {
        $seq->($sacc, $dacc, $msg, cmp_bare_jid ($msg->from, $src));
      } else {
        $cl->finish;
      }
   }
);

$cl->wait;

is ($message_conv,
   "start\n"
   .$dest."\n"
   .$src_full."\n"
   .$dest_full."\n"
   ."end\n",
   "conversation had expected results"
);
