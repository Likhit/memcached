#!/usr/bin/perl

use strict;
use Test::More tests => 4;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;

my $server = new_memcached();
my $sock = $server->sock;
my $key = "del_key";
my $config_id = 1;

print $sock "rj $config_id add $key 0 0 1\r\nx\r\n";
is (scalar <$sock>, "STORED\r\n", "Added a key");

print $sock "rj $config_id delete $key 0\r\n";
is (scalar <$sock>, "DELETED\r\n", "Properly deleted with 0");

print $sock "rj $config_id add $key 0 0 1\r\nx\r\n";
is (scalar <$sock>, "STORED\r\n", "Added again a key");

print $sock "rj $config_id delete $key 0 noreply\r\n";
# will not reply, but a subsequent add will succeed

print $sock "rj $config_id add $key 0 0 1\r\nx\r\n";
is (scalar <$sock>, "STORED\r\n", "Add succeeded after quiet deletion.");

