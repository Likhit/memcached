#!/usr/bin/perl
# Test the 'stats items' evictions counters.

# The same test as in evictions.t but using rejig commands instead.

use strict;
use Test::More tests => 94;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;

my $server = new_memcached("-m 3");
my $sock = $server->sock;
my $value = "B"x66560;
my $key = 0;
my $config_id = 1;
my $fragment_id = 1;
my $fragment_lease_time = 300;

# Initialize the config and number of fragments.
print $sock "rj $config_id $fragment_id conf 0 0 12\r\ndummy_config\r\n";
is(scalar <$sock>, "STORED\r\n", "stored config");

# Grant a lease on the fragment
print $sock "rj $config_id $fragment_id grant $fragment_lease_time\r\n";
is(scalar <$sock>, "GRANTED\r\n", "granted lease");

# These aren't set to expire.
for ($key = 0; $key < 40; $key++) {
    print $sock "rj $config_id $fragment_id set key$key 0 0 66560\r\n$value\r\n";
    is(scalar <$sock>, "STORED\r\n", "stored key$key");
}

# These ones would expire in 600 seconds.
for ($key = 0; $key < 50; $key++) {
    print $sock "rj $config_id $fragment_id set key$key 0 600 66560\r\n$value\r\n";
    is(scalar <$sock>, "STORED\r\n", "stored key$key");
}

my $stats  = mem_stats($sock, "items");
my $evicted = $stats->{"items:31:evicted"};
isnt($evicted, "0", "check evicted");
my $evicted_nonzero = $stats->{"items:31:evicted_nonzero"};
isnt($evicted_nonzero, "0", "check evicted_nonzero");
