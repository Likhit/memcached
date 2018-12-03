#!/usr/bin/perl

# The same test as in issue_61-rejig.t but using rejig commands instead.

use strict;
use Test::More tests => 9;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;

my $server = new_memcached("-R 1");
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

print $sock "rj $config_id $fragment_id set foobar 0 0 5\r\nBubba\r\nrj $config_id $fragment_id set foobar 0 0 5\r\nBubba\r\nrj $config_id $fragment_id set foobar 0 0 5\r\nBubba\r\nrj $config_id $fragment_id set foobar 0 0 5\r\nBubba\r\nrj $config_id $fragment_id set foobar 0 0 5\r\nBubba\r\nrj $config_id $fragment_id set foobar 0 0 5\r\nBubba\r\n";
is (scalar <$sock>, "STORED\r\n", "stored foobar");
is (scalar <$sock>, "STORED\r\n", "stored foobar");
is (scalar <$sock>, "STORED\r\n", "stored foobar");
is (scalar <$sock>, "STORED\r\n", "stored foobar");
is (scalar <$sock>, "STORED\r\n", "stored foobar");
is (scalar <$sock>, "STORED\r\n", "stored foobar");
my $stats = mem_stats($sock);
is ($stats->{"conn_yields"}, "5", "Got a decent number of yields");
