#!/usr/bin/perl

package LifeWiki::Plugin::OpenIDConsumer;

use strict;
use Net::OpenID::Consumer;
use LWPx::ParanoidAgent;

# setup options we'll use
our %opts;

# the init function is called as soon as a plugin is loaded.  you can do any
# initialization stuff you'd like to do here.
sub init {
    %opts = %{ shift() || {} };
    die "Need consumer_secret passed to OpenIDConsumer plugin\n"
        unless $opts{consumer_secret};

    # adding a component root enables the Mason backend that LifeWiki runs on
    # to search for files you've created
    LifeWiki::addComponentRoot('plugins/OpenIDConsumer/htdocs');

    # now setup our images
    LifeWiki::addImageDir('/images/openid', 'plugins/OpenIDConsumer/images');

    # setup some hooks we add
    LifeWiki::addHook('get_linked_user', sub {
        my $u = shift;
        return undef unless $u;

        my $nick = $u->getNick || $u->getUsername;
        return undef unless $nick;

        my $image = $u->getExternal;
        if ($image) {
            $image = qq{<a href="$image"><img src="$LifeWiki::SITEROOT/images/openid/openid.gif" style="vertical-align: bottom; border: 0;" alt="OpenID Identity" title="OpenID Identity" /></a>};
        }

        my $url = $u->getBioURL || $u->getHomeURL || $u->getExternal;
        if ($url) {
            $url = qq{<a href="$url">$nick</a>};
        } else {
            $url = "$nick";
        }

        return qq{<span style="white-space: nowrap;">$image$url</span>};
    });

    # biography output link
    LifeWiki::addHook('print_bio', sub {
        my $u = shift;
        return unless $u;

        my $externals = $u->getAllExternals;
        if ($externals && @$externals) {
            print "<p>Verified <a href='http://www.openid.net/'>OpenID</a> identities this account is connected with:</p><ul>";
            foreach my $ext (@$externals) {
                print "<li><a href='$ext'>$ext</a></li>\n";
            }
            print "</ul>\n";
        }
    });

    # extra page HTML we add
    LifeWiki::addHook('print_extra_page_html', sub {
        my ($page, $u) = @_;
        return unless $page && $u;

        if ($page eq 'prefs') {
            print "<p><a href='$LifeWiki::SITEROOT/openid/add-identity'>Associate Another Identity</a></p>";
        }
    });

    # must return 1 to indicate that we're setup correctly
    return 1;
}

# ( $args, $assoc )
# args from the post, assoc whether or not we're doing an association
sub getVerifyRedirectURL {
    my $args = shift;

    my $extra = "";
    $extra = "?assoc=1" if shift;
    $extra .= ($extra ? '&' : '?') . 'to=' . $args->{'to'}
        if $args->{'to'};

    my $csr = Net::OpenID::Consumer->new( consumer_secret => $opts{consumer_secret} );
    return LifeWiki::error('unable to create Net::OpenID::Consumer object')
        unless $csr;

    $csr->ua(LWPx::ParanoidAgent->new);
    $csr->args($args);

    my $cident = $csr->claimed_identity($args->{'openid_url'});
    return LifeWiki::error('unable to determine claimed identity: ' . $csr->err)
        unless $cident;

    my $url = $cident->check_url(
        return_to => "$LifeWiki::SITEROOT/openid/check$extra",
        delayed_return => 1,
        trust_root => "$LifeWiki::SITEROOT/",
    );
    return $url;
}

sub tryAssociate {
    my ($remote, $args) = @_;
    return LifeWiki::error("invalid arguments passed to tryAssociate")
        unless $remote && $args;

    my $csr = Net::OpenID::Consumer->new( consumer_secret => $opts{consumer_secret} );
    return LifeWiki::error('unable to create Net::OpenID::Consumer object')
        unless $csr;

    $csr->cache(Cache::FileCache->new);
    $csr->ua(LWPx::ParanoidAgent->new);
    $csr->args($args);

    if (my $setup_url = $csr->user_setup_url(post_grant => 'return')) {
        return $setup_url;
    } elsif (my $vident = $csr->verified_identity) {
        my $url = $vident->url;
        my $u = LifeWiki::User->newFromExternal($url);
        return LifeWiki::error("the identity '$url' is already associated with another account")
            if $u;
        return LifeWiki::error('error adding identity in database')
            unless $remote->addExternal($url);
        return { success => 1, url => $url };
    } else {
        return LifeWiki::error('error validating identity: ' . $csr->err);
    }
}

sub tryVerify {
    my $args = shift;

    my $csr = Net::OpenID::Consumer->new( consumer_secret => $opts{consumer_secret} );
    return LifeWiki::error('unable to create Net::OpenID::Consumer object')
        unless $csr;

    $csr->cache(Cache::FileCache->new);
    $csr->ua(LWPx::ParanoidAgent->new);
    $csr->args($args);

    if (my $setup_url = $csr->user_setup_url(post_grant => 'return')) {
        return $setup_url;
    } elsif (my $vident = $csr->verified_identity) {
        # FIXME: Net::OpenID::UserProfile would be useful here
        return {
            name => undef,
            nick => $vident->display,
            password => undef,
            email => undef,
            external => $vident->url,
        };
    } else {
        return LifeWiki::error('error validating identity: ' . $csr->err);
    }
}
