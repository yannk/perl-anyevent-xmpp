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
      tests => 2, two_accounts => 1, muc_test => 1, finish_count => 1
   );
my $C = $cl->client;

my ($nickjids, $users_r1, $users_r2) = ("nonickjids", "nousers", "nootherusers");

$C->reg_cb (
   two_rooms_joined => sub {
      my ($C) = @_;
      $nickjids = join '', sort ($cl->{room}->nick_jid, $cl->{room2}->nick_jid);
      $users_r1 = join '', sort map { $_->jid } $cl->{room}->users;
      $users_r2 = join '', sort map { $_->jid } $cl->{room2}->users;
      $cl->finish;
   }
);

$cl->wait;

is ($users_r1, $nickjids, 'room only has our two test bots');
is ($users_r1, $users_r2, 'the room lists match for both extensions');
