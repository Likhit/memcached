#!/usr/bin/perl

# The same test as in issue_108-rejig.t but using rejig commands instead.

use strict;
use Test::More tests => 6;
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

print $sock "rj $config_id $fragment_id add $key 0 0 1\r\nx\r\n";
is (scalar <$sock>, "STORED\r\n", "Added a key");

print $sock "rj $config_id $fragment_id delete $key 0\r\n";
is (scalar <$sock>, "DELETED\r\n", "Properly deleted with 0");

print $sock "rj $config_id $fragment_id add $key 0 0 1\r\nx\r\n";
is (scalar <$sock>, "STORED\r\n", "Added again a key");

print $sock "rj $config_id $fragment_id delete $key 0 noreply\r\n";
# will not reply, but a subsequent add will succeed

print $sock "rj $config_id $fragment_id add $key 0 0 1\r\nx\r\n";
is (scalar <$sock>, "STORED\r\n", "Add succeeded after quiet deletion.");

