#!/usr/bin/perl

# The same test as in touch.t but using rejig commands instead.

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

# set foo (and should get it)
print $sock "rj $config_id $fragment_id set foo 0 2 6\r\nfooval\r\n";
is(scalar <$sock>, "STORED\r\n", "stored foo");
rejig_mem_get_is($sock, $config_id, $fragment_id, "foo", "fooval");

# touch it
print $sock "rj $config_id $fragment_id touch foo 10\r\n";
is(scalar <$sock>, "TOUCHED\r\n", "touched foo");

sleep 2;
rejig_mem_get_is($sock, $config_id, $fragment_id, "foo", "fooval");
