#!/usr/bin/perl

package LifeWiki::Auth::TypeKey;

use strict;
use Authen::TypeKey;

our $opts;
our $tk;

my @subs = qw( getLoginURL tryVerify canLoginManually allowNullPasswords );

sub enable {
    # move us into the standard namespace
    $opts = shift() || {};
    die "Need argument 'token' at least for TypeKey auth\n"
        unless $opts->{token};

    $tk = Authen::TypeKey->new;
    $tk->token($opts->{token});

    foreach my $sub (@subs) {
        eval "*LifeWiki::Auth::$sub = \\*LifeWiki::Auth::TypeKey::$sub;"
            or return 0;
    }
    return 1;
}

sub getLoginURL {
    my $res = "https://www.typekey.com/t/typekey/login";
    $res .= "?t=" . $opts->{token};
    $res .= "&need_email=1" if $opts->{need_email};
    $res .= "&_return=" . $LifeWiki::SITEROOT . "/typekey";
    $res .= "&v=1.1";
    return $res;
}

# given an Apache::Request, note you can use $r->param() to get at parameters
sub tryVerify {
    my $r = shift;

    my $res = $tk->verify($r);

    unless (defined $res) {
        $@ = "<b>TypeKey authentication error:</b> " . $tk->errstr . "\n";
        return undef;
    }

    delete $res->{email}
        unless $res->{email} =~ /@/;

    return $res;
}

# this disables the /login functionality
sub canLoginManually {
    return 0;
}

# yes, this is what we do
sub allowNullPasswords {
    return 1;
}

1;
