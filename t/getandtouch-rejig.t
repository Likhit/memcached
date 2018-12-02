#!/usr/bin/perl

# The same test as in getandtouch.t but using rejig commands instead.

use strict;
use warnings;
use Test::More tests => 17;
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

# cache miss
print $sock "rj $config_id $fragment_id gat 10 foo1\r\n";
is(scalar <$sock>, "END\r\n", "cache miss");

# set foo1 and foo2 (and should get it)
print $sock "rj $config_id $fragment_id set foo1 0 2 7\r\nfooval1\r\n";
is(scalar <$sock>, "STORED\r\n", "stored foo");

print $sock "rj $config_id $fragment_id set foo2 0 2 7\r\nfooval2\r\n";
is(scalar <$sock>, "STORED\r\n", "stored foo2");

# get and touch it with cas
print $sock "rj $config_id $fragment_id gats 10 foo1 foo2\r\n";
ok(scalar <$sock> =~ /VALUE foo1 0 7 (\d+) $config_id\r\n/, "get and touch foo1 with cas regexp success");
is(scalar <$sock>, "fooval1\r\n","value");
ok(scalar <$sock> =~ /VALUE foo2 0 7 (\d+) $config_id\r\n/, "get and touch foo2 with cas regexp success");
is(scalar <$sock>, "fooval2\r\n","value");
is(scalar <$sock>, "END\r\n", "end");

# get and touch it without cas
print $sock "rj $config_id $fragment_id gat 10 foo1 foo2\r\n";
ok(scalar <$sock> =~ /VALUE foo1 0 7 $config_id\r\n/, "get and touch foo1 without cas regexp success");
is(scalar <$sock>, "fooval1\r\n","value");
ok(scalar <$sock> =~ /VALUE foo2 0 7 $config_id\r\n/, "get and touch foo2 without cas regexp success");
is(scalar <$sock>, "fooval2\r\n","value");
is(scalar <$sock>, "END\r\n", "end");

sleep 2;
rejig_mem_get_is($sock, $config_id, $fragment_id, "foo1", "fooval1");
rejig_mem_get_is($sock, $config_id, $fragment_id, "foo2", "fooval2");
