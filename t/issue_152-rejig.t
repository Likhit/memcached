#!/usr/bin/perl

use strict;
use Test::More tests => 2;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;

my $server = new_memcached();
my $sock = $server->sock;
my $key = "a"x251;
my $config_id = 1;

print $sock "rj $config_id set a 1 0 1\r\na\r\n";
is (scalar <$sock>, "STORED\r\n", "Stored key");

print $sock "rj $config_id get a $key\r\n";
is (scalar <$sock>, "CLIENT_ERROR bad command line format\r\n", "illegal key");
