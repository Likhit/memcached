#!/usr/bin/perl

use strict;
use Test::More tests => 4;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;

my $server = new_memcached();
my $sock = $server->sock;
my $config_id = 1;

print $sock "rj $config_id set issue70 0 0 0\r\n\r\n";
is (scalar <$sock>, "STORED\r\n", "stored issue70");

print $sock "rj $config_id set issue70 0 0 -1\r\n";
is (scalar <$sock>, "CLIENT_ERROR bad command line format\r\n");

print $sock "rj $config_id set issue70 0 0 4294967295\r\n";
is (scalar <$sock>, "CLIENT_ERROR bad command line format\r\n");

print $sock "rj $config_id set issue70 0 0 2147483647\r\nscoobyscoobydoo";
is (scalar <$sock>, "CLIENT_ERROR bad command line format\r\n");
