#!/usr/bin/perl

use strict;
use Test::More tests => 5;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;

my $server = new_memcached("-o no_modern");
my $sock = $server->sock;
my $config_id = 1;

print $sock "rj $config_id set key 0 0 1\r\n1\r\n";
is (scalar <$sock>, "STORED\r\n", "stored key");
my $s1  = mem_stats($sock);
my $r1 = $s1->{"reclaimed"};
is ($r1, "0", "Objects should not be reclaimed");
sleep(2);
print $sock "flush_all\r\n";
is (scalar <$sock>, "OK\r\n", "Cache flushed");
print $sock "rj $config_id set key 0 0 1\r\n1\r\n";
is (scalar <$sock>, "STORED\r\n", "stored key");
my $s2  = mem_stats($sock);
my $r2 = $s2->{"reclaimed"};
is ($r2, "1", "Objects should be reclaimed");