#!/usr/bin/perl

package LifeWiki::Auth::LDAP;

use strict;
use Net::LDAP;
use Digest::MD5 qw(md5);
use Digest::SHA1 qw(sha1);
use MIME::Base64;

our $opts;

my @subs = qw( getLoginURL tryVerify canLoginManually allowNullPasswords );

sub enable {
    # move us into the standard namespace
    $opts = shift() || {};
    die "Need: base, server, port for LDAP information.\n"
        unless $opts->{base} && $opts->{server} && $opts->{port};

    foreach my $sub (@subs) {
        eval "*LifeWiki::Auth::$sub = \\*LifeWiki::Auth::LDAP::$sub;"
            or return 0;
    }
    return 1;
}

sub getLoginURL {
    return $LifeWiki::SITEROOT . "/ldap";
}

# given an Apache::Request, note you can use $r->param() to get at parameters
sub tryVerify {
    my $r = shift;

    # see if we got a username/password
    my ($un, $pw) = ($r->param('username'), $r->param('password'));
    return undef unless $un && $pw;

    # step 1: connect to LDAP server
    my $ldap = Net::LDAP->new($opts->{server}, port => $opts->{port});
    unless ($ldap) {
        $@ = "Unable to access LDAP server (round 1)";
        return undef;
    }
    $ldap->bind;

    # now search for this username
    my $dn = $ldap->search(base => $opts->{base},
                           scope => "sub",
                           filter => "uid=$un")->pop_entry;
    unless ($dn) {
        $@ = "Username not found in LDAP server";
        return undef;
    }

    # extract the userdn
    my $userdn = $dn->dn();
    $ldap->unbind;

    # now rebind with the userdn
    $ldap = Net::LDAP->new($opts->{server}, port => $opts->{port});
    unless ($ldap) {
        $@ = "Unable to access LDAP server (round 2)";
        return undef;
    }
    my $bind = $ldap->bind($userdn);
    unless ($bind) {
        $@ = "Unable to bind to username on LDAP server";
        return undef;
    }

    # and try to extract the full user record
    my $userentry = $ldap->search(base => $opts->{base},
                                  scope => "sub",
                                  filter => "uid=$un")->pop_entry;
    unless ($userentry) {
        $@ = "Unable to locate full user record on LDAP server";
        return undef;
    }

    # now get their user password field
    my $up = $userentry->get_value('userPassword');
    unless ($up) {
        $@ = "Unable to locate userPassword field in user record from LDAP server";
        return undef;
    }

    # get auth type and data, then decode it
    unless ($up =~ /^\{(\w+)\}(.+)$/) {
        $@ = "userPassword field from LDAP server ont of expected format; received: $up";
        return undef;
    }
    my ($auth, $data) = ($1, decode_base64($2));

    # what type of auth are they doing?
    if ($auth eq 'MD5') {
        unless ($data eq md5($pw)) {
            $@ = "Password mismatch (MD5) from LDAP server; is your password correct?";
            return undef;
        }
        
    } elsif ($auth eq 'SSHA') {
        my $salt = substr($data, 20);
        my $orig = substr($data, 0, 20);
        unless ($orig eq sha1($pw, $salt)) {
            $@ = "Password mismatch (SSHA) from LDAP server; is your password correct?";
            return undef;
        }

    } else {
        $@ = "userPassword field from LDAP server not of supported format; received: $up";
        return undef;
    }

    # see if we have all the info needed
    my ($nick, $email) = ($userentry->get_value('gecos'), $userentry->get_value('mailLocalAddress'));
    unless ($nick && $email) {
        $@ = "Necessary information not found in LDAP record: name=$nick; email=$email";
        return undef;
    }

    # $res comes out as...?
    my $res = {
        name => $un,
        nick => $nick,
        email => $email,
    };

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
