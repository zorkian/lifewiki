#!/usr/bin/perl

package LifeWiki::Plugin::OpenIDServer;

use strict;
use Net::OpenID::Server;

our %opts;

# the init function is called as soon as a plugin is loaded.  you can do any
# initialization stuff you'd like to do here.
sub init {
    # adding a component root enables the Mason backend that LifeWiki runs on
    # to search for files you've created
    LifeWiki::addComponentRoot('plugins/OpenIDServer/htdocs');

    # get some options
    %opts = %{ shift() || {} };
    die "Error: need private_key, public_key for OpenID server plugin\n"
        unless $opts{private_key} && $opts{public_key};

    # set extra hook for dumping openid server information
    LifeWiki::addHook('page_head_content', sub {
        return qq{<link rel="openid.server" href="$LifeWiki::SITEROOT/openid/verify" />};
    });

    # must return 1 to indicate that we're setup correctly
    return 1;
}

sub is_identity {
    my ($u, $url) = @_;
    return 0 unless $u;

    # this is probably unsafe, don't care right now -- just getting this working
    my $canon = "$LifeWiki::SITEROOT/" . $u->getUsername;
    return 1 if $url =~ m/^$canon(?:\/.*)?$/;
    return 0;
}

sub is_trusted {
    my ($u, $root, $identity) = @_;
    return 0 unless $u && $identity;

    # yeah, sure, whatever, we'll identify to anybody
    return 1;
}

1;
