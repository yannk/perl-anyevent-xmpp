package Net::XMPP2::Ext::Registration;
use strict;
use Net::XMPP2::Util;
use Net::XMPP2::Namespaces qw/xmpp_ns/;

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

This module handles all tasks of in band registration that are
possible and specified by XEP-0077. (NOT IMPLEMENTED YET!)

=cut

=head1 METHODS

=over 4

=item B<new (%args)>

This is the constructor for a registration object.
C<%args> is a hash which can have the following keys:

NOTE: the C<connection> argument is required.

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

=cut

sub send_registration_request {
   my ($self, $cb) = @_;



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
