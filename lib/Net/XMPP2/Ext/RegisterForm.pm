package Net::XMPP2::Ext::RegisterForm;
use strict;
use Net::XMPP2::Util;
use Net::XMPP2::Namespaces qw/xmpp_ns/;
use Net::XMPP2::Ext::DataForm;

=head1 NAME

Net::XMPP2::Ext::RegisterForm - Handle for in band registration

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
   $self
}

sub get_old_form {
   my ($self, $node) = @_;

   my $form = {};

   for ($node->nodes) {
      if ($_->eq_ns ('register')) {
         $form->{$_->name} = $_->text;
      }
   }

   $form
}

sub try_fillout_registration {
   my ($self, $username, $password) = @_;

   my $form;
   my $nform;
   if (my $df = $self->get_data_form) {
      my $af = Net::XMPP2::Ext::DataForm->new;
      $af->make_answer_form ($df);
      $af->set_field_value (username => $username);
      $af->set_field_value (password => $password);
      $nform = $af;

   } else {
      my $frm = $self->get_standard_form_fields;
      $form = {
         username => $username,
         password => $password
      };
   }

   return
      Net::XMPP2::Ext::RegisterForm->new (
         type => $self->{type},
         form     => $nform,
         old_form => $form,
         answered => 1
      );
}

sub type {
   my ($self) = @_;
   $self->{type}
}

sub is_answer_form {
   my ($self) = @_;
   $self->{answered}
}

sub is_already_registered {
   my ($self) = @_;
   exists $self->{old_form}->{registered}
}

sub init_new_form {
   my ($self, $node) = @_;

   my (@x) = $node->find_all ([qw/register query/], [qw/data_form x/]);

   if (@x) {
      my $df = Net::XMPP2::Ext::DataForm->new;
      $df->from_node (@x);
      $self->{form} = $df;

   } else {
      die "TODO!";
   }
}

sub get_standard_form_fields {
   my ($self) = @_;
   $self->{old_form};
}

sub get_data_form {
   my ($self) = @_;
   if ($self->{type} eq 'form') {
      return $self->{form};
   }
}

sub init_from_node {
   my ($self, $node) = @_;

   if ($node->find_all ([qw/register query/], [qw/data_form x/])) {
      $self->init_new_form ($node);
      $self->{type} = 'form';
   } else {
      $self->{type} = 'standard';
   }
   my $form = $self->get_old_form ($node);
   $self->{old_form} = $form;
}

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Net::XMPP2::RegisterForm
