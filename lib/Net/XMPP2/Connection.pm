package Net::XMPP2::Connection;
use warnings;
use strict;
use AnyEvent;
use IO::Socket::INET;
use Net::XMPP2::Parser;
use Net::XMPP2::Writer;
use Net::XMPP2::Util;
use Net::XMPP2::Namespaces qw/xmpp_ns/;
use Net::DNS;
use Net::SSLeay;

BEGIN {
   Net::SSLeay::load_error_strings ();
   Net::SSLeay::SSLeay_add_ssl_algorithms ();
   Net::SSLeay::randomize ();
}

our @ISA = qw/Net::XMPP2::SimpleConnection/;

=head1 NAME

Net::XMPP2::Connection - A XML stream that implements the XMPP RFC 3920.

=head1 SYNOPSIS

   use Net::XMPP2::Connection;

   my $con =
      Net::XMPP2::Connection->new (
         username => "abc",
         domain => "jabber.org",
         resource => "Net::XMPP2"
      );

   $con->connect or die "Couldn't connect to jabber.org: $!";
   $con->init;
   $con->reg_cb (stream_ready => sub { print "XMPP stream ready!\n" });

=head1 DESCRIPTION

This module represents a XMPP stream as described in RFC 3920. You can issue the basic
XMPP XML stanzas with methods like C<send_iq>, C<send_message> and C<send_presence>.

And receive events with the C<reg_cb> event framework from the connection.

If you need instant messaging stuff please take a look at C<Net::XMPP2::IM::Connection>.

=head1 METHODS

=head2 new (%args)

Following arguments can be passed in C<%args>:

=over 4

=item language => $tag

This should be the language of the human readable contents that
will be transmitted over the stream. The default will be 'en'.

Please look in RFC 3066 how C<$tag> should look like.

=item resource => $resource

If this argument is given C<$resource> will be passed as desired
resource on resource binding.

Note: You have to take care that the stringprep profile for
resources can be applied at: C<$resource>. Otherwise the server
might signal an error. See L<Net::XMPP2::Util> for utility functions
to check this.

=item domain => $domain

This is the destination host we are going to connect to.
As the connection won't be automatically connected use C<connect>
to initiate the connect.

Note: A SRV RR lookup will be performed to discover the real hostname
and port to connect to. See also C<connect>.

=item port => $port

This is optional, the default port is 5222.

Note: A SRV RR lookup will be performed to discover the real hostname
and port to connect to. See also C<connect>.

=item username => $username

This is your C<$username> (the userpart in the JID);

Note: You have to take care that the stringprep profile for
nodes can be applied at: C<$username>. Otherwise the server
might signal an error. See L<Net::XMPP2::Util> for utility functions
to check this.

=item password => $password

This is the password for the C<username> above.

=item disable_ssl => $bool

If C<$bool> is true no SSL will be used.

=back

=cut

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = {  language => 'en', @_ };
   bless $self, $class;

   $self->{parser} = new Net::XMPP2::Parser;
   $self->{writer} = Net::XMPP2::Writer->new (
      write_cb => sub { $self->write_data ($_[0]) }
   );

   $self->{parser}->set_stanza_cb (sub {
      $self->handle_stanza (@_);
   });

   $self->{iq_id} = 1;

   $self->{disconnect_cb} = sub {
      my ($host, $port, $message) = @_;
      $self->event (disconnect => $host, $port, $message);
   };

   return $self;
}

=head2 connect ($no_srv_rr)

Try to connect to the domain and port passed in C<new>.

A SRV RR lookup will be performed on the domain to discover
the host and port to use. If you don't want this set C<$no_srv_rr>
to a true value. C<$no_srv_rr> is false by default.

As the SRV RR lookup might return multiple host and you fail to
connect to one you might just call this function again to try a
different host.

If C<connect> was successful and we connected a true value is returned.
If the connect was unsuccessful undef is returned and C<$!> will be set
to the error that occured while connecting.

If you want to know whether further connection attempts might be more
successful (as SRV RR lookup may return multiple hosts) call C<may_try_connect>
(see also C<may_try_connect>).

Note that an internal list will be kept of tried hosts.  Use
C<reset_connect_tries> to reset the internal list of tried hosts.

=cut

