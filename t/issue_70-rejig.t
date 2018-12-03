#!/usr/bin/perl

# The same test as in issue_70-rejig.t but using rejig commands instead.

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

print $sock "rj $config_id $fragment_id set issue70 0 0 0\r\n\r\n";
is (scalar <$sock>, "STORED\r\n", "stored issue70");

print $sock "rj $config_id $fragment_id set issue70 0 0 -1\r\n";
is (scalar <$sock>, "CLIENT_ERROR bad command line format\r\n");

print $sock "rj $config_id $fragment_id set issue70 0 0 4294967295\r\n";
is (scalar <$sock>, "CLIENT_ERROR bad command line format\r\n");

print $sock "rj $config_id $fragment_id set issue70 0 0 2147483647\r\nscoobyscoobydoo";
is (scalar <$sock>, "CLIENT_ERROR bad command line format\r\n");
