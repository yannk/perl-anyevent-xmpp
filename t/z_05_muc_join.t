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
      tests => 2, two_accounts => 1, muc_test => 1, finish_count => 1
   );
my $C = $cl->client;

my ($nickjids, $users_r1, $users_r2) = ("nonickjids", "nousers", "nootherusers");

$C->reg_cb (
   two_rooms_joined => sub {
      my ($C, $acc, $jid1, $jid2, $room1, $room2) = @_;
      $nickjids = join '', sort ($room1->nick_jid, $room2->nick_jid);
      $users_r1 = join '', sort map { $_->jid } $room1->users;
      $users_r2 = join '', sort map { $_->jid } $room1->users;
      $cl->finish;
   }
);

$cl->wait;

is ($users_r1, $nickjids, 'room only has our two test bots');
is ($users_r1, $users_r2, 'the room lists match for both extensions');
