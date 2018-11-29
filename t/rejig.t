#!/usr/bin/perl

# Test that config id changes are handled corectly.

use strict;
use Test::More tests => 23;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;


my $server = new_memcached();
my $sock = $server->sock;

# Initial rejig_config_id should be 0.
my $stats = mem_stats($sock);
is($stats->{rejig_config_id}, 0, "rejig_config_id is 0");

# Set rejig_config_id to 1.
# Use dummy value for actual config.
print $sock "rj 1 conf 0 0 12\r\ndummy_config\r\n";
is(scalar <$sock>, "STORED\r\n", "stored config");
$stats = mem_stats($sock);
is($stats->{rejig_config_id}, 1);
mem_get_is($sock, "REJIG_CONFIG_STORAGE_KEY", "dummy_config");

# set foo with config id 1 (and should get it).
print $sock "rj 1 set foo 0 0 6\r\nfooval\r\n";
is(scalar <$sock>, "STORED\r\n", "stored foo");
rejig_mem_get_is($sock, 1, "foo", "fooval");

# set bar with config id 2 (should get it, and
# config id should now be 2, and the config object deleted).
print $sock "rj 2 set bar 0 0 6\r\nbarval\r\n";
is(scalar <$sock>, "STORED\r\n", "stored bar");
rejig_mem_get_is($sock, 2, "bar", "barval");
$stats = mem_stats($sock);
is($stats->{rejig_config_id}, 2);
print $sock "get REJIG_CONFIG_STORAGE_KEY\r\n";
is(scalar <$sock>, "END\r\n", "get config object");

# set foo with config id 1 (should fail).
print $sock "rj 1 set foo 0 0 7\r\n";
is(scalar <$sock>, "REFRESH_AND_RETRY\r\n", "store foo failed");
is(scalar <$sock>, "END\r\n", "store foo failed");

# set the config object.
print $sock "rj 2 conf  0 0 14\r\ndummy_config_2\r\n";
is(scalar <$sock>, "STORED\r\n", "stored config");
$stats = mem_stats($sock);
is($stats->{rejig_config_id}, 2);
mem_get_is($sock, "REJIG_CONFIG_STORAGE_KEY", "dummy_config_2");

# get bar with config id 1 (should fail, and return config).
print $sock "rj 1 set bar 0 0 7\r\n";
is(scalar <$sock>, "REFRESH_AND_RETRY\r\n", "store bar failed");
is(scalar <$sock>, "VALUE REJIG_CONFIG_STORAGE_KEY 0 14\r\n", "store bar failed");
is(scalar <$sock>, "dummy_config_2\r\n", "store bar failed");
is(scalar <$sock>, "END\r\n", "store bar failed");

# Multi get should fail if passed config id is smaller than current config id.
print $sock "rj 1 get foo bar\r\n";
is(scalar <$sock>, "REFRESH_AND_RETRY\r\n");
is(scalar <$sock>, "VALUE REJIG_CONFIG_STORAGE_KEY 0 14\r\n", "get foo, bar failed");
is(scalar <$sock>, "dummy_config_2\r\n", "get foo, bar failed");
is(scalar <$sock>, "END\r\n", "get foo, bar failed");
