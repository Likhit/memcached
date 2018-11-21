#!/usr/bin/perl

use strict;
use Test::More tests => 7;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;

my $server = new_memcached("-R 1");
my $sock = $server->sock;
my $config_id = 1;

print $sock "rj $config_id set foobar 0 0 5\r\nBubba\r\nrj $config_id set foobar 0 0 5\r\nBubba\r\nrj $config_id set foobar 0 0 5\r\nBubba\r\nrj $config_id set foobar 0 0 5\r\nBubba\r\nrj $config_id set foobar 0 0 5\r\nBubba\r\nrj $config_id set foobar 0 0 5\r\nBubba\r\n";
is (scalar <$sock>, "STORED\r\n", "stored foobar");
is (scalar <$sock>, "STORED\r\n", "stored foobar");
is (scalar <$sock>, "STORED\r\n", "stored foobar");
is (scalar <$sock>, "STORED\r\n", "stored foobar");
is (scalar <$sock>, "STORED\r\n", "stored foobar");
is (scalar <$sock>, "STORED\r\n", "stored foobar");
my $stats = mem_stats($sock);
is ($stats->{"conn_yields"}, "5", "Got a decent number of yields");
