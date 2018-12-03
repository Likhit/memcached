#!/usr/bin/perl

# The same test as in lru.t but using rejig commands instead.

use strict;
use Test::More tests => 152;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;

# assuming max slab is 1M and default mem is 64M
my $server = new_memcached('-o no_modern');
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

# create a big value for the largest slab
my $max = 1024 * 1024;
my $big = 'x' x (1024 * 1024 - 250);

ok(length($big) > 512 * 1024);
ok(length($big) < 1024 * 1024);

# test that an even bigger value is rejected while we're here
my $too_big = $big . $big . $big;
my $len = length($too_big);
print $sock "rj $config_id $fragment_id set too_big 0 0 $len\r\n$too_big\r\n";
is(scalar <$sock>, "SERVER_ERROR object too large for cache\r\n", "too_big not stored");

# set the big value
my $len = length($big);
print $sock "rj $config_id $fragment_id set big 0 0 $len\r\n$big\r\n";
is(scalar <$sock>, "STORED\r\n", "stored big");
rejig_mem_get_is($sock, $config_id, $fragment_id, "big", $big);

# no evictions yet
my $stats = mem_stats($sock);
is($stats->{"evictions"}, "0", "no evictions to start");

# set many big items, enough to get evictions
for (my $i = 0; $i < 100; $i++) {
  print $sock "rj $config_id $fragment_id set item_$i 0 0 $len\r\n$big\r\n";
  is(scalar <$sock>, "STORED\r\n", "stored item_$i");
}

# some evictions should have happened
my $stats = mem_stats($sock);
my $evictions = int($stats->{"evictions"});
ok($evictions == 38, "some evictions happened");

# the first big value should be gone
rejig_mem_get_is($sock, $config_id, $fragment_id, "big", undef);

# the earliest items should be gone too
for (my $i = 0; $i < $evictions - 1; $i++) {
  rejig_mem_get_is($sock, $config_id, $fragment_id, "item_$i", undef);
}

# check that the non-evicted are the right ones
for (my $i = $evictions - 1; $i < $evictions + 4; $i++) {
  rejig_mem_get_is($sock, $config_id, $fragment_id, "item_$i", $big);
}
