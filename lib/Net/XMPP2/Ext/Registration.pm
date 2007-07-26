package Net::XMPP2::Ext::Registration;
use strict;
use Net::XMPP2::Util;
use Net::XMPP2::Namespaces qw/xmpp_ns/;
use Net::XMPP2::Ext::RegisterForm;

=head1 NAME

Net::XMPP2::Ext::Registration - Handles all tasks of in band registration

=head1 SYNOPSIS

   my $con = Net::XMPP2::Connection->new (...);

   $con->reg_cb (stream_pre_authentication => sub {
      my ($con, $rcont) = @_;

      my $reg = Net::XMPP2::Ext::Registration->new;
      $reg->send_registration_request ($con, sub {
         my ($reg, $con, $form, $error) = @_;

         if ($form) {
            my $res = $form->try_fillout_registration ('myusername', 'mypassword');

            $reg->submit_form ($con, $res, sub {
               my ($reg, $con, $ok, $error) = @_;

               if ($ok) {
                  $con->authenticate; # just make sure the connection knows your
                                      # username and password :-)
               } else {
                  print "error: " . $error->string . "\n";
               }
            });

         } else {
            print "error: " . $error->string . "\n";
         }
      });

      $$rcont = 0;
      0
   });

=head1 DESCRIPTION

This module handles all tasks of in band registration that are possible and
specified by XEP-0077. It's mainly a helper class that eases some tasks such
as submitting and retrieving a form.

=cut

=head1 METHODS

=over 4

=item B<new (%args)>

This is the constructor for a registration object.

=over 4

=item connection

This must be a L<Net::XMPP2::Connection> (or some other subclass of that) object.

This argument is required.

=back

=cut

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = bless { @_ }, $class;
   $self->init;
   $self
}

sub init {
   my ($self) = @_;
   #...
}

=item B<send_registration_request ($cb)>

This method sends a register form request.
C<$cb> will be called when either the form arrived or
an error occured.

The first argument of C<$cb> is always C<$self>.
If the form arrived the second argument of C<$cb> will be
a L<Net::XMPP2::Ext::RegisterForm> object.
If an error occured the second argument will be undef
and the third argument will be a L<Net::XMPP2::Error::Register>
object.

For hints how L<Net::XMPP2::Ext::RegisterForm> should be filled
out look in XEP-0077. Either you have legacy form fields, out of band
data or a data form.

See also L<try_fillout_registration> in L<Net::XMPP2::Ext::RegisterForm>.

=cut

sub send_registration_request {
   my ($self, $cb) = @_;

   my $con = $self->{connection};

   $con->send_iq (get => {
      defns => 'register',
      node => { ns => 'register', name => 'query' }
   }, sub {
      my ($node, $error) = @_;

      my $form;
      if ($node) {
         $form = Net::XMPP2::Ext::RegisterForm->new;
         $form->init_from_node ($node);
      } else {
         $error =
            Net::XMPP2::Error::Register->new (
               node => $error->xml_node, register_state => 'register'
            );
      }

      $cb->($self, $form, $error);
   });
}

=item B<send_unregistration_request>

=cut

sub _error_or_form_cb {
   my ($self, $e, $cb) = @_;

   $e = $e->xml_node;

   my $error =
      Net::XMPP2::Error::Register->new (
         node => $e, register_state => 'submit'
      );

   if ($e->find_all ([qw/register query/], [qw/data_form x/])) {
      my $form = Net::XMPP2::Ext::RegisterForm->new;
      $form->init_from_node ($e);

      $cb->($self, 0, $error, $form)
   } else {
      $cb->($self, 0, $error)
   }
}

sub send_unregistration_request {
   my ($self, $cb) = @_;

   my $con = $self->{connection};

   $con->send_iq (set => {
      defns => 'register',
      node => { ns => 'register', name => 'query', childs => [
         { ns => 'register', name => 'remove' }
      ]}
   }, sub {
      my ($node, $error) = @_;
      if ($node) {
         $cb->($self, 1)
      } else {
         $self->_error_or_form_cb ($error, $cb);
      }
   });
}

sub send_password_change_request {
   my ($self, $username, $password, $cb) = @_;

   my $con = $self->{connection};

   $con->send_iq (set => {
      defns => 'register',
      node => { ns => 'register', name => 'query', childs => [
         { ns => 'register', name => 'username', childs => [ $username ] },
         { ns => 'register', name => 'password', childs => [ $password ] },
      ]}
   }, sub {
      my ($node, $error) = @_;
      if ($node) {
         $cb->($self, 1)
      } else {
         $self->_error_or_form_cb ($error, $cb);
      }
   });
}

=item B<submit_form ($form, $cb)>

This method submits the C<$form> which should be of
type L<Net::XMPP2::Ext::RegisterForm> and should be an answer
form.

C<$con> is the connection on which to send this form.

C<$cb> is the callback that will be called once the form has been submitted and
either an error or success was received.  The first argument to the callback
will be the L<Net::XMPP2::Ext::Registration> object, the second will be a
boolean value that is true when the form was successfully transmitted and
everything is fine.  If the second argument is false then the third argument is
a L<Net::XMPP2::Error::Register> object.  If the error contained a data form
which is required to successfully make the request then the fourth argument
will be a L<Net::XMPP2::Ext::RegisterForm> which you should fill out and send
again with C<submit_form>.

For the semantics of such an error form see also XEP-0077.

=cut

sub submit_form {
   my ($self, $form, $cb) = @_;

   my $con = $self->{connection};

   $con->send_iq (set => {
      defns => 'register',
      node => { ns => 'register', name => 'quert', childs => [
         $form->answer_form_to_simxml
      ]}
   }, sub {
      my ($n, $e) = @_;

      if ($n) {
         $cb->($self, 1)
      } else {
         $self->_error_or_form_cb ($e, $cb);
      }
   });
}

=back

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Net::XMPP2::Ext::Registration
