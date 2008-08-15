#!perl

use strict;
no warnings;
use Test::More;
use AnyEvent::XMPP::TestClient;
use AnyEvent::XMPP::IM::Message;
use AnyEvent::XMPP::Util qw/bare_jid prep_bare_jid split_jid cmp_jid/;
use AnyEvent::XMPP::Ext::MUC;

my $cl =
   AnyEvent::XMPP::TestClient->new_or_exit (
      tests => 1, two_accounts => 1, muc_test => 1, finish_count => 1
   );
my $C = $cl->client;

my $newsubject = '';

$C->reg_cb (
   two_rooms_joined => sub {
      my ($C, $acc, $jid1, $jid2, $room1, $room2) = @_;
      $room2->reg_cb (
         subject_change => sub {
            my ($room2, $msg, $is_echo) = @_;
            return if $is_echo;
            $newsubject = $msg->any_subject;
            $cl->finish;
         }
      );
      $room1->change_subject ("TEST ABC");
   }
);

$cl->wait;

is ($newsubject, 'TEST ABC', "subject has been changed");
