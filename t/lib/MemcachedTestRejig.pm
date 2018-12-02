package MemcachedTestRejig;
use strict;
use Exporter 'import';
use Carp qw(croak);
use vars qw(@EXPORT);
use MemcachedTest;

@EXPORT = qw(rejig_mem_get_is mem_lease_stats all_in_list);

# rejig version of mem_get_is.
sub rejig_mem_get_is {
  # works on single-line values only.  no newlines in value.
    my ($sock_opts, $config_id, $fragment_num, $key, $val, $msg) = @_;
    my $opts = ref $sock_opts eq "HASH" ? $sock_opts : {};
    my $sock = ref $sock_opts eq "HASH" ? $opts->{sock} : $sock_opts;

    my $expect_flags = $opts->{flags} || 0;
    my $dval = defined $val ? "'$val'" : "<undef>";
    $msg ||= "$key == $dval";

    print $sock "rj $config_id $fragment_num get $key\r\n";
    if (! defined $val) {
        my $line = scalar <$sock>;
        if ($line =~ /^VALUE/) {
            $line .= scalar(<$sock>) . scalar(<$sock>);
        }
        Test::More::is($line, "END\r\n", $msg);
    } else {
        my $len = length($val);
        my $body = scalar(<$sock>);
        my $expected = "VALUE $key $expect_flags $len $config_id\r\n$val\r\nEND\r\n";
        if (!$body || $body =~ /^END/) {
            Test::More::is($body, $expected, $msg);
            return;
        }
        $body .= scalar(<$sock>) . scalar(<$sock>);
        Test::More::is($body, $expected, $msg);
    }
}

sub mem_lease_stats {
    my ($sock) = @_;
    print $sock "stats leases\r\n";
    my @stats = ();
    while (<$sock>) {
        last if /^(\.|END)/;
        /^STAT (\d+)\:fragment ((?:never)|(?:valid)|(?:expired)).*/;
        if ($2 eq "never") { push(@stats, "revoked"); }
        elsif ($2 eq "valid") { push(@stats, "valid"); }
        elsif ($2 eq "expired") { push(@stats, "expired"); }
        else { push(@stats, "this shouldn't be happening"); }
    }
    return @stats;
}

sub all_in_list {
    my ($should_be, @ls) = @_;
    my $i = 0;
    for my $l (@ls) {
        if ($l ne $should_be) {
            print "Element $i is $l. should be $should_be\n";
            return 0;
        }
        $i += 1;
    }
    return 1;
}
