package Net::XMPP2::IM::Roster;
use Net::XMPP2::IM::Contact;
use Net::XMPP2::IM::Presence;
use strict;

=head1 NAME

Net::XMPP2::IM::Roster - A instant messaging roster for XMPP

=head1 SYNOPSIS

   my $con = Net::XMPP2::IM::Connection->new (...);
   ...
   my $ro  = $con->roster;
   if (my $c = $ro->get_contact ('test@example.com')) {
      $c->make_message ()->add_body ("Hello there!")->send;
   }

=head1 DESCRIPTION

This module represents a class for roster objects which contain
contact information.

It manages the roster of a JID connected by an L<Net::XMPP2::IM::Connection>.
It manages also the presence information that is received.

You get the roster by calling the C<roster> method on an L<Net::XMPP2::IM::Connection>
object. There is no other way.

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
   $self->touch_jid ($jid);
   $self->get_contact ($jid)->set_presence ($jid, %data)
}

sub set_contact {
   my ($self, $jid, %data) = @_;
   $self->touch_jid ($jid);
   $self->get_contact ($jid)->_set (%data)
}

=head2 get_contact ($jid)

Returns the contact on the roster with the JID C<$jid>.
(If C<$jid> is not bare the resource part will be stripped
before searching)

The return value is an instance of L<Net::XMPP2::IM::Contact>.

=cut

sub get_contact {
   my ($self, $jid) = @_;
   my $bjid = Net::XMPP2::Util::prep_bare_jid ($jid);
   $self->{contacts}->{$bjid}
}

=head2 get_contacts

Returns the contacts that are on this roster as
L<Net::XMPP2::IM::Contact> objects.

NOTE: This method only returns the contacts that have
a roster item. If you haven't retrieved the roster yet
the presence information is still stored but you have
to get the contacts without a roster item with the
C<get_contacts_off_roster> method. See below.

=cut

sub get_contacts {
   my ($self) = @_;
   grep { $_->is_on_roster } values %{$self->{contacts}}
}

=head2 get_contacts_off_roster

Returns the contacts that are not on the roster
but for which we have received presence.
Return value is a list of L<Net::XMPP2::IM::Contact> objects.

See also documentation of L<Net::XMPP2::IM::Roster::get_contacts>
above.

=cut

sub get_contacts_off_roster {
   my ($self) = @_;
   grep { not $_->is_on_roster } values %{$self->{contacts}}
}

=head2 debug_dump

This prints the roster and all it's contacts
and their presences.

=cut

sub debug_dump {
   my ($self) = @_;
   print "### ROSTER BEGIN ###\n";
   my %groups;
   for my $contact ($self->get_contacts) {
      push @{$groups{$_}}, $contact for $contact->groups;
      push @{$groups{''}}, $contact unless $contact->groups;
   }

   for my $grp (sort keys %groups) {
      print "=== $grp ====\n";
      $_->debug_dump for @{$groups{$grp}};
   }
   if ($self->get_contacts_off_roster) {
      print "### OFF ROSTER ###\n";
      %groups;
      for my $contact ($self->get_contacts_off_roster) {
         push @{$groups{$_}}, $contact for $contact->groups;
         push @{$groups{''}}, $contact unless $contact->groups;
      }

      for my $grp (sort keys %groups) {
         print "=== $grp ====\n";
         $_->debug_dump for @{$groups{$grp}};
      }
   }

   print "### ROSTER END ###\n";
}

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>

=head1 SEE ALSO

L<Net::XMPP2::IM::Connection>, L<Net::XMPP2::IM::Contact>, L<Net::XMPP2::IM::Presence>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut



1; # End of Net::XMPP2
