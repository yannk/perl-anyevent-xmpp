package Net::XMPP2::Client;
use strict;
use AnyEvent;
use Net::XMPP2::IM::Connection;
use Net::XMPP2::Util qw/stringprep_jid prep_bare_jid dump_twig_xml/;
use Net::XMPP2::Namespaces qw/xmpp_ns/;
use Net::XMPP2::Event;
use Net::XMPP2::Extendable;
use Net::XMPP2::IM::Account;

#use XML::Twig;
#
#sub _dumpxml {
#   my $data = shift;
#   my $t = XML::Twig->new;
#   if ($t->safe_parse ("<deb>$data</deb>")) {
#      $t->set_pretty_print ('indented');
#      $t->print;
#      print "\n";
#   } else {
#      print "[$data]\n";
#   }
#}

our @ISA = qw/Net::XMPP2::Event Net::XMPP2::Extendable/;

=head1 NAME

Net::XMPP2::Client - XMPP Client abstraction

=head1 SYNOPSIS

   use Net::XMPP2::Client;
   use AnyEvent;

   my $j = AnyEvent->condvar;

   my $cl = Net::XMPP2::Client->new;
   $cl->start;

   $j->wait;

=head1 DESCRIPTION

This module tries to implement a straight forward and easy to
use API to communicate with XMPP entities. L<Net::XMPP2::Client>
handles connections and timeouts and all such stuff for you.

For more flexibility please have a look at L<Net::XMPP2::Connection>
and L<Net::XMPP2::IM::Connection>, they allow you to control what
and how something is being sent more precisely.

=head1 METHODS

=head2 new (%args)

Following arguments can be passed in C<%args>:

=over 4

=back

=cut

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = { @_ };
   bless $self, $class;

   if ($self->{debug}) {
      $self->reg_cb (
         debug_recv => sub {
            my ($self, $acc, $data) = @_;
            printf "recv>> %s\n%s", $acc->jid, dump_twig_xml ($data)
         },
         debug_send => sub {
            my ($self, $acc, $data) = @_;
            printf "send<< %s\n%s", $acc->jid, dump_twig_xml ($data)
         },
      )
   }
   return $self;
}

sub add_extension {
   my ($self, $ext) = @_;
   $self->add_forward ($ext, sub {
      my ($self, $ext, $ev, $acc, @args) = @_;
      $ext->event ($ev, $acc->connection (), @args);
   });
}

=head2 add_account ($jid, $password, $host, $port)

This method adds a jabber account for connection with the JID C<$jid>
and the password C<$password>.

C<$host> and C<$port> are optional and can be undef. C<$host> overrides the
host to connect to.

Returns 1 on success and undef when the account already exists.

=cut

sub add_account {
   my ($self, $jid, $password, $host, $port) = @_;

   $jid = stringprep_jid $jid;
   my $bj = prep_bare_jid $jid;

   return if exists $self->{accounts}->{$bj};

   my $acc =
      $self->{accounts}->{$bj} =
         Net::XMPP2::IM::Account->new (
            jid      => $jid,
            password => $password,
            host     => $host,
            port     => $port,
         );

   $self->update_connections
      if $self->{started};

   $acc
}

=head2 start ()

This method initiates the connections to the XMPP servers.

=cut

sub start {
   my ($self) = @_;
   $self->{started} = 1;
   $self->update_connections;
}

=head2 update_connections ()

This method tries to connect all unconnected accounts.

=cut

sub update_connections {
   my ($self) = @_;

   for my $acc (values %{$self->{accounts}}) {
      unless ($acc->is_connected) {
         my %args = (initial_presence => 10);

         if (defined $self->{presence}) {
            if (defined $self->{presence}->{priority}) {
               $args{initial_presence} = $self->{presence}->{priority};
            }
         }

         my $con = $acc->spawn_connection (%args);

         $con->add_forward ($self, sub {
            my ($con, $self, $ev, @arg) = @_;
            $self->event ($ev, $acc, @arg);
         });

         $con->reg_cb (
            session_ready => sub {
               my ($con) = @_;
               $self->event (connected => $acc);
               if (defined $self->{presence}) {
                  $con->send_presence (undef, undef, %{$self->{presence} || {}});
               }
               $con->unreg_me
            },
            disconnect => sub {
               delete $self->{accounts}->{$acc};
               $_[0]->unreg_me
            }
         );

         unless ($con->connect) {
            $self->event (connect_error => "Couldn't connect to ".($acc->jid).": $!");
            next
         }
         $con->init
      }
   }
}

=head2 disconnect ($msg)

Disconnect all accounts.

=cut

sub disconnect {
   my ($self, $msg) = @_;
   for my $acc (values %{$self->{accounts}}) {
      if ($acc->is_connected) { $acc->connection ()->disconnect ($msg) }
   }
}

=head2 remove_accounts ($msg)

Removes all accounts and disconnects.

=cut

sub remove_accounts {
   my ($self, $msg) = @_;
   for my $acc (keys %{$self->{accounts}}) {
      my $acca = $self->{accounts}->{$acc};
      if ($acca->is_connected) { $acca->connection ()->disconnect ($msg) }
      delete $self->{accounts}->{$acc};
   }
}

=head2 remove_account ($acc)

Removes and disconnects account C<$acc>.

=cut

sub remove_account {
   my ($self, $acc, $reason) = @_;
   if ($acc->is_connected) {
      $acc->connection ()->disconnect ($reason);
   }
   delete $self->{accounts}->{$acc};
}

=head2 send_message ($msg, $dest_jid, $src, $type)

