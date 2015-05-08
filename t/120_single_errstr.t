# tests for errstr contents on failure to acquire lock

use strict;
use warnings;

use Fcntl qw(O_CREAT O_RDWR O_RDONLY O_TRUNC LOCK_EX LOCK_NB );
use File::NFSLock;
use File::Temp qw(tempfile);
use IO::Handle;
use Test::More tests => 8;

my $datafile = (tempfile 'XXXXXXXXXX', 'TMPDIR' => 1)[1];
my $lockfile = $datafile . $File::NFSLock::LOCK_EXTENSION;

# Create a blank file
sysopen ( my $fh, $datafile, O_CREAT | O_RDWR | O_TRUNC );
close ($fh);
ok(-e $datafile && !-s _, 'create target file');
note( 'datafile >' . $datafile . '<' );
note( 'lockfile >' . $lockfile . '<' );
# Wipe any old stale locks
unlink $lockfile;

# using fork() only to coordinate the test, validation of
# locks in parent/child across fork is done in other tests
my $pid = fork();

if ($pid) {
    # i'm the parent, wait for child to create the lock
    STDOUT->autoflush( 1 );
    ok( $pid > 0, 'fork successful' );
    # wait for child to create the lock
    while (! -f $lockfile) {
        sleep( 1 );
    }
    ok( -f $lockfile, 'child acquired lock' );
    my $blocking_lock = File::NFSLock->new( $datafile, LOCK_EX, 1 );
    ok( ! defined( $blocking_lock ), 'parent unable to acquire blocking lock' );
    like( $File::NFSLock::errstr, qr/$pid/, 'errstr contains lock holder pid' );
    note( 'errstr >' . $File::NFSLock::errstr . '<' );
    my $non_blocking_lock = File::NFSLock->new( $datafile, LOCK_EX | LOCK_NB, 1 );
    ok( ! defined( $non_blocking_lock ), 'parent unable to acquire non-blocking lock' );
    like( $File::NFSLock::errstr, qr/$pid/, 'errstr contains lock holder pid' );
    note( 'errstr >' . $File::NFSLock::errstr . '<' );
    ok( kill( 'TERM', $pid ), 'kill child' );
}
else {
    # i'm the child, create the lock and wait for parent to kill me
    my $lock = File::NFSLock->new( $datafile, LOCK_EX | LOCK_NB );
    sleep;
}

# Wipe the temporary and lock files;
unlink $datafile;
unlink $lockfile;
