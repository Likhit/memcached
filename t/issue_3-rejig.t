#!/usr/bin/perl

# The same test as in issue_3-rejig.t but using rejig commands instead.

use strict;
use Test::More tests => 10;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;

my $server = new_memcached();
my $sock = $server->sock;
my $key = "del_key";
my $config_id = 1;
my $fragment_id = 1;
my $fragment_lease_time = 300;

# Initialize the config and number of fragments.
print $sock "rj $config_id $fragment_id conf 0 0 12\r\ndummy_config\r\n";
is(scalar <$sock>, "STORED\r\n", "stored config");

# Grant a lease on the fragment
print $sock "rj $config_id $fragment_id grant $fragment_lease_time\r\n";
is(scalar <$sock>, "GRANTED\r\n", "granted lease");

print $sock "rj $config_id $fragment_id delete $key\r\n";
is (scalar <$sock>, "NOT_FOUND\r\n", "not found on delete");

print $sock "rj $config_id $fragment_id delete $key 10\r\n";
is (scalar <$sock>, "CLIENT_ERROR bad command line format."
    . "  Usage: delete <key> [noreply]\r\n", "invalid delete");

print $sock "rj $config_id $fragment_id add $key 0 0 1\r\nx\r\n";
is (scalar <$sock>, "STORED\r\n", "Add before a broken delete.");

print $sock "rj $config_id $fragment_id delete $key 10 noreply\r\n";
# Does not reply
# is (scalar <$sock>, "ERROR\r\n", "Even more invalid delete");

print $sock "rj $config_id $fragment_id add $key 0 0 1\r\nx\r\n";
is (scalar <$sock>, "NOT_STORED\r\n", "Failed to add after failed silent delete.");

print $sock "rj $config_id $fragment_id delete $key noreply\r\n";
# Will not reply, so let's do a set and check that.

print $sock "rj $config_id $fragment_id set $key 0 0 1\r\nx\r\n";
is (scalar <$sock>, "STORED\r\n", "Stored a key");

print $sock "rj $config_id $fragment_id delete $key\r\n";
is (scalar <$sock>, "DELETED\r\n", "Properly deleted");

print $sock "rj $config_id $fragment_id set $key 0 0 1\r\nx\r\n";
is (scalar <$sock>, "STORED\r\n", "Stored a key");

print $sock "rj $config_id $fragment_id delete $key noreply\r\n";
# will not reply, but a subsequent add will succeed

print $sock "rj $config_id $fragment_id add $key 0 0 1\r\nx\r\n";
is (scalar <$sock>, "STORED\r\n", "Add succeeded after deletion.");

