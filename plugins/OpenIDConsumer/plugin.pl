#!/usr/bin/perl

package LifeWiki::Plugin::OpenIDConsumer;

use strict;
use Net::OpenID::Consumer;
use LWPx::ParanoidAgent;

# the init function is called as soon as a plugin is loaded.  you can do any
# initialization stuff you'd like to do here.
sub init {
    # adding a component root enables the Mason backend that LifeWiki runs on
    # to search for files you've created
    LifeWiki::addComponentRoot('plugins/OpenIDConsumer/htdocs');

    # must return 1 to indicate that we're setup correctly
    return 1;
}

sub getVerifyRedirectURL {
    my $args = shift;

    my $csr = Net::OpenID::Consumer->new;
    return LifeWiki::error('unable to create Net::OpenID::Consumer object')
        unless $csr;

    $csr->ua(LWPx::ParanoidAgent->new);
    $csr->args($args);

    my $cident = $csr->claimed_identity($args->{'openid_url'});
    return LifeWiki::error('unable to determine claimed identity: ' . $csr->err)
        unless $cident;

    my $url = $cident->check_url(
        return_to => "$LifeWiki::SITEROOT/openid/check",
        delayed_return => 1,
        trust_root => "$LifeWiki::SITEROOT/",
    );
    print STDERR "[$url]\n";
    return $url;
}

sub tryVerify {
    my $args = shift;

    my $csr = Net::OpenID::Consumer->new;
    print STDERR "[$args, $csr]\n";
    return LifeWiki::error('unable to create Net::OpenID::Consumer object')
        unless $csr;

    $csr->ua(LWPx::ParanoidAgent->new);
    $csr->args($args);

    if (my $setup_url = $csr->user_setup_url(post_grant => 'return')) {
        print STDERR "{$setup_url}\n";
        return $setup_url;
    } elsif (my $vident = $csr->verified_identity) {
        # FIXME: Net::OpenID::UserProfile would be useful here
        print STDERR "{$vident, " . $vident->url . "}\n";
        return {
            name => undef,
            nick => undef,
            password => undef,
            email => undef,
            external => $vident->url,
        };
    } else {
        return LifeWiki::error('error validating identity: ' . $csr->err);
    }
}
