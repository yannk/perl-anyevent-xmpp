package EVQ;
use strict;
use AnyEvent;

my $J;

our %reqh;
our $id = 0;
my @req;

sub schedule {
   my $reqcnt = scalar (keys %reqh);
   if ($reqcnt == 0 && !@req) {
      print "no more jobs, finishing...\n";
      $J->broadcast;
   }
   while ($reqcnt < 20) {
      my $r = pop @req;
      return unless defined $r;
      $r->[0]->(addreq ($r->[1]));
      $reqcnt = scalar (keys %reqh);
   }
}

sub addreq { my $k = $id . "_" . $_[0]; $reqh{$k} = 1; $id++; $k }
sub finreq { delete $reqh{$_[0]}; }

sub push_request {
   my ($s, $cb) = @_;
   push @req, [$cb, $s];
   schedule;
}

our $t;
sub timer {
   $t = AnyEvent->timer (after => 2, cb => sub {
      schedule;
      my $reqcnt = scalar (keys %reqh);
      $reqcnt += @req;
      print "$reqcnt outstanding requests\n";
      timer ();
   });
}

sub start {
   $J = AnyEvent->condvar;
   timer;
}
sub wait {
   $J->wait;
}

1
