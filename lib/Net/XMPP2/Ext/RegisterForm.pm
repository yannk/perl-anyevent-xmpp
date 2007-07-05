package Net::XMPP2::RegisterForm;
use strict;
use Net::XMPP2::Util;
use Net::XMPP2::Namespaces qw/xmpp_ns/;

=head1 NAME

Net::XMPP2::RegisterForm - Handle for in band registration

=head1 SYNOPSIS

   my $con = Net::XMPP2::Connection->new (...);
   ...
   $con->do_in_band_register (sub {
      my ($form, $error) = @_;
      if ($error) { print "ERROR: ".$error->string."\n" }
      else {
         if ($form->type eq 'simple') {
            if ($form->has_field ('username') && $form->has_field ('password')) {
               $form->set_field (
                  username => 'test',
                  password => 'qwerty',
               );
               $form->submit (sub {
                  my ($form, $error) = @_;
                  if ($error) { print "SUBMIT ERROR: ".$error->string."\n" }
                  else {
                     print "Successfully registered as ".$form->field ('username')."\n"
                  }
               });
            } else {
               print "Couldn't fill out the form: " . $form->field ('instructions') ."\n";
            }
         } elsif ($form->type eq 'data_form' {
            my $dform = $form->data_form;
            ... fill out the form $dform (of type Net::XMPP2::DataForm) ...
            $form->submit_data_form ($dform, sub {
               my ($form, $error) = @_;
               if ($error) { print "DATA FORM SUBMIT ERROR: ".$error->string."\n" }
               else {
                  print "Successfully registered as ".$form->field ('username')."\n"
               }
            })
         }
      }
   });

=head1 DESCRIPTION

This module represents an in band registration form
which can be filled out and submitted.

You can get an instance of this class only by requesting it
from a L<Net::XMPP2::Connection> by calling the C<request_inband_register_form>
method.

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
   my $node = $self->{node};

   # TODO
}

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Net::XMPP2::RegisterForm
