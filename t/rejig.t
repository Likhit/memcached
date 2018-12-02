#!/usr/bin/perl

# Test that config id changes are handled corectly.

use strict;
use Test::More tests => 71;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;


my $server = new_memcached();
my $sock = $server->sock;

# Initial rejig_config_id should be 0.
my $stats = mem_stats($sock);
is($stats->{rejig_config_id}, 0, "rejig_config_id is 0");

# Initial size of fragment lease list should be 0.
my @lease_stats = mem_lease_stats($sock);
is(scalar @lease_stats, 0, "initial fragment lease list size is 0");

# Set rejig_config_id to 0 or less should fail.
print $sock "rj 0 10 conf 0 0 6\r\n";
is(scalar <$sock>, "ERROR\r\n", "set bad conf failed");
print $sock "rj -1 10 conf 0 0 6\r\n";
is(scalar <$sock>, "ERROR\r\n", "set bad conf failed");

# Set rejig_config_id to 1 with fragment num 0 or less should fail.
print $sock "rj 1 0 conf 0 0 6\r\n";
is(scalar <$sock>, "ERROR\r\n", "set bad conf failed");
print $sock "rj 1 -0 conf 0 0 6\r\n";
is(scalar <$sock>, "ERROR\r\n", "set bad conf failed");

# Set rejig_config_id to 1 with 10 fragments.
# Use dummy value for actual config.
print $sock "rj 1 10 conf 0 0 12\r\ndummy_config\r\n";
is(scalar <$sock>, "STORED\r\n", "stored config");
$stats = mem_stats($sock);
is($stats->{rejig_config_id}, 1);
@lease_stats = mem_lease_stats($sock);
is(scalar @lease_stats, 10, "size of fragment lease list is 10");
is(all_in_list("revoked", @lease_stats), 1, "all leases revoked");
mem_get_is($sock, "REJIG_CONFIG_STORAGE_KEY", "dummy_config");

# Set shouldn't work until lease is granted.
print $sock "rj 1 3 set foo 0 0 6\r\n";
is(scalar <$sock>, "REFRESH_AND_RETRY\r\n", "store foo failed");
is(scalar <$sock>, "VALUE REJIG_CONFIG_STORAGE_KEY 0 12\r\n", "store foo failed");
is(scalar <$sock>, "dummy_config\r\n", "store foo failed");
is(scalar <$sock>, "END\r\n", "store bar failed");

# Get should also return a REFRESH_AND_RETRY.
print $sock "rj 1 3 get foo\r\n";
is(scalar <$sock>, "REFRESH_AND_RETRY\r\n", "get foo failed");
is(scalar <$sock>, "VALUE REJIG_CONFIG_STORAGE_KEY 0 12\r\n", "get foo failed");
is(scalar <$sock>, "dummy_config\r\n", "get foo failed");
is(scalar <$sock>, "END\r\n", "get bar failed");

# Set a lease on fragment 3 for 5 secs.
print $sock "rj 1 3 grant 5\r\n";
is(scalar <$sock>, "GRANTED\r\n", "grant lease failed");
@lease_stats = mem_lease_stats($sock);
is(@lease_stats[2], "valid", "lease not set");

# Set foo with config id 1 and fragment 3 (and should get it).
print $sock "rj 1 3 set foo 0 0 6\r\nfooval\r\n";
is(scalar <$sock>, "STORED\r\n", "stored foo");
rejig_mem_get_is($sock, 1, 3, "foo", "fooval");

# Set shouldn't work after 5 secs.
sleep(5);
print $sock "rj 1 3 set foo 0 0 6\r\n";
is(scalar <$sock>, "REFRESH_AND_RETRY\r\n", "store foo failed");
is(scalar <$sock>, "VALUE REJIG_CONFIG_STORAGE_KEY 0 12\r\n", "store foo failed");
is(scalar <$sock>, "dummy_config\r\n", "store foo failed");
is(scalar <$sock>, "END\r\n", "store bar failed");
@lease_stats = mem_lease_stats($sock);
is(@lease_stats[2], "expired", "lease not expired");

# Set a lease on fragment 3 for 60 secs.
print $sock "rj 1 3 grant 60\r\n";
is(scalar <$sock>, "GRANTED\r\n", "grant lease failed");

# Set foo with config id 1 and fragment 3 (and should get it).
print $sock "rj 1 3 set foo 0 0 6\r\nfooval\r\n";
is(scalar <$sock>, "STORED\r\n", "stored foo");
rejig_mem_get_is($sock, 1, 3, "foo", "fooval");

# Revoke lease.
print $sock "rj 1 3 revoke\r\n";
is(scalar <$sock>, "REVOKED\r\n", "revoke lease failed");