sub connect {
   my ($self, $no_srv_rr) = @_;

   my ($host, $port) = ($self->{domain}, $self->{port} || 5222);

   unless ($no_srv_rr) {
      my $res = Net::DNS::Resolver->new;
      my $p   = $res->query ('_xmpp-client._tcp.'.$host, 'SRV');
      if ($p) {
         my @srvs = grep { $_->type eq 'SRV' } $p->answer;
         if (@srvs) {
            @srvs = sort { $a->priority <=> $b->priority } @srvs;
            @srvs = sort { $b->weight <=> $a->weight } @srvs; # TODO
            $port = $srvs[0]->port;
            $host = $srvs[0]->target;
         }
      }
   }

   if ($self->SUPER::connect ($host, $port)) {
      $self->event (connect => $host, $port);
      return 1;
   } else {
      return undef;
   }
}

=head2 may_try_connect

Returns the number of left alternatives of hosts to connect to for the
domain passed to C<new>.

An internal list of tried hosts will be managed by C<connect> and those
hosts will be ignored by a SRV RR lookup (which will be done if you
call this function).

Use C<reset_connect_tries> to reset the internal list of tried hosts.

=cut

sub may_try_connect {
   # TODO
}

=head2 reset_connect_tries

This function resets the internal list of tried hosts for C<connect>.
See also C<connect>.

=cut

sub reset_connect_tries {
   # TODO
}

sub handle_data {
   my ($self, $buf) = @_;
   $self->event (debug_recv => $$buf);
   $self->{parser}->feed (substr $$buf, 0, (length $$buf), '');
}

sub debug_wrote_data {
   my ($self, $data) = @_;
   $self->event (debug_send => $data);
}

sub write_data {
   my ($self, $data) = @_;
   $self->SUPER::write_data ($data);
}

=item reg_cb ($eventname1, $cb1, [$eventname2, $cb2, ...])

This method registers a callback C<$cb1> for the event with the
name C<$eventname1>. You can also pass multiple of these eventname => callback
pairs.

To see a documentation of emitted events please take a look at the EVENTS section
below.

=cut

sub reg_cb {
   my ($self, %regs) = @_;

   for my $cmd (keys %regs) {
      my $cb = $regs{$cmd};
      push @{$self->{events}->{$cmd}}, $cb;
   }

   1;
}

sub event {
   my ($self, $ev, @arg) = @_;

   my $nxt = [];

   my $handled;
   for (@{$self->{events}->{lc $ev}}) {
      $_->($self, @arg) and push @$nxt, $_;
   }

   $self->{events}->{lc $ev} = $nxt;
}

sub handle_stanza {
   my ($self, $p, $node) = @_;

   if ($node->eq (stream => 'features')) {
      $self->event (stream_features => $node);
      $self->handle_stream_features ($node);
      $self->{features} = $node;

   } elsif ($node->eq (tls => 'proceed')) {
      $self->enable_ssl;
      $self->{parser}->init;
      $self->{writer}->init;
      $self->{writer}->send_init_stream ($self->{language}, $self->{domain});

   } elsif ($node->eq (sasl => 'challenge')) {
      $self->handle_sasl_challenge ($node);
   } elsif ($node->eq (sasl => 'success')) {
      $self->handle_sasl_success ($node);
   } elsif ($node->eq (client => 'iq')) {
      $self->handle_iq ($node);
   } elsif ($node->eq (client => 'message')) {
      $self->event (message => $node);
   } elsif ($node->eq (client => 'presence')) {
      $self->event (presence => $node);
   } elsif ($node->eq (stream => 'error')) {
      $self->handle_error ($node);
   } else {
      warn "Didn't understood stanza: '" . $node->name . "'";
   }
}

=head2 init ($domain)

Initiate the XML stream.

=cut

sub init {
   my ($self) = @_;
   $self->{writer}->send_init_stream ($self->{language}, $self->{domain});
}

=head2 send_iq ($type, $create_cb, $result_cb, %attrs)

This method sends an IQ XMPP request.

Please take a look at the documentation for C<send_iq> in Net::XMPP2::Writer
about the meaning of C<$type>, C<$create_cb> and C<%attrs>.

C<$result_cb> will be called when a result was received. The first argument to
C<$result_cb> will be a Net::XMPP2::Node instance containing the IQ result
stanza contents.

If the IQ resulted in a stanza error the second argument to C<$result_cb> will
be C<undef> (if the error type was not 'continue') and the third argument will
be a Net::XMPP2::Node containg the IQ error stanza. And the fourth argument
will be a array reference with following contents:

This method returns the newly generated id for this iq request.

