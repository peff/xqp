package XQP::Server::Connection;
use Glib;
use strict;

sub register {
  my $self = bless {}, shift;
  $self->{sock} = shift;
  $self->{server} = shift;
  $self->{read_handle} =
    Glib::IO->add_watch($self->{sock}->fileno, 'in', \&_try_read, $self);
  $self->print("OK Welcome.\n");
}

sub _try_read {
  my ($fd, $cond, $self) = @_;

  my $r = sysread($self->{sock}, $self->{req}, 4096, length($self->{req}));
  if (!defined $r) {
    print STDERR "client: read error: $!\n";
    $self->close;
    return undef;
  }
  elsif (!$r) {
    $self->close;
    return undef;
  }

  while ($self->{req} =~ s/^(.*)\n//) {
    my $line = $1;
    if (!defined $self->{cmd}) {
      $self->{cmd} = $line;
      $self->{args} = [];
    }
    elsif ($line =~ /^-(.*)/) {
      push @{$self->{args}}, $1;
    }
    elsif ($line =~ /^\./) {
      $self->{server}->cmd($self, $self->{cmd}, @{$self->{args}});
      $self->{cmd} = undef;
      $self->{args} = undef;
    }
    else {
      $self->close;
      return undef;
    }
  }
  return 1;
}

sub close {
  my $self = shift;
  foreach my $h qw(read_handle write_handle) {
    next unless defined $self->{$h};
    Glib::Source->remove($self->{$h});
    $self->{$h} = undef;
  }
}

sub print {
  my $self = shift;
  $self->{response} .= shift;
  $self->{write_handle} =
    Glib::IO->add_watch($self->{sock}->fileno, 'out', \&_try_write, $self)
      unless defined $self->{write_handle};
}

sub _try_write {
  my ($fd, $cond, $self) = @_;

  my $r = syswrite($self->{sock}, $self->{response});
  if (!defined $r) {
    print STDERR "client: write error: $!";
    $self->close;
    return undef;
  }

  $self->{response} = substr($self->{response}, $r);
  if (!length($self->{response})) {
    Glib::Source->remove($self->{write_handle});
    $self->{write_handle} = undef;
    return undef;
  }

  return 1;
}

sub ok {
  my $self = shift;
  $self->print("OK\n");
  $self->print("-$_\n") for @_;
  $self->print(".\n");
}

sub no {
  my ($self, $reason) = @_;
  $self->print("NO $reason\n");
  $self->print(".\n");
}

1;