Sends a message to the destination C<$dest_jid>.
C<$msg> can either be a string or a L<Net::XMPP2::IM::Message> object.
If C<$msg> is such an object C<$dest_jid> is optional, but will, when
passed, override the destination of the message.

C<$src> is optional. It specifies which account to use
to send the message. If it is not passed L<Net::XMPP2::Client> will try
to find an account itself. First it will look through all rosters
to find C<$dest_jid> and if none found it will pick any of the accounts that
are connected.

C<$src> can either be a JID or a L<Net::XMPP2::IM::Account> object as returned
by C<add_account> and C<get_account>.

C<$type> is optional but overrides the type of the message object in C<$msg>
if C<$msg> is such an object.

C<$type> should be 'chat' for normal chatter. If no C<$type> is specified
the type of the message defaults to the value documented in L<Net::XMPP2::IM::Message>
(should be 'normal').

=cut

sub send_message {
   my ($self, $msg, $dest_jid, $src, $type) = @_;

   unless (ref $msg) {
      $msg = Net::XMPP2::IM::Message->new (body => $msg);
   }

   if (defined $dest_jid) {
      my $jid = stringprep_jid $dest_jid
         or die "send_message: \$dest_jid is not a proper JID";
      $msg->to ($jid);
   }

   $msg->type ($type) if defined $type;

   my $srcacc;
   if (ref $src) {
      $srcacc = $src;
   } elsif (defined $src) {
      $srcacc = $self->get_account ($src)
   } else {
      $srcacc = $self->find_account_for_dest_jid ($dest_jid);
   }

   unless ($srcacc && $srcacc->is_connected) {
      die "send_message: Couldn't get connected account for sending"
   }

   $msg->send ($srcacc->connection)
}

=head2 get_account ($jid)

Returns the L<Net::XMPP2::IM::Account> account object for the JID C<$jid>
if there is any such account added. (returns undef otherwise).

=cut

sub get_account {
   my ($self, $jid) = @_;
   $self->{accounts}->{prep_bare_jid $jid}
}

=head2 get_accounts ()

Returns a list of L<Net::XMPP2::IM::Account>s.

=cut

sub get_accounts {
   my ($self) = @_;
   values %{$self->{accounts}}
}

=head2 get_connected_accounts ()

Returns a list of connected L<Net::XMPP2::IM::Account>s.

Same as:

  grep { $_->is_connected } $client->get_accounts ();

=cut

sub get_connected_accounts {
   my ($self, $jid) = @_;
   my (@a) = grep $_->is_connected, values %{$self->{accounts}};
   @a
}

=head2 find_account_for_dest_jid ($jid)

This method tries to find any account that has the contact C<$jid>
on his roster. If no account with C<$jid> on his roster was found
it takes the first one that is connected. (Return value is a L<Net::XMPP2::IM::Account>
object).

If no account is connected it returns undef.

=cut

sub find_account_for_dest_jid {
   my ($self, $jid) = @_;

   my $any_acc;
   for my $acc (values %{$self->{accounts}}) {
      next unless $acc->is_connected;

      # take "first" active account
      $any_acc = $acc unless defined $any_acc;

      my $roster = $acc->connection ()->get_roster;
      if (my $c = $roster->get_contact ($jid)) {
         return $acc;
      }
   }

   $any_acc
}

=head2 get_contacts_for_jid ($jid)

This method returns all contacts that we are connected to.
That means: It joins the contact lists of all account's rosters
that we are connected to.

=cut

sub get_contacts_for_jid {
   my ($self, $jid) = @_;
   my @cons;
   for ($self->get_connected_accounts) {
      my $roster = $_->connection ()->get_roster ();
      my $con = $roster->get_contact ($jid);
      push @cons, $con if $con;
   }
   return @cons;
}

=head2 get_priority_presence_for_jid ($jid)

This method returns the presence for the contact C<$jid> with the highest
priority.

If the contact C<$jid> is on multiple account's rosters it's undefined which
roster the presence belongs to.

=cut

sub get_priority_presence_for_jid {
   my ($self, $jid) = @_;

   my $lpres;
   for ($self->get_connected_accounts) {
      my $roster = $_->connection ()->get_roster ();
      my $con = $roster->get_contact ($jid);
      next unless defined $con;
      my $pres = $con->get_priority_presence ($jid);
      next unless defined $pres;
      if ((not defined $lpres) || $lpres->priority < $pres->priority) {
         $lpres = $pres;
      }
   }

   $lpres
}

=head2 set_presence ($show, $status, $priority)

This sets the presence of all accounts.  For a meaning of C<$show>, C<$status>
and C<$priority> see the description of the C<%attrs> hash in
C<send_presence> method of L<Net::XMPP2::Writer>.

=cut

sub set_presence {
   my ($self, $show, $status, $priority) = @_;

   $self->{presence} = {
      show     => $show,
      status   => $status,
      priority => $priority
   };

   for my $ac ($self->get_connected_accounts) {
      my $con = $ac->connection ();
      $con->send_presence (undef, undef, %{$self->{presence}});
   }
}

=head1 EVENTS

In the following event descriptions the argument C<$account>
is always a L<Net::XMPP2::IM::Account> object.

All events from L<Net::XMPP2::IM::Connection> are forwarded to the client,
only that the first argument for every event is a C<$account> object.

Aside fom those, these events can be registered on with C<reg_cb>:

=over 4

=item connected => $account

This event is sent when the C<$account> was successfully connected.

=item connect_error => $account, $reason

This event is emitted when an error occured in the connection process for the
account C<$account>.

=item error => $account

This event is emitted when any error occured while communicating
over the connection to the C<$account> - after a connection was established.

=back

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Net::XMPP2::Client