=over 4

=item index 0: error type

This will be one of: 'cancel', 'continue', 'modify', 'auth' and 'wait'.

=item index 1: error condition element

This might be undefined if other XMPP speakers don't play nice i guess.

=item index 2: error text

This will be the human readable form of the error which is maybe undef if
not supplied.

=item index 3: error code

If the error element had an 'code' attribute it will be put here,
the RFC says that this is for backward compatibility :)

=back

=cut

sub send_iq {
   my ($self, $type, $create_cb, $result_cb, %attrs) = @_;
   my $id = $self->{iq_id}++;
   $self->{iqs}->{$id} = $result_cb;
   $self->{writer}->send_iq ($id, $type, $create_cb, %attrs);
   $id
}

=head2 reply_iq_result ($req_iq_node, $create_cb, %attrs)

This method will generate a result reply to the iq request C<Net::XMPP2::Node>
in C<$req_iq_node>.

Please take a look at the documentation for C<send_iq> in Net::XMPP2::Writer
about the meaning C<$create_cb> and C<%attrs>.

The type for this iq reply is 'result'.

=cut

sub reply_iq_result {
   my ($self, $iqnode, $create_cb, %attrs) = @_;
   $self->{writer}->send_iq ($iqnode->attr ('id'), 'result', $create_cb, %attrs);
}

=head2 reply_iq_error ($req_iq_node, $error_type, $error, %attrs)

This method will generate an error reply to the iq request C<Net::XMPP2::Node>
in C<$req_iq_node>.

C<$error_type> is one of 'cancel', 'continue', 'modify', 'auth' and 'wait'.
C<$error> is one of the defined error conditions described in
L<Net::XMPP2::Writer::write_error_tag>.

Please take a look at the documentation for C<send_iq> in Net::XMPP2::Writer
about the meaning C<$create_cb> and C<%attrs>.

The type for this iq reply is 'error'.

=cut

sub reply_iq_error {
   my ($self, $iqnode, $errtype, $error, %attrs) = @_;

   $self->{writer}->send_iq (
      $iqnode->attr ('id'), 'error',
      sub { $self->{writer}->write_error_tag ($iqnode, $errtype, $error) },
      %attrs
   );
}

sub handle_iq {
   my ($self, $node) = @_;

   my $type = $node->attr ('type');

   if ($type eq 'result') {
      if (my $cb = delete $self->{iqs}->{$node->attr ('id')}) {
         $cb->($node);
      }
   } elsif ($type eq 'error') {
      if (my $cb = delete $self->{iqs}->{$node->attr ('id')}) {

         my $error = $self->filter_error_stanza ($node);
         $cb->(($error->[0] eq 'continue' ? $node : undef), $node, $error);
      }

   } else {
      my $handled = 0;
      $self->event ("iq_${type}_request" => $node, \$handled);

      my @from;
      push @from, (to => $node->attr ('from')) if $node->attr ('from');

      unless ($handled) {
         $self->reply_iq_error ($node, undef, 'feature-not-implemented', @from);
      }
   }
}

sub filter_error_stanza {
   my ($self, $node) = @_;
   my $p = $self->{parser};
   my @error;
   my ($err) = $node->find_all ([qw/client error/]);
   $error[0] = $err->attr ('type');
   $error[3] = $err->attr ('code');
   if ($err) {
      if (my ($txt) = $err->find_all ([qw/stanzas text/])) {
         $error[2] = $txt->text;
      }
      for my $er (
        qw/bad-request conflict feature-not-implemented forbidden
           gone internal-server-error item-not-found jid-malformed
           not-acceptable not-allowed not-authorized payment-required
           recipient-unavailable redirect registration-required
           remote-server-not-found remote-server-timeout resource-constraint
           service-unavailable subscription-required undefined-condition
           unexpected-request/)
      {
         if (my ($el) = $err->find_all ([stanzas => $er])) {
            $error[1] = $el;
            last;
         }
      }
   } else {
      warn "no error element found in error stanza!";
   }
   return \@error
}

sub handle_stream_features {
   my ($self, $node) = @_;
   my @mechs = $node->find_all ([qw/sasl mechanisms/], [qw/sasl mechanism/]);
   my @bind  = $node->find_all ([qw/bind bind/]);
   my @tls   = $node->find_all ([qw/tls starttls/]);

   if (not ($self->{disable_ssl}) && not ($self->{ssl_enabled}) && @tls) {
      $self->{writer}->send_starttls;

   } elsif (not ($self->{authenticated}) and @mechs) {
      $self->{writer}->send_sasl_auth (
         (join ' ', map { $_->text } @mechs),
         $self->{username}, $self->{domain}, $self->{password}
      );

   } elsif (@bind) {
      $self->do_rebind ($self->{resource});
   }
}

