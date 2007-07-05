package Net::XMPP2::IM::Roster;
use Net::XMPP2::IM::Contact;
use Net::XMPP2::IM::Presence;
use Net::XMPP2::Util qw/prep_bare_jid/;
use Net::XMPP2::Namespaces qw/xmpp_ns/;
use strict;

=head1 NAME

Net::XMPP2::IM::Roster - Instant messaging roster for XMPP

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

sub update {
   my ($self, $node) = @_;

   my ($query) = $node->find_all ([qw/roster query/]);
   return unless $query;

   my @upd;

   for my $item ($query->find_all ([qw/roster item/])) {
      my $jid = $item->attr ('jid');

      my $sub = $item->attr ('subscription'),
      $self->touch_jid ($jid);

      if ($sub eq 'remove') {
         my $c = $self->remove_contact ($jid);
         $c->update ($item);
      } else {
         push @upd, $self->get_contact ($jid)->update ($item);
      }
   }

   @upd
}

sub update_presence {
   my ($self, $node) = @_;
   my $jid  = $node->attr ('from');
   # XXX: should check whether C<$jid> is nice JID.

   my $type = $node->attr ('type');
   my $contact = $self->touch_jid ($jid);

   if ($type eq 'subscribe') {
      my $doit;
      $self->{connection}->event (contact_request_subscribe => $self, $contact, \$doit);
      return $contact unless defined $doit;

      if ($doit) {
         $contact->send_subscribed;
      } else {
         $contact->send_unsubscribed;
      }

   } elsif ($type eq 'subscribed') {
      $self->{connection}->event (contact_subscribed => $self, $contact);

   } elsif ($type eq 'unsubscribe') {
      my $doit;
      $self->{connection}->event (contact_did_unsubscribe => $self, $contact, \$doit);
      return $contact unless defined $doit;

      if ($doit) {
         $contact->send_unsubscribe;
      }

   } elsif ($type eq 'unsubscribed') {
      $self->{connection}->event (contact_unsubscribed => $self, $contact);

   } else {
      return $contact->update_presence ($node)
   }
   return ($contact)
}

sub touch_jid {
   my ($self, $jid) = @_;
   my $bjid = prep_bare_jid ($jid);

   unless ($self->{contacts}->{$bjid}) {
      $self->{contacts}->{$bjid} =
         Net::XMPP2::IM::Contact->new (
            connection => $self->{connection},
            jid        => Net::XMPP2::Util::bare_jid ($jid)
         )
   }

   $self->{contacts}->{$bjid}
}

sub remove_contact {
   my ($self, $jid) = @_;
   my $bjid = prep_bare_jid ($jid);
   delete $self->{contacts}->{$bjid};
}

sub set_retrieved {
   my ($self) = @_;
   $self->{retrieved} = 1;
}

=head1 METHODS

=over 4

=item B<is_retrieved>

Returns true if this roster was fetched from the server or false if this
roster hasn't been retrieved yet.

=cut

sub is_retrieved {
   my ($self) = @_;
   return $self->{retrieved}
}

=item B<new_contact ($jid, $name, $groups, $cb)>

This method sends a roster item creation request to
the server. C<$jid> is the JID of the contact.
C<$name> is the nickname of the contact, which can be
undef. C<$groups> should be a array reference containing
the groups this contact should be in.

The callback in C<$cb> will be called when the creation
is finished. The first argument will be an L<Net::XMPP2::Error::IQ>
object if the request resulted in an error.

=cut

sub new_contact {
   my ($self, $jid, $name, $groups, $cb) = @_;

   my $c = Net::XMPP2::IM::Contact->new (
      connection => $self->{connection},
      jid        => prep_bare_jid ($jid)
   );
   $c->send_update (
       $cb,
       (defined $name ? (name => $name) : ()),
       groups => ($groups || [])
   );
}

=item B<delete_contact ($jid, $cb)>

This method will send a request to the server to delete this contact
from the roster. It will result in cancelling all subscriptions.

C<$cb> will be called when the request was finished. The first argument
to the callback might be a L<Net::XMPP2::Error::IQ> object if the
request resulted in an error.

=cut

sub delete_contact {
   my ($self, $jid, $cb) = @_;

   $jid = prep_bare_jid $jid;

   $self->{connection}->send_iq (
      set => sub {
         my ($w) = @_;
         $w->addPrefix (xmpp_ns ('roster'), '');
         $w->startTag ([xmpp_ns ('roster'), 'query']);
            $w->emptyTag ([xmpp_ns ('roster'), 'item'], 
               jid => $jid,
               subscription => 'remove'
            );
         $w->endTag;
      },
      sub {
         my ($node, $error) = @_;
         $cb->($error) if $cb
      }
   );
}

=item B<get_contact ($jid)>

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

=item B<get_contacts>

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

=item B<get_contacts_off_roster>

Returns the contacts that are not on the roster
but for which we have received presence.
Return value is a list of L<Net::XMPP2::IM::Contact> objects.

See also documentation of C<get_contacts> method of L<Net::XMPP2::IM::Roster> above.

=cut

sub get_contacts_off_roster {
   my ($self) = @_;
   grep { not $_->is_on_roster } values %{$self->{contacts}}
}

=item B<subscribe ($jid)>

This method sends a subscription request to C<$jid>.
If the optional C<$not_mutual> paramenter is true
the subscription will not be mutual.

=cut

sub subscribe {
   my ($self) = @_;
   # FIXME / TODO
}

=item B<debug_dump>

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
      for my $contact ($self->get_contacts_off_roster) {
         push @{$groups{$_}}, $contact for $contact->groups;
         push @{$groups{''}}, $contact unless $contact->groups;
      }

      for my $grp (sort keys %groups) {
         print "=== $grp ====\n";
         $_->debug_dump for grep { not $_->is_on_roster } @{$groups{$grp}};
      }
   }

   print "### ROSTER END ###\n";
}

=back

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 SEE ALSO

L<Net::XMPP2::IM::Connection>, L<Net::XMPP2::IM::Contact>, L<Net::XMPP2::IM::Presence>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut



1; # End of Net::XMPP2
