#!/usr/bin/perl

# The same test as in incrdecr.t but using rejig commands instead.

use strict;
use Test::More tests => 23;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;

my $server = new_memcached();
my $sock = $server->sock;
my $config_id = 1;

# Bug 21
print $sock "rj $config_id set bug21 0 0 19\r\n9223372036854775807\r\n";
is(scalar <$sock>, "STORED\r\n", "stored text");
print $sock "rj $config_id incr bug21 1\r\n";
is(scalar <$sock>, "9223372036854775808\r\n", "bug21 incr 1");
print $sock "rj $config_id incr bug21 1\r\n";
is(scalar <$sock>, "9223372036854775809\r\n", "bug21 incr 2");
print $sock "rj $config_id decr bug21 1\r\n";
is(scalar <$sock>, "9223372036854775808\r\n", "bug21 decr");

print $sock "rj $config_id set num 0 0 1\r\n1\r\n";
is(scalar <$sock>, "STORED\r\n", "stored num");
rejig_mem_get_is($sock, $config_id, "num", 1, "stored 1");

print $sock "rj $config_id incr num 1\r\n";
is(scalar <$sock>, "2\r\n", "+ 1 = 2");
rejig_mem_get_is($sock, $config_id, "num", 2);

print $sock "rj $config_id incr num 8\r\n";
is(scalar <$sock>, "10\r\n", "+ 8 = 10");
rejig_mem_get_is($sock, $config_id, "num", 10);

print $sock "rj $config_id decr num 1\r\n";
is(scalar <$sock>, "9\r\n", "- 1 = 9");

print $sock "rj $config_id decr num 9\r\n";
is(scalar <$sock>, "0\r\n", "- 9 = 0");

print $sock "rj $config_id decr num 5\r\n";
is(scalar <$sock>, "0\r\n", "- 5 = 0");

printf $sock "rj $config_id set num 0 0 10\r\n4294967296\r\n";
is(scalar <$sock>, "STORED\r\n", "stored 2**32");

print $sock "rj $config_id incr num 1\r\n";
is(scalar <$sock>, "4294967297\r\n", "4294967296 + 1 = 4294967297");

printf $sock "rj $config_id set num 0 0 %d\r\n18446744073709551615\r\n", length("18446744073709551615");
is(scalar <$sock>, "STORED\r\n", "stored 2**64-1");

print $sock "rj $config_id incr num 1\r\n";
is(scalar <$sock>, "0\r\n", "(2**64 - 1) + 1 = 0");

print $sock "rj $config_id decr bogus 5\r\n";
is(scalar <$sock>, "NOT_FOUND\r\n", "can't decr bogus key");

print $sock "rj $config_id decr incr 5\r\n";
is(scalar <$sock>, "NOT_FOUND\r\n", "can't incr bogus key");

print $sock "rj $config_id set bigincr 0 0 1\r\n0\r\n";
is(scalar <$sock>, "STORED\r\n", "stored bigincr");
print $sock "rj $config_id incr bigincr 18446744073709551610\r\n";
is(scalar <$sock>, "18446744073709551610\r\n");

print $sock "rj $config_id set text 0 0 2\r\nhi\r\n";
is(scalar <$sock>, "STORED\r\n", "stored hi");
print $sock "rj $config_id incr text 1\r\n";
is(scalar <$sock>,
   "CLIENT_ERROR cannot increment or decrement non-numeric value\r\n",
   "hi - 1 = 0");

