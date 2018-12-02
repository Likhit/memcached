#!/usr/bin/perl

# The same test as in issue_14-rejig.t but using rejig commands instead.

use strict;
use Test::More tests => 23;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;

my $server = new_memcached();
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

for ($key = 0; $key < 10; $key++) {
    print $sock "rj $config_id $fragment_id set key$key 0 2 66560\r\n$value\r\n";
    is (scalar <$sock>, "STORED\r\n", "stored key$key");
}

#print $sock "stats slabs"
my $first_stats  = mem_stats($sock, "slabs");
my $first_malloc = $first_stats->{total_malloced};

sleep(4);

for ($key = 10; $key < 20; $key++) {
    print $sock "rj $config_id $fragment_id set key$key 0 2 66560\r\n$value\r\n";
    is (scalar <$sock>, "STORED\r\n", "stored key$key");
}

my $second_stats  = mem_stats($sock, "slabs");
my $second_malloc = $second_stats->{total_malloced};


is ($second_malloc, $first_malloc, "Memory grows..")
