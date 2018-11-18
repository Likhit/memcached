#!/usr/bin/perl

# The same test as in getandtouch.t but using rejig commands instead.

use strict;
use warnings;
use Test::More tests => 19;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;


my $server = new_memcached();
my $sock = $server->sock;
my $config_id = 1;

# cache miss
print $sock "rj $config_id gat 10 foo1\r\n";
is(scalar <$sock>, "END\r\n", "cache miss");

# set foo1 and foo2 (and should get it)
print $sock "rj $config_id set foo1 0 2 7\r\nfooval1\r\n";
is(scalar <$sock>, "STORED\r\n", "stored foo");

print $sock "rj $config_id set foo2 0 2 7\r\nfooval2\r\n";
is(scalar <$sock>, "STORED\r\n", "stored foo2");

# get and touch it with cas
print $sock "rj $config_id gats 10 foo1 foo2\r\n";
ok(scalar <$sock> =~ /VALUE foo1 0 7 (\d+)\r\n/, "get and touch foo1 with cas regexp success");
is(scalar <$sock>, "fooval1\r\n","value");
is(scalar <$sock>, "$config_id\r\n","config id");
ok(scalar <$sock> =~ /VALUE foo2 0 7 (\d+)\r\n/, "get and touch foo2 with cas regexp success");
is(scalar <$sock>, "fooval2\r\n","value");
is(scalar <$sock>, "$config_id\r\n","config id");
is(scalar <$sock>, "END\r\n", "end");

# get and touch it without cas
print $sock "rj $config_id gat 10 foo1 foo2\r\n";
ok(scalar <$sock> =~ /VALUE foo1 0 7\r\n/, "get and touch foo1 without cas regexp success");
is(scalar <$sock>, "fooval1\r\n","value");
is(scalar <$sock>, "$config_id\r\n","config id");
ok(scalar <$sock> =~ /VALUE foo2 0 7\r\n/, "get and touch foo2 without cas regexp success");
is(scalar <$sock>, "fooval2\r\n","value");
is(scalar <$sock>, "$config_id\r\n","config id");
is(scalar <$sock>, "END\r\n", "end");

sleep 2;
rejig_mem_get_is($sock, $config_id, "foo1", "fooval1");
rejig_mem_get_is($sock, $config_id, "foo2", "fooval2");
