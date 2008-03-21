package Net::XMPP2::Ext::Version;
use Net::XMPP2::Namespaces qw/xmpp_ns/;
use Net::XMPP2::Util qw/simxml/;
use Net::XMPP2::Ext;
use strict;

our @ISA = qw/Net::XMPP2::Ext/;

=head1 NAME

Net::XMPP2::Ext::Version - Software version

=head1 SYNOPSIS

   use Net::XMPP2::Ext::Version;

=head1 DESCRIPTION

This module defines an extension to provide the abilities
to answer to software version requests and to request software
version from other entities.

See also XEP-0092

This class is derived from L<Net::XMPP2::Ext> and can be added as extension to
objects that implement the L<Net::XMPP2::Extendable> interface or derive from
it.

=head1 METHODS

=over 4

=item B<new (%args)>

Creates a new software version handle.

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

   $self->set_name    ("Net::XMPP2");
   $self->set_version ("$Net::XMPP2::VERSION");


   $self->{cb_id} = $self->reg_cb (
      iq_get_request_xml => sub {
         my ($self, $con, $node) = @_;

         if ($self->handle_query ($con, $node)) {
            return 1;
         }

         ()
      }
   );
}

=item B<set_name ($name)>

This method sets the software C<$name> string, the default is "Net::XMPP2".

=cut

sub set_name {
   my ($self, $name) = @_;
   $self->{name} = $name;
}

=item B<set_version ($version)>

This method sets the software C<$version> string that is replied.

The default is C<$Net::XMPP2::VERSION>.

=cut

sub set_version {
   my ($self, $version) = @_;
   $self->{version} = $version;
}

=item B<set_os ($os)>

This method sets the operating system string C<$os>. If you pass
undef the string will be removed.

The default is no operating system string at all.

You may want to pass something like this:

   $version->set_os (`uname -s -r -m -o`);

=cut

sub set_os {
   my ($self, $os) = @_;
   $self->{os} = $os;
   delete $self->{os} unless defined $os;
}

sub version_result {
   my ($self) = @_;
   (
      { name => 'name'   , childs => [ $self->{name}    ] },
      { name => 'version', childs => [ $self->{version} ] },
      (defined $self->{os}
         ? { name => 'os', childs => [ $self->{os} ] }
         : ()
      ),
   )
}

sub handle_query {
   my ($self, $con, $node) = @_;

   if (my ($q) = $node->find_all ([qw/version query/])) {
      my @result = $self->version_result;
      $con->reply_iq_result (
         $node, {
            defns => 'version',
            node => {
               ns => 'version', name => 'query', childs => [
                  @result
               ]
            }
         }
      );
      return 1
   }

   ()
}

sub _version_from_node {
   my ($node) = @_;
   my (@vers) = $node->find_all ([qw/version query/], [qw/version version/]);
   my (@name) = $node->find_all ([qw/version query/], [qw/version name/]);
   my (@os)   = $node->find_all ([qw/version query/], [qw/version os/]);

   my $v = {};

   $v->{jid}     = $node->attr ('from');
   $v->{version} = $vers[0]->text if @vers;
   $v->{name}    = $name[0]->text if @name;
   $v->{os}      = $os[0]->text   if @os;

   $v
}

=item B<request_version ($con, $dest, $cb)>

This method sends a version request to C<$dest> on the connection C<$con>.

C<$cb> is the callback that will be called if either an error occured or
the result was received. The callback will also be called after the default IQ
timeout for the connection C<$con>.
The second argument for the callback will be either undef if no error occured
or a L<Net::XMPP2::Error::IQ> error.
The first argument will be a hash reference with the following fields:

=over 4

=item jid

The JID of the entity this version reply belongs to.

=item version

The software version string of the entity.

=item name 

The software name of the entity.

=item os

The operating system of the entity, which might be undefined if none
was provided.

=back

Here an example of the structure of the hash reference:

  {
     jid     => 'juliet@capulet.com/balcony',
     name    => 'Exodus',
     version => '0.7.0.4',
     os      => 'Windows-XP 5.01.2600',
  }

=cut

sub request_version {
   my ($self, $con, $dest, $cb) = @_;

   $con->send_iq (get => {
      defns => 'version',
      node  => { ns => 'version', name => 'query' }
   }, sub {
      my ($n, $e) = @_;
      if ($e) {
         $cb->(undef, $e);
      } else {
         $cb->(_version_from_node ($n), undef);
      }
   }, to => $dest);
}

sub DESTROY {
   my ($self) = @_;
   $self->unreg_cb ($self->{cb_id})
}


=back

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
