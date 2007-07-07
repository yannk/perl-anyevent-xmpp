package Net::XMPP2::Event;

=head1 NAME

Net::XMPP2::Event - Event handler class

=head1 SYNOPSIS

   package foo;
   use Net::XMPP2::Event;

   our @ISA = qw/Net::XMPP2::Event/;

   package main;
   my $o = foo->new;
   $o->reg_cb (foo => sub { ...; 1 });
   $o->event (foo => 1, 2, 3);

=head1 DESCRIPTION

This module is just a small helper module for the connection
and client classes.

You may only derive from this package.

=head1 METHODS

=over 4

=item B<reg_cb ($eventname1, $cb1, [$eventname2, $cb2, ...])>

This method registers a callback C<$cb1> for the event with the
name C<$eventname1>. You can also pass multiple of these eventname => callback
pairs.

The return value will be an ID that represents the set of callbacks you have installed.
Call C<unreg_cb> with that ID to remove those callbacks again.

To see a documentation of emitted events please take a look at the EVENTS section
in the classes that inherit from this one.

=cut

sub reg_cb {
   my ($self, %regs) = @_;

   $self->{id}++;

   for my $cmd (keys %regs) {
      push @{$self->{events}->{lc $cmd}}, [$self->{id}, $regs{$cmd}]
   }

   $self->{id}
}

=item B<unreg_cb ($id)>

Removes the set C<$id> of registered callbacks. C<$id> is the
return value of a C<reg_cb> call.

=cut

sub unreg_cb {
   my ($self, $id) = @_;

   my $set = delete $self->{ids}->{$id};

   for my $key (keys %{$self->{events}}) {
      @{$self->{events}->{$key}} =
         grep {
            $_->[0] ne $id
         } @{$self->{events}->{$key}};
   }
}


=item B<event ($eventname, @args)>

Emits the event C<$eventname> and passes the arguments C<@args>.

=cut

sub event {
   my ($self, $ev, @arg) = @_;

   my $nxt = [];

   my $handled;
   for (@{$self->{events}->{lc $ev}}) {
      $_->[1]->($self, @arg) and push @$nxt, $_;
   }

   for (values %{$self->{event_forwards}}) {
      $_->[1]->($self, $_->[0], $ev, @arg);
   }

   $self->{events}->{lc $ev} = $nxt;
}

=item B<add_forward ($obj, $forward_cb)>

This method allows to forward or copy all events to a object.
C<$forward_cb> will be called everytime an event is generated in C<$self>.
The first argument to the callback C<$forward_cb> will be <$self>, the second
will be C<$obj>, the third will be the event name and the rest will be
the event arguments. (For third and rest of argument also see description
of C<event>).

=cut

sub add_forward {
   my ($self, $obj, $forward_cb) = @_;
   $self->{event_forwards}->{$obj} = [$obj, $forward_cb];
}

=item B<remove_forward ($obj)>

This method removes a forward. C<$obj> must be the same
object that was given C<add_forward> as the C<$obj> argument.

=cut

sub remove_forward {
   my ($self, $obj) = @_;
   delete $self->{event_forwards}->{$obj};
}

=back

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