# Set shouldn't work after lease revoke.
print $sock "rj 1 3 set foo 0 0 6\r\n";
is(scalar <$sock>, "REFRESH_AND_RETRY\r\n", "store foo failed");
is(scalar <$sock>, "VALUE REJIG_CONFIG_STORAGE_KEY 0 12\r\n", "store foo failed");
is(scalar <$sock>, "dummy_config\r\n", "store foo failed");
is(scalar <$sock>, "END\r\n", "store bar failed");

# Revoke, and Grant shouldn't work on lease number greater than 10.
print $sock "rj 1 11 grant 30\r\n";
is(scalar <$sock>, "CLIENT_ERROR fragment num larger than number of fragments\r\n", "grant lease failed");
print $sock "rj 1 11 revoke\r\n";
is(scalar <$sock>, "CLIENT_ERROR fragment num larger than number of fragments\r\n", "revoke lease failed");

# Revoke, and Grant shouldn't work on lease number less than 0.
print $sock "rj 1 -1 grant 30\r\n";
is(scalar <$sock>, "ERROR\r\n", "grant lease failed");
print $sock "rj 1 -1 revoke\r\n";
is(scalar <$sock>, "ERROR\r\n", "revoke lease failed");

# Set a lease on fragment 3 for 300 secs.
print $sock "rj 1 3 grant 300\r\n";
is(scalar <$sock>, "GRANTED\r\n", "grant lease failed");

# Set bar with config id 2 (should get it, and
# config id should now be 2, and the config object deleted).
print $sock "rj 2 3 set bar 0 0 6\r\nbarval\r\n";
is(scalar <$sock>, "STORED\r\n", "stored bar");
rejig_mem_get_is($sock, 2, 3, "bar", "barval");
$stats = mem_stats($sock);
is($stats->{rejig_config_id}, 2);
print $sock "get REJIG_CONFIG_STORAGE_KEY\r\n";
is(scalar <$sock>, "END\r\n", "get config object");

# Set foo with config id 1 (should fail).
print $sock "rj 1 3 set foo 0 0 7\r\n";
is(scalar <$sock>, "REFRESH_AND_RETRY\r\n", "store foo failed");
is(scalar <$sock>, "END\r\n", "store foo failed");

# Set foo with config id 2 but fragment 1 (should fail).
print $sock "rj 2 1 set foo 0 0 7\r\n";
is(scalar <$sock>, "REFRESH_AND_RETRY\r\n", "store foo failed");
is(scalar <$sock>, "END\r\n", "store foo failed");

# Set the config object with only 5 fragments.
print $sock "rj 2 5 conf 0 0 14\r\ndummy_config_2\r\n";
is(scalar <$sock>, "STORED\r\n", "stored config");
$stats = mem_stats($sock);
is($stats->{rejig_config_id}, 2);
@lease_stats = mem_lease_stats($sock);
is(@lease_stats[2], "valid", "lease discarded");
is(scalar @lease_stats, 5, "lease list length change failed");
mem_get_is($sock, "REJIG_CONFIG_STORAGE_KEY", "dummy_config_2");

# Get bar with config id 1 (should fail, and return config).
print $sock "rj 1 3 set bar 0 0 7\r\n";
is(scalar <$sock>, "REFRESH_AND_RETRY\r\n", "store bar failed");
is(scalar <$sock>, "VALUE REJIG_CONFIG_STORAGE_KEY 0 14\r\n", "store bar failed");
is(scalar <$sock>, "dummy_config_2\r\n", "store bar failed");
is(scalar <$sock>, "END\r\n", "store bar failed");

# Get bar with config id 2 but fragment 1 (should fail, and return config).
print $sock "rj 2 1 set bar 0 0 7\r\n";
is(scalar <$sock>, "REFRESH_AND_RETRY\r\n", "store bar failed");
is(scalar <$sock>, "VALUE REJIG_CONFIG_STORAGE_KEY 0 14\r\n", "store bar failed");
is(scalar <$sock>, "dummy_config_2\r\n", "store bar failed");
is(scalar <$sock>, "END\r\n", "store bar failed");

# Multi get should fail if passed config id is smaller than current config id.
print $sock "rj 1 3 get foo bar\r\n";
is(scalar <$sock>, "REFRESH_AND_RETRY\r\n");
is(scalar <$sock>, "VALUE REJIG_CONFIG_STORAGE_KEY 0 14\r\n", "get foo, bar failed");
is(scalar <$sock>, "dummy_config_2\r\n", "get foo, bar failed");
is(scalar <$sock>, "END\r\n", "get foo, bar failed");

# Set the config object with only 15 fragments.
print $sock "rj 3 15 conf 0 0 14\r\ndummy_config_3\r\n";
is(scalar <$sock>, "STORED\r\n", "stored config");
$stats = mem_stats($sock);
is($stats->{rejig_config_id}, 3);
@lease_stats = mem_lease_stats($sock);
is(@lease_stats[2], "valid", "lease discarded");
is(scalar @lease_stats, 15, "lease list length change failed");
mem_get_is($sock, "REJIG_CONFIG_STORAGE_KEY", "dummy_config_3");
