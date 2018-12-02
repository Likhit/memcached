#!/usr/bin/perl

# The same test as in issue_104-rejig.t but using rejig commands instead.

use strict;
use Test::More tests => 8;
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

# first get should miss
print $sock "rj $config_id $fragment_id get foo\r\n";
is(scalar <$sock>, "END\r\n", "get foo");

# Now set and get (should hit)
print $sock "rj $config_id $fragment_id set foo 0 0 6\r\nfooval\r\n";
is(scalar <$sock>, "STORED\r\n", "stored foo");
rejig_mem_get_is($sock, $config_id, $fragment_id, "foo", "fooval");

my $stats = mem_stats($sock);
is($stats->{cmd_get}, 2, "Should have 2 get requests");
is($stats->{get_hits}, 1, "Should have 1 hit");
is($stats->{get_misses}, 1, "Should have 1 miss");
