package Net::XMPP2::IM::Presence;
use strict;
use Net::XMPP2::Util;
use Net::XMPP2::IM::Message;

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   bless { @_ }, $class;
}

sub _set {
   my ($self, %data) = @_;
   $self->{show}     = $data{show} || '';
   $self->{priority} = $data{priority};
   $self->{status}   = $data{status};
}

sub jid { $_[0]->{jid} }

sub priority { $_[0]->{priority} }

sub status_all_lang {
   my ($self, $jid) = @_;
   keys %{$self->{status} || []}
}

sub show { $_[0]->{show} }

sub status {
   my ($self, $lang) = @_;

   if (defined $lang) {
      return $self->{status}->{$lang}
   } else {
      return $self->{status}->{''}
         if defined $self->{status}->{''};
      return $self->{status}->{en}
         if defined $self->{status}->{en};
   }

   undef
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
   printf "   * %-30s [%-5s] (%3d)          {%s}\n",
      $self->jid,
      $self->show     || '',
      $self->priority || 0,
      $self->status   || '',
}

1;
