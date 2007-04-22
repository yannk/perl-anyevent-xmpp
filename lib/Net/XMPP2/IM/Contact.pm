package Net::XMPP2::IM::Contact;
use strict;
use Net::XMPP2::Util;
use Net::XMPP2::Namespaces qw/xmpp_ns/;
use Net::XMPP2::IM::Presence;
use Net::XMPP2::IM::Message;

=head1 NAME

Net::XMPP2::IM::Contact - A instant messaging roster contact

=head1 SYNOPSIS

   my $con = Net::XMPP2::IM::Connection->new (...);
   ...
   my $ro  = $con->roster;
   if (my $c = $ro->get_contact ('test@example.com')) {
      $c->make_message ()->add_body ("Hello there!")->send;
   }

=head1 DESCRIPTION

This module represents a class for contact objects which populate
a roster (L<Net::XMPP2::IM::Roster>.

You can get an instance of this class only by calling the C<get_contact>
function on a roster object.

=cut


sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   bless { @_ }, $class;
}

=head2 send_update ($cb, %upd)

This method updates a contact. If the request is finished
it will call C<$cb>. If it resulted in an error the first argument
of that callback will be a L<Net::XMPP2::Error::IQ> object.

The C<%upd> hash should have one of the following keys and defines
what parts of the contact to update:

=over 4

=item name => $name

Updates the name of the contact. C<$name> = '' erases the contact.

=item add_group => $groups

Addes the contact to the groups in the arrayreference C<$groups>.

=item remove_group => $groups

Removes the contact from the groups in the arrayreference C<$groups>.

=item groups => $groups

This sets the groups of the contact. C<$groups> should be an array reference
of the groups.

=back

=cut

sub send_update {
   my ($self, $cb, %upd) = @_;

   if ($upd{groups}) {
      $self->{groups} = $upd{groups};
   }
   for my $g (@{$upd{add_group} || []}) {
      push @{$self->{groups}}, $g unless grep { $g eq $_ } $self->groups;
   }
   for my $g (@{$upd{remove_group} || []}) {
      push @{$self->{groups}}, grep { $g ne $_ } $self->groups;
   }

   $self->{connection}->send_iq (
      set => sub {
         my ($w) = @_;
         $w->addPrefix (xmpp_ns ('roster'), '');
         $w->startTag ([xmpp_ns ('roster'), 'query']);
            $w->startTag ([xmpp_ns ('roster'), 'item'], 
               jid => $self->jid,
               (defined $upd{name} ? (name => $upd{name}) : ())
            );
               for ($self->groups) {
                  $w->startTag ([xmpp_ns ('roster'), 'group']);
                  $w->characters ($_);
                  $w->endTag;
               }
            $w->endTag;
         $w->endTag;
      },
      sub {
         my ($node, $error) = @_;
         $cb->($error) if $cb
      }
   );
}

=head2 send_subscribe ()

This method sends this contact a subscription request.

=cut

sub send_subscribe {
   my ($self) = @_;
   $self->{connection}->send_presence ('subscribe', undef, to => $self->jid);
}

=head2 send_unsubscribe ()

This method sends this contact a unsubscription request.

=cut

sub send_unsubscribe {
   my ($self) = @_;
   $self->{connection}->send_presence ('unsubscribe', undef, to => $self->jid);
}

=head2 update ($item)

This method wants a L<Net::XMPP2::Node> in C<$item> which
should be a roster item received from the server. The method will
update the contact accordingly and return it self.

=cut

sub update {
   my ($self, $item) = @_;

   my ($jid, $name, $subscription, $ask) =
      (
         $item->attr ('jid'),
         $item->attr ('name'),
         $item->attr ('subscription'),
         $item->attr ('ask')
      );

   $self->{name}         = $name;
   $self->{subscription} = $subscription;
   $self->{groups}       = [ map { $_->text } $item->find_all ([qw/roster group/]) ];
   $self->{ask}          = $ask;

   $self
}

=head2 update_presence ($presence)

This method updates the presence of contacts on the roster.
C<$presence> must be a L<Net::XMPP2::Node> object and should be
a presence packet.

=cut

sub update_presence {
   my ($self, $node) = @_;

   my $type = $node->attr ('type');
   my $jid  = $node->attr ('from');
   # XXX: should check whether C<$jid> is nice JID.

   $self->touch_presence ($jid);

   my $old;
   my $new;
   if ($type eq 'unavailable') {
      $old = $self->remove_presence ($jid);
   } else {
      $old = $self->touch_presence ($jid)->update ($node);
      $new = $self->touch_presence ($jid);
   }

   ($self, $old, $new)
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

=head2 get_presence ($jid)

This method returns a presence of this contact if
it is available. The return value is an instance of L<Net::XMPP2::IM::Presence>
or undef if no such presence exists.

=cut

sub get_presence {
   my ($self, $jid) = @_;
   my $sjid = Net::XMPP2::Util::stringprep_jid ($jid);
   $self->{presences}->{$sjid}
}

=head2 get_presences

Returns all presences of this contact in form of
L<Net::XMPP2::IM::Presence> objects.

=cut

sub get_presences { values %{$_[0]->{presences}} }

=head2 groups

Returns the list of groups (strings) this contact is in.

=cut

sub groups {
   @{$_[0]->{groups} || []}
}

=head2 jid

Returns the bare JID of this contact.

=cut

sub jid {
   $_[0]->{jid}
}

=head2 name

Returns the (nick)name of this contact.

=cut

sub name {
   $_[0]->{name}
}

=head2 is_on_roster ()

Returns 1 if this is a contact that is officially on the
roster and not just a contact we've received presence information
for.

=cut

sub is_on_roster {
   my ($self) = @_;
   $self->{subscription} && $self->{subscription} ne ''
}

=head2 subscription

Returns the subscription state of this contact, which
can be one of:

   'none', 'to', 'from', 'both'

If the contact isn't on the roster anymore this method
returns:

   'remove'

=cut

sub subscription {
   $_[0]->{subscription}
}

=head2 subscription_pending

Returns true if this contact has a pending subscription.
That means: the contact has to aknowledge the subscription.

=cut

sub subscription_pending {
   my ($self) = @_;
   $self->{ask}
}

sub make_message {
   my ($self) = @_;
   Net::XMPP2::IM::Message->new (
      connection => $self->{connection},
      to         => $self->jid
   );
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

1;
