#!/usr/bin/perl

# The same test as in issue_183-rejig.t but using rejig commands instead.

use strict;
use Test::More tests => 7;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;

my $server = new_memcached("-o no_modern");
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

print $sock "rj $config_id $fragment_id set key 0 0 1\r\n1\r\n";
is (scalar <$sock>, "STORED\r\n", "stored key");
my $s1  = mem_stats($sock);
my $r1 = $s1->{"reclaimed"};
is ($r1, "0", "Objects should not be reclaimed");
sleep(2);
print $sock "flush_all\r\n";
is (scalar <$sock>, "OK\r\n", "Cache flushed");
print $sock "rj $config_id $fragment_id set key 0 0 1\r\n1\r\n";
is (scalar <$sock>, "STORED\r\n", "stored key");
my $s2  = mem_stats($sock);
my $r2 = $s2->{"reclaimed"};
is ($r2, "1", "Objects should be reclaimed");
