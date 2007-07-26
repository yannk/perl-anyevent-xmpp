#!perl -T

my @MODULES = qw/
Net::XMPP2::IM::Contact
Net::XMPP2::IM::Roster
Net::XMPP2::IM::Connection
Net::XMPP2::IM::Presence
Net::XMPP2::IM::Account
Net::XMPP2::IM::Message
Net::XMPP2::Ext::Disco::Info
Net::XMPP2::Ext::Disco::Items
Net::XMPP2::Ext::DataForm
Net::XMPP2::Ext::OOB
Net::XMPP2::Ext::Pubsub
Net::XMPP2::Ext::Registration
Net::XMPP2::Ext::Disco
Net::XMPP2::Ext::RegisterForm
Net::XMPP2::Namespaces
Net::XMPP2::Util
Net::XMPP2::Ext
Net::XMPP2::Error::SASL
Net::XMPP2::Error::IQ
Net::XMPP2::Error::Register
Net::XMPP2::Error::Exception
Net::XMPP2::Error::Stanza
Net::XMPP2::Error::Stream
Net::XMPP2::Error::Parser
Net::XMPP2::Error::Presence
Net::XMPP2::Error::Message
Net::XMPP2::Event
Net::XMPP2::Client
Net::XMPP2::SimpleConnection
Net::XMPP2::Extendable
Net::XMPP2::Writer
Net::XMPP2::Component
Net::XMPP2::Parser
Net::XMPP2::Connection
Net::XMPP2::Error
Net::XMPP2::Node
Net::XMPP2
/;

use Test::More;
plan tests => scalar @MODULES;
use_ok $_ for @MODULES;

diag( "Testing Net::XMPP2 $Net::XMPP2::VERSION, Perl $], $^X" );

