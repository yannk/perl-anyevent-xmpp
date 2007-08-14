#!perl

use strict;
no warnings;
use Test::More;
use Net::XMPP2;
use Net::XMPP2::Namespaces qw/xmpp_ns/;
use Net::XMPP2::TestClient;
use Net::XMPP2::IM::Message;
use Net::XMPP2::Util qw/bare_jid/;

my $cl =
   Net::XMPP2::TestClient->new_or_exit (tests => 3, two_accounts => 1, finish_count => 2);
my $C = $cl->client;
my $disco = $cl->instance_ext ('Net::XMPP2::Ext::Disco');
my $ping  = $cl->instance_ext ('Net::XMPP2::Ext::Ping');
$ping->auto_timeout (1);

$disco->enable_feature ($ping->disco_feature);

my $ping_error = '';
my $response_time;
my $feature = 0;

$C->reg_cb (
   two_accounts_ready => sub {
      my ($C, $acc, $jid1, $jid2) = @_;
      my $con = $C->get_account ($jid1)->connection;

      $disco->request_info ($con, $jid2, undef, sub {
         my ($disco, $info, $error) = @_;
         $feature = ! ! ($info->features->{xmpp_ns ('ping')});
         $cl->finish;
      });

      $ping->ping ($con, $jid2, sub {
         my ($time, $error) = @_;
         if ($error) {
            $ping_error = $error->string;
         }
         $response_time = $time;
         $cl->finish;
      });
   }
);

$cl->wait;

is ($ping_error,         '', 'no ping error');
ok ($feature               , 'ping feature advertised');
ok ($response_time > 0.0001, 'got a reasonable response time');
