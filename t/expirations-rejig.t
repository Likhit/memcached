#!/usr/bin/perl

# The same test as in expirations.t but using rejig commands instead.

use strict;
use Test::More tests => 17;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;

my $server = new_memcached();
my $sock = $server->sock;
my $expire;
my $config_id = 1;
my $fragment_id = 1;
my $fragment_lease_time = 300;

# Initialize the config and number of fragments.
print $sock "rj $config_id $fragment_id conf 0 0 12\r\ndummy_config\r\n";
is(scalar <$sock>, "STORED\r\n", "stored config");

# Grant a lease on the fragment
print $sock "rj $config_id $fragment_id grant $fragment_lease_time\r\n";
is(scalar <$sock>, "GRANTED\r\n", "granted lease");

sub wait_for_early_second {
    my $have_hires = eval "use Time::HiRes (); 1";
    if ($have_hires) {
        my $tsh = Time::HiRes::time();
        my $ts = int($tsh);
        return if ($tsh - $ts) < 0.5;
    }

    my $ts = int(time());
    while (1) {
        my $t = int(time());
        return if $t != $ts;
        select undef, undef, undef, 0.10;  # 1/10th of a second sleeps until time changes.
    }
}

wait_for_early_second();

print $sock "rj $config_id $fragment_id set foo 0 3 6\r\nfooval\r\n";
is(scalar <$sock>, "STORED\r\n", "stored foo");

mem_get_is($sock, "foo", "fooval");
sleep(4);
rejig_mem_get_is($sock, $config_id, $fragment_id, "foo", undef);

$expire = time() - 1;
print $sock "rj $config_id $fragment_id set foo 0 $expire 6\r\nfooval\r\n";
is(scalar <$sock>, "STORED\r\n", "stored foo");
rejig_mem_get_is($sock, $config_id, $fragment_id, "foo", undef, "already expired");

$expire = time() + 1;
print $sock "rj $config_id $fragment_id set foo 0 $expire 6\r\nfoov+1\r\n";
is(scalar <$sock>, "STORED\r\n", "stored foo");
rejig_mem_get_is($sock, $config_id, $fragment_id, "foo", "foov+1");
sleep(2.2);
rejig_mem_get_is($sock, $config_id, $fragment_id, "foo", undef, "now expired");

$expire = time() - 20;
print $sock "rj $config_id $fragment_id set boo 0 $expire 6\r\nbooval\r\n";
is(scalar <$sock>, "STORED\r\n", "stored boo");
rejig_mem_get_is($sock, $config_id, $fragment_id, "boo", undef, "now expired");

print $sock "rj $config_id $fragment_id add add 0 2 6\r\naddval\r\n";
is(scalar <$sock>, "STORED\r\n", "stored add");
rejig_mem_get_is($sock, $config_id, $fragment_id, "add", "addval");
# second add fails
print $sock "rj $config_id $fragment_id add add 0 2 7\r\naddval2\r\n";
is(scalar <$sock>, "NOT_STORED\r\n", "add failure");
sleep(2.3);
print $sock "rj $config_id $fragment_id add add 0 2 7\r\naddval3\r\n";
is(scalar <$sock>, "STORED\r\n", "stored add again");
rejig_mem_get_is($sock, $config_id, $fragment_id, "add", "addval3");
