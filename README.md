xqp -- music queue playing daemon
==================================

xqp is a queue-based music-playing daemon that stresses simplicity,
flexibility, and extensibility.

xqp is queue-based: tracks are played sequentially from a queue, and the
user is free to add to or manipulate the queue at any time. The
currently playing track is never interrupted (unless you ask for it
explicitly), making it suitable for DJ-ing or party situations.

xqp is simple: there is no music database, no tag management, no
playlist management, and no graphical interface. The queue is a list of
files to play. It's written in only a few hundred lines of perl, and
relies on gstreamer to do the heavy lifting.

xqp is flexible: clients access the daemon over a simple text-based
protocol, and a scriptable unix-friendly client is included. You can
dump the queue to a file, edit it with your favorite text editor, and
then push it back to the daemon.

xqp is extensible: xqpd will run arbitrary perl code from the user. You
can provide custom gstreamer elements in the pipeline. You can use smart
playlist generators to generate items in the queue. You can hook
notifications into your existing status widgets. And so on.

Building
--------

To build from the git repository, you will need the `mfm` tool. You can
get it here: <http://github.com/peff/mfm>

Then run:

    mfm
    make
    make install

Contact
-------

Send questions or comments to peff@peff.net.
