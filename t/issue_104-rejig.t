#!/usr/bin/perl

use strict;
use Test::More tests => 6;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;

my $server = new_memcached();
my $sock = $server->sock;
my $config_id = 1;

# first get should miss
print $sock "rj $config_id get foo\r\n";
is(scalar <$sock>, "END\r\n", "get foo");

# Now set and get (should hit)
print $sock "rj $config_id set foo 0 0 6\r\nfooval\r\n";
is(scalar <$sock>, "STORED\r\n", "stored foo");
mem_get_is($sock, "foo", "fooval");

my $stats = mem_stats($sock);
is($stats->{cmd_get}, 2, "Should have 2 get requests");
is($stats->{get_hits}, 1, "Should have 1 hit");
is($stats->{get_misses}, 1, "Should have 1 miss");
