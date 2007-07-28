#!perl

use strict;
no warnings;
use Test::More;
use Net::XMPP2::TestClient;
use Net::XMPP2::IM::Message;
use Net::XMPP2::Util qw/bare_jid prep_bare_jid split_jid/;

my $cl =
   Net::XMPP2::TestClient->new_or_exit (
      tests => 7, two_accounts => 1, finish_count => 2
   );
my $C = $cl->client;

my ($src, $dest);

my $received_subscribe = 0;
my $mutual_subscribe = 0;
my $subscriptions = 0;
my $unsubscriptions = 0;

my $dest_src_subs = '';
my $src_dest_subs = '';

sub jid_user($) { my ($u) = split_jid $_[0]; $u }

$C->reg_cb (
   two_accounts_ready => sub {
      my ($C, $acc, $jid1, $jid2) = @_;
      my $con1 = $C->get_account ($src  = $jid1)->connection;
      my $con2 = $C->get_account ($dest = $jid2)->connection;
      $src = prep_bare_jid $src;
      $dest = prep_bare_jid $dest;

      $con1->get_roster ()->new_contact ($jid2, undef, "friend", sub {
         my ($con, $err) = @_;
         ok ($con, "roster push");
         if ($con) {
            $con->send_subscribe
         }
      });
   },
   contact_request_subscribe => sub {
      my ($C, $acc, $roster, $contact) = @_;

      if ($acc->bare_jid eq $dest) {
         $received_subscribe = 1;
         $contact->send_subscribed;
         $contact->send_subscribe;

      } elsif ($acc->bare_jid eq $src) {
         $mutual_subscribe = 1;
         $contact->send_subscribed;
      }
   },
   contact_unsubscribed => sub {
      my ($C, $acc, $roster, $contact) = @_;
      $unsubscriptions++;

      if ($contact->subscription eq 'from') {
         $contact->send_unsubscribed;
      }

      $cl->finish;
   },
   contact_subscribed => sub {
      my ($C, $acc, $roster, $contact) = @_;
      $subscriptions++;

      if ($acc->bare_jid eq $src) {
         $dest_src_subs = prep_bare_jid ($contact->jid);
      } else {
         $src_dest_subs = prep_bare_jid ($contact->jid);
      }

      if ($subscriptions >= 2) {
         $contact->send_unsubscribed;
      }
   }
);

$cl->wait;

ok ($received_subscribe, "received subscription request");
ok ($mutual_subscribe,   "mutual subscription ok");
is ($subscriptions, 2, "got two subscriptions");
is ($unsubscriptions, 2, "got two unsubscriptions");
is ($dest_src_subs, $dest, "destination subscribed to source");
is ($src_dest_subs, $src, "source subscribed to destination");
