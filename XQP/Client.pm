package XQP::Client;
use strict;
use IO::Socket::UNIX;
use Errno qw(EAGAIN);
use Cwd qw(abs_path);

sub new {
  my $self = bless {}, shift;
  $self->{sockname} = shift || "$ENV{HOME}/.xqpd/socket";
  return $self;
}

sub connect {
  my $self = shift;
  $self->{sock} = IO::Socket::UNIX->new(
    Type => SOCK_STREAM,
    Peer => $self->{sockname}
    ) or die "unable to connect to $self->{sockname}: $!";
  defined($self->{sock}->blocking(0))
    or die "unable to set non-blocking mode: $!";
}

sub fd {
  my $self = shift;
  return $self->{sock} ? $self->{sock}->fileno : undef;
}

sub read {
  my $self = shift;

  my $r = sysread($self->{sock}, $self->{buf}, 4096, length($self->{buf}));
  if(!defined($r)) {
    return if $! == EAGAIN;
    $self->close;
    die "read error: $!";
  }
  if(!$r) {
    $self->close;
    die "eof";
  }
  while($self->{buf} =~ s/([^\n]*)\n//) {
    $self->_handle_line($1);
  }
}

sub _handle_line {
  my $self = shift;
  my $line = shift;

  if(!$self->{greeted}) {
    my ($status, $message) = $self->_parse_status($line);
    if(!$status) {
      $self->close;
      die "server did not welcome us: $message";
    }
    $self->{greeted} = 1;
    return;
  }

  if(!defined $self->{status}) {
    ($self->{status}, $self->{message}) = $self->_parse_status($line);
    return;
  }

  if($line =~ s/^-//) {
    $self->{cb}->[0]->($self->{status}, $line);
  }
  elsif($line =~ /^\./) {
    $self->{cb}->[0]->($self->{status}, undef);
    $self->{status} = undef;
    shift @{$self->{cb}};
  }
  else {
    $self->close;
    die "bad argument from server: $line";
  }
}

sub close {
  my $self = shift;
  $self->{sock}->shutdown(2) if $self->{sock};
  $self->{sock} = undef;
  $self->{greeted} = 0;
  $self->{status} = undef;
  $self->{cb} = [];
}

sub cmd_start {
  my $self = shift;
  my $cmd = shift;
  $self->{sock}->print("$cmd\n");
  $self->{use_abspath} =
    $cmd eq 'prepend' || $cmd eq 'append' || $cmd eq 'replace';
}

sub cmd_arg {
  my $self = shift;

  if ($self->{use_abspath}) {
    @_ = map { abs_path($_) } @_;
  }

  $self->{sock}->print("-$_\n") for @_;
}

sub cmd_finish {
  my $self = shift;
  my $cb = shift || sub {};
  $self->{use_abspath} = 0;
  $self->{sock}->print(".\n");
  push @{$self->{cb}}, $cb;
}

sub cmd_finish_loop {
  my $self = shift;
  my $cb = shift;

  my $done = 0;
  $self->cmd_finish(
    sub {
      my ($status, $value) = @_;
      $status or die "server reported failure: $self->{message}";
      if (defined($value)) { $cb->($value) }
      else { $done = 1 }
    }
  );

  my $b = $self->{sock}->blocking(1);
  while(!$done) { $self->read }
  $self->{sock}->blocking($b);
}

sub cmd {
  my $self = shift;
  my $cb = shift;
  my $cmd = shift;

  $self->cmd_start($cmd);
  $self->cmd_arg(@_);
  $self->cmd_finish($cb);
}

sub cmd_loop {
  my $self = shift;
  my $cb = shift;
  my $cmd = shift;

  $self->cmd_start($cmd);
  $self->cmd_arg(@_);
  $self->cmd_finish_loop($cb);
}

sub cmd_wait {
  my $self = shift;
  my @r;
  $self->cmd_loop(sub { push @r, @_ }, @_);
  return wantarray ? @r : $r[0];
}

sub _parse_status {
  my $self = shift;
  my $line = shift;

  $line =~ /^(OK|NO)\s*(.*)/
    or die "bad status from server: $line";
  return ($1 eq 'OK', $2);
}

sub DESTROY {
  my $self = shift;
  $self->close;
}

1;
