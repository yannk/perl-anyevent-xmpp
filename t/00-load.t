#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Net::XMPP2' );
}

diag( "Testing Net::XMPP2 $Net::XMPP2::VERSION, Perl $], $^X" );
