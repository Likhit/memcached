#!/usr/bin/perl

# The same test as in unixsocket.t but using rejig commands instead.

use strict;
use Test::More tests => 5;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;

my $filename = "/tmp/memcachetest$$";

my $server = new_memcached("-s $filename");
my $sock = $server->sock;
my $config_id = 1;
my $fragment_num = 1;
my $fragment_lease_time = 300;

# Initialize the config and number of fragments.
print $sock "rj $config_id $fragment_num conf 0 0 12\r\ndummy_config\r\n";
is(scalar <$sock>, "STORED\r\n", "stored config");

# Grant a lease on the fragment
print $sock "rj $config_id $fragment_num grant $fragment_lease_time\r\n";
is(scalar <$sock>, "GRANTED\r\n", "granted lease");

ok(-S $filename, "creating unix domain socket $filename");

# set foo (and should get it)
print $sock "rj $config_id $fragment_num set foo 0 0 6\r\nfooval\r\n";
is(scalar <$sock>, "STORED\r\n", "stored foo");
rejig_mem_get_is($sock, $config_id, $fragment_num, "foo", "fooval");

unlink($filename);

## Just some basic stuff for now...
