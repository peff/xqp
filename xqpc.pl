use Error::Die; # DEPEND
use XQP::Client; # DEPEND
use Cwd qw(abs_path);

if (!@ARGV) {
  die "usage: xqpc <cmd> [args]";
}
my $cmd = shift;

my $xqp = XQP::Client->new;
$xqp->connect;

$xqp->cmd_start($cmd);
foreach my $arg (@ARGV) {
  if ($arg eq '-') {
    $xqp->cmd_arg(map { chomp; $_ } <STDIN>);
  }
  else {
    $xqp->cmd_arg($arg);
  }
}
$xqp->cmd_finish_loop(sub { print $_[0], "\n" });
exit 0;
