#!/usr/bin/perl

# The same test as in issue_140-rejig.t but using rejig commands instead.

use strict;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;

plan skip_all => 'Fix for Issue 140 was only an illusion';

plan tests => 9;

my $server = new_memcached();
my $sock = $server->sock;
my $config_id = 1;
my $fragment_id = 1;
my $fragment_lease_time = 300;

# Initialize the config and number of fragments.
print $sock "rj $config_id $fragment_id conf 0 0 12\r\ndummy_config\r\n";
is(scalar <$sock>, "STORED\r\n", "stored config");

# Grant a lease on the fragment
print $sock "rj $config_id $fragment_id grant $fragment_lease_time\r\n";
is(scalar <$sock>, "GRANTED\r\n", "granted lease");

print $sock "rj $config_id $fragment_id set a 0 0 1\r\na\r\n";
is (scalar <$sock>, "STORED\r\n", "stored key");

my $stats  = mem_stats($sock, "items");
my $age = $stats->{"items:1:age"};
isnt ($age, "0", "Age should not be zero");

print $sock "flush_all\r\n";
is (scalar <$sock>, "OK\r\n", "items flushed");

my $stats  = mem_stats($sock, "items");
my $age = $stats->{"items:1:age"};
is ($age, undef, "all should be gone");

print $sock "rj $config_id $fragment_id set a 0 1 1\r\na\r\n";
is (scalar <$sock>, "STORED\r\n", "stored key");

my $stats  = mem_stats($sock, "items");
my $age = $stats->{"items:1:age"};
isnt ($age, "0", "Age should not be zero");

sleep(3);

my $stats  = mem_stats($sock, "items");
my $age = $stats->{"items:1:age"};
is ($age, undef, "all should be gone");
