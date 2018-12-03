#!/usr/bin/perl

# The same test as in issue_68-rejig.t but using rejig commands instead.

use strict;
use Test::More tests => 998;
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

for (my $keyi = 1; $keyi < 250; $keyi++) {
    my $key = "x" x $keyi;
    print $sock "rj $config_id $fragment_id set $key 0 0 1\r\n9\r\n";
    is (scalar <$sock>, "STORED\r\n", "stored $key");
    rejig_mem_get_is($sock, $config_id, $fragment_id, $key, "9");
    print $sock "rj $config_id $fragment_id incr $key 1\r\n";
    is (scalar <$sock>, "10\r\n", "incr $key to 10");
    rejig_mem_get_is($sock, $config_id, $fragment_id, $key, "10");
}

