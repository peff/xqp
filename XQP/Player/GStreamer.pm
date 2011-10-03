package XQP::Player::GStreamer;
use strict;
use GStreamer;

sub new {
  my $self = bless {}, shift;
  $self->{server} = shift;

  GStreamer->init;
  $self->{player} = GStreamer::ElementFactory->make('playbin2', 'player');
  $self->{player}->get_bus->add_watch(\&_bus_callback, $self);

  return $self;
}

sub _bus_callback {
  my ($bus, $message, $self) = @_;

  if ($message->type & 'error') {
    print STDERR "gstreamer: ", $message->error, "\n";
    $self->{player}->set_state('null');
    $self->{server}->track_done;
  }
  elsif ($message->type & 'eos') {
    $self->{player}->set_state('null');
    $self->{server}->track_done;
  }

  return 1;
}

sub set_sink {
  my $self = shift;
  $self->{sink} = shift;
  $self->{player}->set('audio-sink' => $self->{sink});
}

sub set_file {
  my $self = shift;
  my $fn = shift;
  $self->{player}->set(uri => Glib::filename_to_uri($fn, 'localhost'));
}

sub play {
  my $self = shift;
  $self->{player}->set_state('playing');
}

sub stop {
  my $self = shift;
  $self->{player}->set_state('null');
}

sub seek {
  my $self = shift;
  my $time = shift;
  $self->{player}->seek(1, 'time', [qw(accurate flush)],
                        set => 1000000 * $time,
                        none => -1);
}

sub position {
  my $self = shift;
  my $q = GStreamer::Query::Position->new('time');
  $self->{player}->query($q);
  my (undef, $pos) = $q->position;
  return $pos / 1000000;
}

1;
