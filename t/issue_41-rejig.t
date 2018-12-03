#!/usr/bin/perl

# The same test as in issue_41-rejig.t but using rejig commands instead.

use strict;
use warnings;
use POSIX qw(ceil);
use Test::More tests => 693;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;

my $server = new_memcached();
my $sock = $server->sock;
my $config_id = 1;
my $fragment_id = 1;
my $fragment_lease_time = 300;

my $factor = 2;
my $val = "x" x $factor;
my $key = '';

# Initialize the config and number of fragments.
print $sock "rj $config_id $fragment_id conf 0 0 12\r\ndummy_config\r\n";
is(scalar <$sock>, "STORED\r\n", "stored config");

# Grant a lease on the fragment
print $sock "rj $config_id $fragment_id grant $fragment_lease_time\r\n";
is(scalar <$sock>, "GRANTED\r\n", "granted lease");

# SET items of diverse size to the daemon so it can attempt
# to return a large stats output for slabs
for (my $i=0; $i<69; $i++) {
    for (my $j=0; $j<10; $j++) {
        $key = "$i:$j";
        print $sock "rj $config_id $fragment_id set key$key 0 0 $factor\r\n$val\r\n";
        is (scalar <$sock>, "STORED\r\n", "stored key$key");
    }
    $factor *= 1.2;
    $factor = ceil($factor);
    $val = "x" x $factor;
}

# This request will kill the daemon if it has not allocated
# enough memory internally.
my $stats = mem_stats($sock, "slabs");

# Verify whether the daemon is still running or not by asking
# it for statistics.
print $sock "version\r\n";
my $v = scalar <$sock>;
ok(defined $v && length($v), "memcached didn't respond");
