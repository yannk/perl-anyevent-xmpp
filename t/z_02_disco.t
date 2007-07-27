#!perl

use strict;
use Test::More;
use Net::XMPP2::TestClient;
use Net::XMPP2::IM::Message;
use Net::XMPP2::Util qw/bare_jid/;

my $cl =
   Net::XMPP2::TestClient->new_or_exit (
      tests => 2, two_accounts => 1, finish_count => 2
   );
my $C = $cl->client;
my $disco = $cl->instance_ext ('Net::XMPP2::Ext::Disco');
$disco->set_identity (client => bot => "net xmpp2 test");

my $disco_error = '';

$C->reg_cb (
   two_accounts_ready => sub {
      my ($C, $acc, $jid1, $jid2) = @_;
      my $con = $C->get_account ($jid1)->connection;

      $disco->request_info ($con, $jid2, undef, sub {
         my ($disco, $info, $error) = @_;
         if ($error) {
            $disco_error = $error->string;
         } else {
            my (@ids) = $info->identities ();
            ok (
               (grep {
                  $_->{category} eq 'client'
                  && $_->{type} eq 'bot'
                  && $_->{name} eq 'net xmpp2 test'
               } @ids),
               "has bot identity"
            );
            ok (
               (grep {
                  $_->{category} eq 'client'
                  && $_->{type} eq 'console'
                  && $_->{name} eq 'net xmpp2 test'
               } @ids),
               "has default identity"
            );
         }
         $cl->finish;
      });

      $cl->finish;
   }
);

$cl->wait;
