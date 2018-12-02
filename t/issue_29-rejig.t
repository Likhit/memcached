#!/usr/bin/perl

# The same test as in issue_29-rejig.t but using rejig commands instead.

use strict;
use Test::More tests => 6;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;

my $server = new_memcached();
my $sock = $server->sock;
my $config_id = 1;
my $fragment_id = 1;
my $fragment_lease_time = 300;

# Initialize the config and number of fragments.
print $sock "rj $config_id $fragment_id conf 0 0 12\r\ndummy_config\r\n";
is(scalar <$sock>, "STORED\r\n", "stored config");

# Grant a lease on the fragment
print $sock "rj $config_id $fragment_id grant $fragment_lease_time\r\n";
is(scalar <$sock>, "GRANTED\r\n", "granted lease");

print $sock "rj $config_id $fragment_id set issue29 0 0 0\r\n\r\n";
is (scalar <$sock>, "STORED\r\n", "stored issue29");

my $first_stats  = mem_stats($sock, "slabs");
my $first_used = $first_stats->{"1:used_chunks"};

# Changed 1 to 2 to accommodate rejig test cases
is(2, $first_used, "Used one");

print $sock "rj $config_id $fragment_id set issue29_b 0 0 0\r\n\r\n";
is (scalar <$sock>, "STORED\r\n", "stored issue29_b");

my $second_stats  = mem_stats($sock, "slabs");
my $second_used = $second_stats->{"1:used_chunks"};

# Changed 2 to 3 to accommodate rejig test cases
is(3, $second_used, "Used two")
