package XQP::Server::Listener;
use strict;
use XQP::Server::Connection; # DEPEND
use Glib;
use IO::Socket::UNIX;

sub register {
  my $self = bless {}, shift;

  $self->{path} = shift;
  $self->{server} = shift;

  unlink($self->{path});
  $self->{sock} = IO::Socket::UNIX->new(
    Type => SOCK_STREAM,
    Local => $self->{path},
    Listen => 1,
  );

  Glib::IO->add_watch($self->{sock}->fileno, 'in', \&_accept, $self);
}

sub _accept {
  my ($fd, $cond, $self) = @_;
  my $client = $self->{sock}->accept;
  XQP::Server::Connection->register($client, $self->{server});
  return 1;
}

1;
