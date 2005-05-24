#!/usr/bin/perl

package LifeWiki::Plugin::TypeKeyAuth;

use strict;
use Authen::TypeKey;

our %opts;
our $tk;

# the init function is called as soon as a plugin is loaded.  you can do any
# initialization stuff you'd like to do here.
sub init {
    # adding a component root enables the Mason backend that LifeWiki runs on
    # to search for files you've created
    LifeWiki::addComponentRoot('plugins/TypeKeyAuth/htdocs');

    # get some options
    %opts = %{ shift() || {} };
    die "Error: need token for TypeKey auth plugin\n"
        unless $opts{token};

    # setup our typekey
    $tk = Authen::TypeKey->new;
    $tk->token($opts{token});

    # must return 1 to indicate that we're setup correctly
    return 1;
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
