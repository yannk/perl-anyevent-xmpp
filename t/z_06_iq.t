#!perl

use strict;
no warnings;
use Test::More;
use Net::XMPP2;
use Net::XMPP2::TestClient;
use Net::XMPP2::IM::Message;
use Net::XMPP2::Util qw/bare_jid/;

my $cl =
   Net::XMPP2::TestClient->new_or_exit (tests => 3, two_accounts => 1, finish_count => 2);
my $C = $cl->client;
my $vers = $cl->instance_ext ('Net::XMPP2::Ext::Version');

$vers->set_os ('GNU/Virtual 0.23 x86_128');

my $recv_error;
my $recv_vers_error = '';
my $recv_vers;

my $dest;

$C->reg_cb (
   two_accounts_ready => sub {
      my ($C, $acc, $jid1, $jid2) = @_;
      my $con = $C->get_account ($jid1)->connection;

      $dest = $jid2;

      $vers->request_version ($con, $jid2, sub {
         my ($version, $error) = @_;

         if ($error) {
            $recv_error = $error;

         } else {
            $recv_vers =
               sprintf "(%s) %s/%s/%s",
                  $version->{jid}, $version->{name}, $version->{version}, $version->{os};
         }
         $cl->finish;
      });

      $con->send_iq ('get', {
         defns => 'broken:iq:request',
         node => { ns => 'broken:iq:request', name => 'query' }
      }, sub {
         my ($n, $e) = @_;
         $recv_error = $e;
         $cl->finish;
      }, to => $jid2);
   }
);

$cl->wait;

if ($recv_error) {
   is ($recv_error->condition (), 'service-unavailable', 'service unavailable error');
} else {
   fail ('service unavailable error');
}
is ($recv_vers_error         , ''                   , 'no software version error');
is ($recv_vers,
    "($dest) Net::XMPP2/$Net::XMPP2::VERSION/GNU/Virtual 0.23 x86_128",
    'software version reply');