sub handle_sasl_challenge {
   my ($self, $node) = @_;
   $self->{writer}->send_sasl_response ($node->text);
}

sub handle_sasl_success {
   my ($self, $node) = @_;
   $self->{authenticated} = 1;
   $self->{parser}->init;
   $self->{writer}->init;
   $self->{writer}->send_init_stream ($self->{language}, $self->{domain});
}

sub handle_error {
   my ($self, $node) = @_;
   my @txt = $node->find_all ([qw/stream text/]);
   my $error;
   for my $er (
      qw/bad-format bad-namespace-prefix conflict connection-timeout host-gone
         host-unknown improper-addressing internal-server-error invalid-from
         invalid-id invalid-namespace invalid-xml not-authorized policy-violation
         remote-connection-failed resource-constraint restricted-xml
         see-other-host system-shutdown undefined-condition unsupported-stanza-type
         unsupported-version xml-not-well-formed/)
   {
      for ($node->nodes) {
         if ($node->eq (streams => $er)) {
            $error = $_->name;
            last
         }
      }
   }
   unless ($error) {
      warn "got undefined error stanza, trying to find any undefined error...";
      for ($node->nodes) {
         if ($node->eq_ns ('streams')) {
            $error = $node->name;
         }
      }
   }
   $self->event (stream_error => $error, (@txt ? $txt[0]->text : ''));
   $self->{writer}->send_end_of_stream;
}

=head2 send_presence ($type, $create_cb, %attrs)

This method sends a presence stanza, for the meanings
of C<$type>, C<$create_cb> and C<%attrs> please take a look
at the documentation for L<Net::XMPP2::Writer::send_presence>.

This methods does attach an id attribute to the message stanza and
will return the id that was used (so you can react on possible replies).

=cut

sub send_presence {
   my ($self, $type, $create_cb, %attrs) = @_;
   my $id = $self->{iq_id}++;
   $self->{writer}->send_presence ($id, $type, $create_cb, %attrs);
   $id
}

=head2 send_message ($to, $type, $create_cb, %attrs)

This method sends a presence stanza, for the meanings
of C<$to>, C<$type>, C<$create_cb> and C<%attrs> please take a look
at the documentation for L<Net::XMPP2::Writer::send_message>.

This methods does attach an id attribute to the message stanza and
will return the id that was used (so you can react on possible replies).

=cut

sub send_message {
   my ($self, $to, $type, $create_cb, %attrs) = @_;
   my $id = $self->{iq_id}++;
   $self->{writer}->send_message ($id, $to, $type, $create_cb, %attrs);
   $id
}

=head2 do_rebind ($resource)

In case you got a C<bind_error> event and want to retry
binding you can call this function to set a new C<$resource>
and retry binding.

If it fails again you can call this again. Becareful not to
end up in a loop!

If binding was successful the C<stream_ready> event will be generated.

=cut

sub do_rebind {
   my ($self, $resource) = @_;
   $self->{resource} = $resource;
   $self->send_iq (
      set =>
         sub {
            my ($w) = @_;
            if ($self->{resource}) {
               $w->startTag ([xmpp_ns ('bind'), 'bind']);
                  $w->startTag ([xmpp_ns ('bind'), 'resource']);
                  $w->characters ($self->{resource});
                  $w->endTag;
               $w->endTag;
            } else {
               $w->emptyTag ([xmpp_ns ('bind'), 'bind'])
            }
         },
         sub {
            my ($ret_iq, $err_iq, $err) = @_;

            if ($err) {
               my ($res) = $err_iq->find_all ([qw/bind bind/], [qw/bind resource/]);
               $self->event (bind_error => $err->[0], ($res ? $res : $self->{resource}));

            } else {
               my @jid = $ret_iq->find_all ([qw/bind bind/], [qw/bind jid/]);
               my $jid = $jid[0]->text;
               unless ($jid) { die "Got empty JID tag from server!\n" }
               $self->{jid} = $jid;

               $self->event (stream_ready => $jid);
            }
         }
   );
}

=head2 jid

After the stream has been bound to a resource the JID can be retrieved via this
method.

