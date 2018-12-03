#!/usr/bin/perl

# The same test as in issue_163-rejig.t but using rejig commands instead.

use strict;
use Test::More tests => 9;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;

my $server = new_memcached();
my $sock = $server->sock;
my $value1 = "A"x66560;
my $value2 = "B"x66570;
my $config_id = 1;
my $fragment_id = 1;
my $fragment_lease_time = 300;

# Initialize the config and number of fragments.
print $sock "rj $config_id $fragment_id conf 0 0 12\r\ndummy_config\r\n";
is(scalar <$sock>, "STORED\r\n", "stored config");

# Grant a lease on the fragment
print $sock "rj $config_id $fragment_id grant $fragment_lease_time\r\n";
is(scalar <$sock>, "GRANTED\r\n", "granted lease");

print $sock "rj $config_id $fragment_id set key 0 1 66560\r\n$value1\r\n";
is (scalar <$sock>, "STORED\r\n", "stored key");

my $stats  = mem_stats($sock, "slabs");
my $requested = $stats->{"31:mem_requested"};
isnt ($requested, "0", "We should have requested some memory");

sleep(3);
print $sock "rj $config_id $fragment_id set key 0 0 66570\r\n$value2\r\n";
is (scalar <$sock>, "STORED\r\n", "stored key");

my $stats  = mem_stats($sock, "items");
my $reclaimed = $stats->{"items:31:reclaimed"};
is ($reclaimed, "1", "Objects should be reclaimed");

print $sock "rj $config_id $fragment_id delete key\r\n";
is (scalar <$sock>, "DELETED\r\n", "deleted key");

print $sock "rj $config_id $fragment_id set key 0 0 66560\r\n$value1\r\n";
is (scalar <$sock>, "STORED\r\n", "stored key");

my $stats  = mem_stats($sock, "slabs");
my $requested2 = $stats->{"31:mem_requested"};
is ($requested2, $requested, "we've not allocated and freed the same amount");
