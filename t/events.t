#!perl
use strict;
use Test::More tests => 5;
use Net::XMPP2::Event;
use Scalar::Util qw/weaken/;

my $ev = Net::XMPP2::Event->new;

my $a = {};

my $b = $a;
weaken $b;

my $cb_call_cnt = 0;

$ev->reg_cb (
   _while_referenced => $a,
   test => sub { $a->{test} .= "BBB"; $cb_call_cnt++ }
);

$a->{test} = "AAA";
$ev->event ('test');

ok ($ev->events_as_string_dump =~ /test:\s*1/, "events in before undef");
is ($a->{test}, "AAABBB", "callback adjusted our object");

undef $a;

ok ($ev->events_as_string_dump =~ /test:\s*1/, "events in after undef");

$ev->event ('test');

ok ($ev->events_as_string_dump !~ /test:\s*1/, "no events in after undef and call");
is ($cb_call_cnt, 1, "callback called once only");