=cut

sub jid { $_[0]->{jid} }

=head2 features

Returns the last received <features> tag in form of an L<Net::XMPP2::Node> object.

=cut

sub features { $_[0]->{features} }

#sub enable_extension {
#   my ($self, @exts) = @_;
#   for (@exts) {
#      if (/^xep-(\d+)$/i) {
#         $self->{ext}->{''.(1*$1)} = 1;
#      }
#   }
#}
#
#sub check_extension {
#   my ($self, $extnum) = @_;
#   return $self->{ext}->{"$extnum"} || $Net::XMPP2::EXTENSION_ENABLED{"$extnum"};
#}

=head1 EVENTS

These events can be registered on with C<reg_cb>:

=over 4

=item stream_features => $node

This event is sent when a stream feature (<features>) tag is received. C<$node> is the
L<Net::XMPP2::Node> object that represents the <features> tag.

=item stream_ready => $jid

This event is sent if the XML stream has been established (and
resources have been bound) and is ready for transmitting regular stanzas.

C<$jid> is the bound jabber id.

=item bind_error => $error_name, $resource

This event is generated when the stream was unable to bind to
any or the in C<new> specified resource. C<$error_name>
may be 'bad-request', 'not-allowed' or 'conflict'.

Node: this is untested, i couldn't get the server to send a bind error
to test this.

=item connect => $host, $port

This event is generated when a successful connect was performed to
the domain passed to C<new>.

Note: C<$host> and C<$port> might be different from the domain you passed to
C<new> if C<connect> performed a SRV RR lookup.

If this connection is lost a C<disconnect> will be generated with the same
C<$host> and C<$port>.

=item disconnect => $host, $port, $message

This event is generated when the connection was lost or another error
occured while writing or reading from it.

C<$message> is a humand readable error message for the failure.
C<$host> and C<$port> were the host and port we were connected to.

Note: C<$host> and C<$port> might be different from the domain you passed to
C<new> if C<connect> performed a SRV RR lookup.

=item presence => $node

This event is sent when a presence stanza is received. C<$node> is the
L<Net::XMPP2::Node> object that represents the <presence> tag.

=item message => $node

This event is sent when a message stanza is received. C<$node> is the
L<Net::XMPP2::Node> object that represents the <message> tag.

=item iq_set_request => $node, $handled_ref

=item iq_get_request => $node, $handled_ref

These events are sent when an iq request stanza of type 'get' or 'set' is received.
C<$type> will either be 'get' or 'set' and C<$node> will be the L<Net::XMPP2::Node>
object of the iq tag.

If C<$$handled_ref> is true an event handler should not handle this message anymore.

If one of the event handlers handled this message the scalar pointed at by
the reference in C<$handled_ref> should be set to 1 true value. If C<$$handled_ref>
is still false after all event handlers were executed an error iq will be generated.

=back

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

package Net::XMPP2::SimpleConnection;
use IO::Socket::INET;
use Errno;
use Fcntl;
use Encode;

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = { disconnect_cb => sub {}, @_ };
   bless $self, $class;
   return $self;
}

sub set_block {
   my ($self) = @_;
   my $flags = 0;
   fcntl($self->{socket}, F_GETFL, $flags)
       or die "Couldn't get flags for HANDLE : $!\n";
   $flags &= ~O_NONBLOCK;
   fcntl($self->{socket}, F_SETFL, $flags)
       or die "Couldn't set flags for HANDLE: $!\n";
}

sub set_noblock {
   my ($self) = @_;
   my $flags = 0;
   fcntl($self->{socket}, F_GETFL, $flags)
       or die "Couldn't get flags for HANDLE : $!\n";
   $flags |= O_NONBLOCK;
   fcntl($self->{socket}, F_SETFL, $flags)
       or die "Couldn't set flags for HANDLE: $!\n";
}

