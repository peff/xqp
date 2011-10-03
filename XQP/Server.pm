package XQP::Server;
use strict;
use XQP::Server::Listener; # DEPEND
use Glib;

sub new {
  my $self = bless {}, shift;
  $self->{loop} = Glib::MainLoop->new;
  $self->{socket_path} = "$ENV{HOME}/.xqpd/socket";
  $self->{advance} = 1;
  $self->{current} = undef;
  $self->{queue} = [];
  return $self;
}

sub run {
  my $self = shift;
  XQP::Server::Listener->register($self->{socket_path}, $self);
  if (!$self->{player}) {
    require XQP::Player::GStreamer;
    $self->player(XQP::Player::GStreamer->new($self));
  }
  $self->{loop}->run;
}

sub player {
  my $self = shift;
  $self->{player} = shift if @_;
  return $self->{player};
}

sub check_queue {
  my $self = shift;

  if ($self->{advance} && !defined $self->{current} && @{$self->{queue}}) {
    $self->{current} = shift @{$self->{queue}};
    $self->_qnotify;
    $self->_notify(play => $self->{current});
    $self->{player}->set_file($self->{current});
    $self->{player}->play;
  }
}

sub track_done {
  my $self = shift;
  $self->{current} = undef;
  $self->_notify('done');
  $self->check_queue;
}

sub subscribe {
  my $self = shift;
  my $what = shift;
  push @{$self->{callbacks}->{$what}}, @_;
}

sub _notify {
  my $self = shift;
  my $what = shift;

  my $cbv = $self->{callbacks}->{$what}
    or return;
  foreach my $cb (@$cbv) {
    $cb->(@_);
  }
}

sub _qnotify {
  my $self = shift;
  $self->_notify(queue => @{$self->{queue}});
}

sub append {
  my $self = shift;
  push @{$self->{queue}}, @_;
  $self->_qnotify;
}

sub prepend {
  my $self = shift;
  unshift @{$self->{queue}}, @_;
  $self->_qnotify;
}

sub replace {
  my $self = shift;
  $self->{queue} = [@_];
  $self->_qnotify;
}

sub cmd {
  my ($self, $c, $cmd, @args) = @_;

  my $fun = "cmd_$cmd";
  if (!$self->can($fun)) {
    $c->no('no such command');
    return;
  }

  $self->$fun($c, @args);
  $self->check_queue;
}

sub cmd_quit {
  my ($self, $c) = @_;
  $self->{loop}->quit;
  $c->ok;
}

sub cmd_clear {
  my ($self, $c) = @_;
  $self->{queue} = [];
  $c->ok;
}

sub cmd_append {
  my ($self, $c, @args) = @_;
  $self->append(@args);
  $c->ok;
}

sub cmd_prepend {
  my ($self, $c, @args) = @_;
  $self->prepend(@args);
  $c->ok;
}

sub cmd_replace {
  my ($self, $c, @args) = @_;
  $self->replace(@args);
  $c->ok;
}

sub cmd_list {
  my ($self, $c, @args) = @_;
  $c->ok(@{$self->{queue}});
}

sub cmd_advance {
  my ($self, $c, $bool) = @_;
  $self->{advance} = !!$bool;
  $c->ok;
}

sub cmd_current {
  my ($self, $c) = @_;
  $c->ok(defined $self->{current} ? $self->{current} : ());
}

sub cmd_seek {
  my ($self, $c, $spec) = @_;

  my $pos = 0;
  if ($spec =~ /^\+(\d+)$/) {
    $pos = $self->{player}->position + $1;
  }
  elsif ($spec =~ /^-(\d+)$/) {
    $pos = $self->{player}->position - $1;
  }
  elsif ($spec =~ /^(\d+)$/) {
    $pos = $1;
  }
  else {
    $c->no('invalid position');
    return;
  }

  $self->{player}->seek($spec);
  $c->ok;
}

sub cmd_position {
  my ($self, $c) = @_;
  $c->ok($self->{player}->position);
}

sub cmd_next {
  my ($self, $c) = @_;
  $self->{player}->stop;
  $self->track_done;
  $c->ok;
}

1;
