#!perl
use strict;
use Test::More tests => 1;
use Net::XMPP2::Util qw/filter_xml_chars/;

is (filter_xml_chars ("BB\a\bAA"), "BBAA", "filters out bad chars");