sub connect {
   my ($self, $host, $port) = @_;

   $self->{socket}
      and return 1;

   my $sock = IO::Socket::INET->new (
      PeerAddr => $host,
      PeerPort => $port,
      Proto    => 'tcp',
      Blocking => 1
   );
   return undef unless $sock;;

   $self->{socket} = $sock;
   $self->{host}   = $host;
   $self->{port}   = $port;

   $self->set_noblock;

   binmode $sock, ":utf8";

   $self->{r} =
      AnyEvent->io (poll => 'r', fh => $sock, cb => sub {
         my $l = sysread $sock, my $data, 1024;

         if ($l) {
            $self->{read_buffer} .= $data;
            $self->handle_data (\$self->{read_buffer});

         } else {
            return if $! == Errno::EAGAIN;
            if (defined $l) {
               $self->{disconnect_cb}->($self->{host}, $self->{port}, "EOF from server '$self->{host}:$self->{port}'");
               $self->end_sockets;
               return;

            } else {
               $self->{disconnect_cb}->($self->{host}, $self->{port}, "Error while reading from server '$self->{host}:$port': $!");
               $self->end_sockets;
               return;
            }
         }
      });
   return 1;
}

sub end_sockets {
   my ($self) = @_;
   delete $self->{r};
   delete $self->{w};
   delete $self->{socket};
   if (delete $self->{ssl_enabled}) {
      Net::SSLeay::free ($self->{ssl});
      delete $self->{ssl};
      Net::SSLeay::CTX_free ($self->{ctx});
      delete $self->{ctx};
   }
}

sub dumpbio {
   my ($self) = @_;

   print "er: ".Net::SSLeay::BIO_should_retry (Net::SSLeay::get_rbio ($self->{ssl}));
   print " ew: ".Net::SSLeay::BIO_should_retry (Net::SSLeay::get_wbio ($self->{ssl}));
   print " rr: ".Net::SSLeay::BIO_should_read (Net::SSLeay::get_rbio ($self->{ssl}));
   print " rw: ".Net::SSLeay::BIO_should_read (Net::SSLeay::get_wbio ($self->{ssl}));
   print " wr: ".Net::SSLeay::BIO_should_write (Net::SSLeay::get_rbio ($self->{ssl}));
   print " ww: ".Net::SSLeay::BIO_should_write (Net::SSLeay::get_wbio ($self->{ssl}))."\n";

   my $e = Net::SSLeay::BIO_should_retry (Net::SSLeay::get_wbio ($self->{ssl}))
           | Net::SSLeay::BIO_should_retry (Net::SSLeay::get_wbio ($self->{ssl}));
   my $w = Net::SSLeay::BIO_should_read (Net::SSLeay::get_wbio ($self->{ssl}))
           | Net::SSLeay::BIO_should_write (Net::SSLeay::get_wbio ($self->{ssl}));
   my $r = Net::SSLeay::BIO_should_read (Net::SSLeay::get_rbio ($self->{ssl}))
           | Net::SSLeay::BIO_should_write (Net::SSLeay::get_rbio ($self->{ssl}));

   print "TEST:$e $w $r\n";
 #  delete $self->{r};
 #  delete $self->{w};
 #  if ($w) { $self->make_ssl_write_watcher }
 #  if ($r) { $self->make_ssl_read_watcher }
 #  unless ($e) {
 #     $self->make_ssl_read_watcher;
 #     $self->make_ssl_write_watcher;
 #  }
}

sub try_ssl_write {
   my ($self) = @_;

   unless ($self->{ssl_out_buffer}) { # refill buffer
      $self->{ssl_out_buffer} = $self->{write_buffer};
      $self->{write_buffer} = "";
   }

   unless ($self->{ssl_out_buffer}) {
      delete $self->{w};
      return;
   }

   my $l = Net::SSLeay::write_nb ($self->{ssl},
              $self->{ssl_out_buffer}, length ($self->{ssl_out_buffer}));

   if ($l <= 0) {
      if ($l == 0) {
         $self->{disconnect_cb}->($self->{host}, $self->{port},
            "unexpected EOF from server (ssl) '$self->{host}:$self->{port}'");
         $self->end_sockets;
         return;

      } else {
         my $err2 = Net::SSLeay::get_error $self->{ssl}, $l;
         #d# warn "write err[$err2]\n"; $self->dumpbio;
         if ($err2 == 2 || $err2 == 3) {
            delete $self->{w};
            $self->make_ssl_write_watcher ($err2 == 2 ? 'r' : 'w');
            return;
         }

         if ($! != Errno::EAGAIN
             or my $err = Net::SSLeay::ERR_get_error) {

            $self->{disconnect_cb}->($self->{host}, $self->{port},
               sprintf (
                  "Error while writing from server '$self->{host}:$self->{port}': (%d|%s|%s)",
               $err2, (Net::SSLeay::ERR_error_string $err), "$!")
            );
            $self->end_sockets;
            return;
         }
      }
      $self->make_ssl_read_watcher;
      return;
   } else {
      $self->debug_wrote_data (substr $self->{ssl_out_buffer}, 0, $l);
      $self->{ssl_out_buffer} = substr $self->{ssl_out_buffer}, $l;
   }
}

