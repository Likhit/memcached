#!/usr/bin/perl

# The same test as in getset.t but using rejig commands instead.

use strict;
use Test::More tests => 630;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;


my $server = new_memcached();
my $sock = $server->sock;
my $config_id = 1;

# set foo (and should get it)
print $sock "rj $config_id set foo 0 0 6\r\nfooval\r\n";
is(scalar <$sock>, "STORED\r\n", "stored foo");
rejig_mem_get_is($sock, $config_id, "foo", "fooval");

# add bar (and should get it)
print $sock "rj $config_id add bar 0 0 6\r\nbarval\r\n";
is(scalar <$sock>, "STORED\r\n", "stored barval");
rejig_mem_get_is($sock, $config_id, "bar", "barval");

# add foo (but shouldn't get new value)
print $sock "rj $config_id add foo 0 0 5\r\nfoov2\r\n";
is(scalar <$sock>, "NOT_STORED\r\n", "not stored");
rejig_mem_get_is($sock, $config_id, "foo", "fooval");

# replace bar (should work)
print $sock "rj $config_id replace bar 0 0 6\r\nbarva2\r\n";
is(scalar <$sock>, "STORED\r\n", "replaced barval 2");

# replace notexist (shouldn't work)
print $sock "rj $config_id replace notexist 0 0 6\r\nbarva2\r\n";
is(scalar <$sock>, "NOT_STORED\r\n", "didn't replace notexist");

# delete foo.
print $sock "rj $config_id delete foo\r\n";
is(scalar <$sock>, "DELETED\r\n", "deleted foo");

# delete foo again.  not found this time.
print $sock "rj $config_id delete foo\r\n";
is(scalar <$sock>, "NOT_FOUND\r\n", "deleted foo, but not found");

# add moo
print $sock "rj $config_id add moo 0 0 6\r\nmooval\r\n";
is(scalar <$sock>, "STORED\r\n", "stored barval");
rejig_mem_get_is($sock, $config_id, "moo", "mooval");

# check-and-set (cas) failure case, try to set value with incorrect cas unique val
print $sock "rj $config_id cas moo 0 0 6 0\r\nMOOVAL\r\n";
is(scalar <$sock>, "EXISTS\r\n", "check and set with invalid id");

# test "gets", grab unique ID
print $sock "rj $config_id gets moo\r\n";
# VALUE moo 0 6 3084947704
#
my @retvals = split(/ /, scalar <$sock>);
my $data = scalar <$sock>; # grab data
my $dot  = scalar <$sock>; # grab dot on line by itself
is($retvals[0], "VALUE", "get value using 'gets'");
my $unique_id = $retvals[4];
ok($unique_id =~ /^\d+$/, "unique ID '$unique_id' is an integer");
# clean off \r\n
my $ret_config_id = $retvals[5];
$ret_config_id =~ s/\r\n$//;
is($ret_config_id, $config_id, "get value using 'gets'");
# now test that we can store moo with the correct unique id
print $sock "rj $config_id cas moo 0 0 6 $unique_id\r\nMOOVAL\r\n";
is(scalar <$sock>, "STORED\r\n");
rejig_mem_get_is($sock, $config_id, "moo", "MOOVAL");

# pipeline is okay
print $sock "rj $config_id set foo 0 0 6\r\nfooval\r\nrj $config_id delete foo\r\nrj $config_id set foo 0 0 6\r\nfooval\r\nrj $config_id delete foo\r\n";
is(scalar <$sock>, "STORED\r\n",  "pipeline set");
is(scalar <$sock>, "DELETED\r\n", "pipeline delete");
is(scalar <$sock>, "STORED\r\n",  "pipeline set");
is(scalar <$sock>, "DELETED\r\n", "pipeline delete");

# Multi get tests

# Multi get should return the config id for each key
# even if it is different.
print $sock "rj $config_id set foo 0 0 6\r\nfooval\r\n";
is(scalar <$sock>, "STORED\r\n", "stored foo");
rejig_mem_get_is($sock, $config_id, "foo", "fooval");
$config_id = 2;
print $sock "rj $config_id set bar 0 0 6\r\nbarval\r\n";
is(scalar <$sock>, "STORED\r\n", "stored bar");
rejig_mem_get_is($sock, $config_id, "bar", "barval");
print $sock "rj $config_id get foo bar\r\n";
is(scalar <$sock>, "VALUE foo 0 6 1\r\n");
is(scalar <$sock>, "fooval\r\n");
is(scalar <$sock>, "VALUE bar 0 6 2\r\n");
is(scalar <$sock>, "barval\r\n");
is(scalar <$sock>, "END\r\n");

# Multi get with more than MAX_TOKENS should still work correctly.

print $sock "rj $config_id get foo bar foo bar foo bar foo bar foo bar foo bar foo bar foo bar foo bar foo bar foo bar foo bar foo bar foo bar foo bar foo bar foo bar foo bar foo bar foo bar\r\n";
my $i = 0;
while ($i < 20) {
    is(scalar <$sock>, "VALUE foo 0 6 1\r\n");
    is(scalar <$sock>, "fooval\r\n");
    is(scalar <$sock>, "VALUE bar 0 6 2\r\n");
    is(scalar <$sock>, "barval\r\n");
    $i += 1;
}
is(scalar <$sock>, "END\r\n");

# Test sets up to a large size around 1MB.
# Everything up to 1MB - 1k should succeed, everything 1MB +1k should fail.

my $len = 1024;
while ($len < 1024*1028) {
    my $val = "B"x$len;
    if ($len > (1024*1024)) {
        # Ensure causing a memory overflow doesn't leave stale data.
        print $sock "rj $config_id set foo_$len 0 0 3\r\nMOO\r\n";
        is(scalar <$sock>, "STORED\r\n");
        print $sock "rj $config_id set foo_$len 0 0 $len\r\n$val\r\n";
        is(scalar <$sock>, "SERVER_ERROR object too large for cache\r\n", "failed to store size $len");
        rejig_mem_get_is($sock, $config_id, "foo_$len");
    } else {
        print $sock "rj $config_id set foo_$len 0 0 $len\r\n$val\r\n";
        is(scalar <$sock>, "STORED\r\n", "stored size $len");
    }
    $len += 2048;
}
