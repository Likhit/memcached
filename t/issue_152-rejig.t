#!/usr/bin/perl

# The same test as in issue_152-rejig.t but using rejig commands instead.

use strict;
use Test::More tests => 4;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;

my $server = new_memcached();
my $sock = $server->sock;
my $key = "a"x251;
my $config_id = 1;
my $fragment_id = 1;
my $fragment_lease_time = 300;

# Initialize the config and number of fragments.
print $sock "rj $config_id $fragment_id conf 0 0 12\r\ndummy_config\r\n";
is(scalar <$sock>, "STORED\r\n", "stored config");

# Grant a lease on the fragment
print $sock "rj $config_id $fragment_id grant $fragment_lease_time\r\n";
is(scalar <$sock>, "GRANTED\r\n", "granted lease");

print $sock "rj $config_id $fragment_id set a 1 0 1\r\na\r\n";
is (scalar <$sock>, "STORED\r\n", "Stored key");

print $sock "rj $config_id $fragment_id get a $key\r\n";
is (scalar <$sock>, "CLIENT_ERROR bad command line format\r\n", "illegal key");