sub try_ssl_read {
   my ($self) = @_;
   my $l = Net::SSLeay::read_nb ($self->{ssl}, $self->{ssl_read_data});

   if ($l <= 0) {
      if ($l == 0) {
         $self->{disconnect_cb}->($self->{host}, $self->{port},
            "unexpected EOF from server (ssl) '$self->{host}:$self->{port}'");
         $self->end_sockets;
         return;

      } else {
         my $err2 = Net::SSLeay::get_error $self->{ssl}, $l;
         #d# warn "read err[$err2]\n"; $self->dumpbio;
         if ($err2 == 2 || $err2 == 3) {
            delete $self->{r};
            $self->make_ssl_read_watcher ($err2 == 2 ? 'r' : 'w');
            return;
         }

         if ($! != Errno::EAGAIN
             or my $err = Net::SSLeay::ERR_get_error) {

            $self->{disconnect_cb}->($self->{host}, $self->{port},
               sprintf (
                  "Error while reading from server '$self->{host}:$self->{port}':"
                  ."(%d|%s|%s)",
                  $err2, (Net::SSLeay::ERR_error_string $err), "$!")
            );
            $self->end_sockets;
            return;
         }
      }
   } else {
      $self->{read_buffer} .= decode_utf8 ($self->{ssl_read_data});
      $self->handle_data (\$self->{read_buffer});
      $self->{ssl_read_data} = "";
   }

}

sub make_ssl_read_watcher {
   my ($self, $poll) = @_;
   return if $self->{r};

   $poll ||= 'r';
   $self->{r} =
      AnyEvent->io (poll => $poll, fh => $self->{socket}, cb => sub {
         #d# warn "read cb [$poll]\n";
         $self->try_ssl_read;
      });
}

sub make_ssl_write_watcher {
   my ($self, $poll) = @_;
   return if $self->{w};

   $poll ||= 'w';
   $self->{w} =
      AnyEvent->io (poll => $poll, fh => $self->{socket}, cb => sub {
         #warn "write cb [$poll]\n";
         $self->try_ssl_write;
         1;
      });
}

sub write_data {
   my ($self, $data) = @_;
   #return unless $self->{r};

   my $cl = $self->{socket};
   $self->{write_buffer} .= $data;

   unless ($self->{w}) {
      if (not $self->{ssl_enabled}) {
         $self->{w} =
            AnyEvent->io (poll => 'w', fh => $cl, cb => sub {
               if (my $data = $self->{write_buffer}) {
                  my $len = syswrite $cl, $data;
                  unless ($len) {
                     return if $! == Errno::EAGAIN;
                     if (not defined $len) {
                        warn "error when writing data on $self->{host}:$self->{port}: $!";
                        return;
                     } else {
                        delete $self->{w};
                     }
                  }

                  if ($len == length $self->{write_buffer}) {
                     delete $self->{w};
                  }

                  $self->debug_wrote_data (substr $self->{write_buffer}, 0, $len);
                  $self->{write_buffer} = substr $self->{write_buffer}, $len;
               }
            });

      } else {
         unless ($self->{ssl_out_buffer}) {
            $self->{ssl_out_buffer} = encode_utf8 ($self->{write_buffer});
            $self->{write_buffer} = "";
            $self->make_ssl_write_watcher;
         }
      }
   }
}

sub enable_ssl {
   my ($self) = @_;

   $Net::SSLeay::ssl_version = 10; # Insist on TLSv1

   $self->{ssl_enabled} = 1;

   warn "START TLS!\n";

   $self->{r} = undef;
   $self->{w} = undef;

   $self->{ctx} = Net::SSLeay::CTX_new ();
   Net::SSLeay::CTX_set_mode($self->{ctx}, 1);
   $self->{ssl} = Net::SSLeay::new ($self->{ctx});

   Net::SSLeay::set_fd ($self->{ssl}, fileno $self->{socket});
   #d# warn "CONNECT\n";
   Net::SSLeay::connect $self->{ssl};
   #d# warn "CONNECT END\n";
   binmode $self->{socket}, ":bytes";

   $self->{ssl_read_data} = "";

   $self->make_ssl_read_watcher;
}

1; # End of Net::XMPP2
