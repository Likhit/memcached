#!/usr/bin/perl

use strict;
use Test::More tests => 996;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;

my $server = new_memcached();
my $sock = $server->sock;
my $config_id = 1;

for (my $keyi = 1; $keyi < 250; $keyi++) {
    my $key = "x" x $keyi;
    print $sock "rj $config_id set $key 0 0 1\r\n9\r\n";
    is (scalar <$sock>, "STORED\r\n", "stored $key");
    rejig_mem_get_is($sock, $config_id, $key, "9");
    print $sock "rj $config_id incr $key 1\r\n";
    is (scalar <$sock>, "10\r\n", "incr $key to 10");
    rejig_mem_get_is($sock, $config_id, $key, "10");
}

