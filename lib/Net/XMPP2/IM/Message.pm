package Net::XMPP2::IM::Message;
use strict;
use overload
  '""' => "to_string";

=head1 NAME

Net::XMPP2::IM::Message - An instant message

=head1 SYNOPSIS

   use Net::XMPP2::IM::Message;

   my $con = Net::XMPP2::IM::Connection->new (...);
   ...
   my $ro  = Net::XMPP2::IM::Roster->new (connection => $con);

=head1 DESCRIPTION

This module represents a class for roster objects which contain
contact information.

=cut

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   bless { @_ }, $class;
}

sub to_string {
   my ($self) = @_;
   $self->body
}

sub from {
   my ($self, $from) = @_;
   $self->{from} = $from if defined $from;
   $self->{from}
}

sub to {
   my ($self, $to) = @_;
   $self->{to} = $to if defined $to;
   $self->{to}
}

sub make_reply {
   my ($self, $msg) = @_;

   unless ($msg) {
      $msg = Net::XMPP2::IM::Message->new ();
   }

   $msg->{connection} = $self->{connection};
   $msg->to ($self->from);
   $msg->type ($self->type);

   $msg
}

sub reply {
   my ($self, $msg, $type) = @_;

   if (ref $msg) {
      $self->make_reply ($msg)

   } else {
      my $txt = $msg;
      $msg = $self->make_reply;
      $msg->add_body ($txt);
   }

   $msg->send
}

sub send {
   my ($self) = @_;

   my @add;
   push @add, (subject => $self->{subjects})
      if %{$self->{subjects} || {}};
   push @add, (thread => $self->thread)
      if $self->thread;

   $self->{connection}->send_message (
      $self->to, $self->type, undef,
      body => $self->{bodies},
      @add
   );
}

sub type {
   my ($self, $type) = @_;
   $self->{type} = $type
      if defined $type;
   $self->{type}
}

sub thread {
   my ($self, $thread) = @_;
   $self->{thread} = $thread
      if defined $thread;
   $self->{thread}
}

sub subject {
   my ($self, $lang) = @_;

   if (defined $lang) {
      return $self->{subjects}->{$lang}
   } else {
      return $self->{subjects}->{''}
         if defined $self->{subjects}->{''};
      return $self->{subjects}->{en}
         if defined $self->{subjects}->{en};
   }

   undef
}

sub add_subject {
   my ($self, $subject, $lang) = @_;
   $self->{subjects}->{$lang || ''} = $subject;
}

sub body {
   my ($self, $lang) = @_;

   if (defined $lang) {
      return $self->{bodies}->{$lang}
   } else {
      return $self->{bodies}->{''}
         if defined $self->{bodies}->{''};
      return $self->{bodies}->{en}
         if defined $self->{bodies}->{en};
   }

   undef
}

sub add_body {
   my ($self, $body, $lang) = @_;
   $self->{bodies}->{$lang || ''} = $body;
}

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-net-xmpp2 at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-XMPP2>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::XMPP2

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Net-XMPP2>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Net-XMPP2>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Net-XMPP2>

=item * Search CPAN

L<http://search.cpan.org/dist/Net-XMPP2>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut



1; # End of Net::XMPP2
