#!perl

use strict;
use Test::More;
use Net::XMPP2::TestClient;
use Net::XMPP2::IM::Message;
use Net::XMPP2::Util qw/bare_jid split_jid/;
use Net::XMPP2::Ext::Registration;

my $cl =
   Net::XMPP2::TestClient->new_or_exit (
      tests        => 2,
      two_accounts => 1,
      finish_count => 2
   );
my $C = $cl->client;

my $reg_error   = "";
my $unregistered = 0;

$C->reg_cb (
   session_ready => sub {
      my ($C, $acc) = @_;
      my ($username) = split_jid ($acc->bare_jid);
      my $con = $acc->connection;

      my $reg = Net::XMPP2::Ext::Registration->new (connection => $con);

      $reg->send_unregistration_request (sub {
         my ($reg, $ok, $error, $form) = @_;

         if ($ok) {
            $unregistered++;
         } else {
            $reg_error = $error->string;
         }

         $cl->finish;
      });
   },
);

$cl->wait;

is ($unregistered, 2, "registered 2 accounts");
is ($reg_error, '', 'no registration error');
if ($reg_error) {
   diag (
      "Error in registration: "
      . $reg_error
      . ", please register two accounts yourself for the next tests."
   );
}
