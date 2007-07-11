package DevCL::TreeView;
use strict;
use Gtk2;
use POSIX qw/strftime/;

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = { @_ };
   bless $self, $class
}

sub init {
   my ($self, @titles) = @_;

   my $cols = scalar @titles;
   my @cls;
   for (1..$cols) { push @cls, 'Glib::String' }
   push @cls, 'Glib::Scalar';
   my $model = Gtk2::TreeStore->new (@cls);
   $self->{model} = $model;
   my $tv = $self->{tree} = Gtk2::TreeView->new ($model);

   $tv->set_rules_hint (1);

   for (1..$cols) {
      my $txt = Gtk2::CellRendererText->new;
      $txt->set (xalign => 0);

      my $coffs =
         $tv->insert_column_with_attributes (
            -1, $titles[$_ - 1], $txt,
            text => ($_ - 1)
         );
      my $col = $tv->get_column ($coffs - 1);
   }

   $tv->signal_connect (row_activated => sub {
      my ($tv, $tp, $tc) = @_;
      my $iter = $tv->get_model ()->get_iter ($tp);
      my (@vals) = $tv->get_model ()->get ($iter);
      my $us = pop @vals;
      $self->{act_cb}->(@vals, @$us);
   });

   $tv
}

sub set_activate_cb {
   my ($self, $cb) = @_;
   $self->{act_cb} = $cb;
}

sub add_rec_path {
   my ($self, $id, @cols) = @_;
   my $fnd;
   my $m = $self->{model};

   if (defined $id) {
      $m->foreach (sub {
         my ($ts, $path, $iter) = @_;
         my $clcnt = $m->get_n_columns;
         my (@g) = $m->get ($iter);
         if ($g[$clcnt - 1]->[0] eq $id) {
            $fnd = $m->get_path ($iter)->to_string;
            return 1;
         }
         0
      });
   }

   $self->{id}++;

   my $iter;
   if (defined $fnd) {
      $iter = $m->get_iter_from_string ($fnd);
   }
   my $chlditer = $m->append ($iter);
   my $i = 0;
   my $usrptr = pop @cols;
   $m->set ($chlditer, map { ($i++, $_) } (@cols, [$self->{id}, $usrptr]));
   my $path = $m->get_path ($chlditer);

   $self->{id}
}

sub walk_step {
   my ($self, $sub, $in_id, $field, $usr) = @_;
   my ($id, $node_sub);
   if (exists $sub->{$field}) {
      ($id, $node_sub) = @{$sub->{$field}};
   } else {
      $id = $self->add_rec_path ($in_id, $field, $usr);
      $node_sub = {};
      $sub->{$field} = [$id, $node_sub];
   }
   ($id, $node_sub)
}



1
