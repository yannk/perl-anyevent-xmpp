package Net::XMPP2::IM::Presence;
use strict;
use Net::XMPP2::Util;

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   bless { @_ }, $class;
}

sub _set {
   my ($self, %data) = @_;
   $self->{show}     = $data{show} || '';
   $self->{priority} = $data{priority};
   $self->{status}   = $data{status};
}

sub jid { $_[0]->{jid} }

sub priority { $_[0]->{priority} }

sub status_all_lang {
   my ($self, $jid) = @_;
   keys %{$self->{status} || []}
}

sub show { $_[0]->{show} }

sub status {
   my ($self, $lang) = @_;

   if (defined $lang) {
      return $self->{status}->{$lang}
   } else {
      return $self->{status}->{''}
         if defined $self->{status}->{''};
      return $self->{status}->{en}
         if defined $self->{status}->{en};
   }

   undef
}

sub debug_dump {
   my ($self) = @_;
   printf "   * %-30s [%-5s] (%3d)          {%s}\n",
      $self->jid,
      $self->show     || '',
      $self->priority || 0,
      $self->status   || '',
}

package Net::XMPP2::IM::Contact;
use strict;
use Net::XMPP2::Util;

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   bless { @_ }, $class;
}

sub _set {
   my ($self, %data) = @_;
   $self->{$_} = $data{$_} for keys %data;
}

sub remove_presence {
   my ($self, $jid) = @_;
   my $sjid = Net::XMPP2::Util::stringprep_jid ($jid);
   delete $self->{presences}->{$sjid}
}

sub touch_presence {
   my ($self, $jid) = @_;
   my $sjid = Net::XMPP2::Util::stringprep_jid ($jid);

   unless (exists $self->{presences}->{$sjid}) {
      $self->{presences}->{$sjid} =
         Net::XMPP2::IM::Presence->new (connection => $self->{connection}, jid => $jid);
   }
   $self->{presences}->{$sjid}
}

sub get_presence {
   my ($self, $jid) = @_;
}

sub get_presences { values %{$_[0]->{presences}} }

sub set_presence {
   my ($self, $jid, %data) = @_;
   if ($data{type} eq 'unavailable') {
      $self->remove_presence ($jid);
   } else {
      my $p = $self->touch_presence ($jid);
      $p->_set (%data);
   }
}

sub groups {
   @{$_[0]->{groups} || []}
}

sub jid {
   $_[0]->{jid}
}

sub name {
   $_[0]->{name}
}

sub subscription {
   $_[0]->{subscription}
}

sub write_simple_message {
   my ($self, $type, $message) = @_;
   $self->{connection}->send_message ($self->jid, $type, undef, body => $message);
}

sub write_message {
   my ($self, $type, $create_cb, %attrs) = @_;
   $self->{connection}->send_message ($self->jid, $type, $create_cb, %attrs);
}

sub debug_dump {
   my ($self) = @_;
   printf "- %-30s    [%-20s] (%s)\n",
      $self->jid,
      $self->name || '',
      $self->subscription;

   for ($self->get_presences) {
      $_->debug_dump;
   }
}

package Net::XMPP2::IM::Roster;
use strict;
=head1 NAME

Net::XMPP2::IM::Roster - A instant messaging roster for XMPP

=head1 SYNOPSIS

   use Net::XMPP2::IM::Roster;

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

sub touch_jid {
   my ($self, $jid) = @_;
   my $bjid = Net::XMPP2::Util::prep_bare_jid ($jid);

   unless ($self->{contacts}->{$bjid}) {
      $self->{contacts}->{$bjid} =
         Net::XMPP2::IM::Contact->new (
            connection => $self->{connection},
            jid        => Net::XMPP2::Util::bare_jid ($jid)
         )
   }

   $self->{contacts}->{$bjid}
}

sub set_presence {
   my ($self, $jid, %data) = @_;
   $self->get_contact ($jid)->set_presence ($jid, %data);
}

sub set_contact {
   my ($self, $jid, %data) = @_;
   $self->get_contact ($jid)->_set (%data);
}

sub get_contact {
   my ($self, $jid) = @_;
   $self->touch_jid ($jid);
}

sub debug_dump {
   my ($self) = @_;
   print "### ROSTER BEGIN ###\n";
   my %groups;
   for my $contact (values %{$self->{contacts}}) {
      push @{$groups{$_}}, $contact for $contact->groups;
      push @{$groups{''}}, $contact unless $contact->groups;
   }

   for my $grp (sort keys %groups) {
      print "=== $grp ====\n";
      $_->debug_dump for @{$groups{$grp}};
   }
   print "### ROSTER END ###\n";
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
