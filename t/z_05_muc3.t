#!perl

use strict;
no warnings;
use Test::More;
use Net::XMPP2::TestClient;
use Net::XMPP2::IM::Message;
use Net::XMPP2::Util qw/bare_jid prep_bare_jid split_jid cmp_jid/;
use Net::XMPP2::Ext::MUC;

my $cl =
   Net::XMPP2::TestClient->new_or_exit (
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
