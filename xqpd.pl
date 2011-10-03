use Error::Die; # DEPEND
use XQP::Server; # DEPEND
use strict;

my $RCFILE = "$ENV{HOME}/.xqpd/rc";
my $RCDIR = "$RCFILE.d";

my $server = XQP::Server->new;

read_rcfile($RCFILE) if -e $RCFILE;
foreach my $fn (<$RCDIR/*>) {
  read_rcfile($fn);
}

$server->run;
exit 0;

sub read_rcfile {
  my $fn = shift;
  open(my $fh, '<', $fn)
    or die "unable to open $fn: $!";
  my $data = do { local $/; <$fh> };
  eval "#line 1 $fn\n$data";
  $@ and die $@;
}
