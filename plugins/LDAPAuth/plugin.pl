#!/usr/bin/perl

package LifeWiki::Plugin::LDAPAuth;

use strict;
use Net::LDAP;
use Digest::MD5 qw(md5);
use Digest::SHA1 qw(sha1);
use MIME::Base64;

our %opts;

# the init function is called as soon as a plugin is loaded.  you can do any
# initialization stuff you'd like to do here.
sub init {
    # adding a component root enables the Mason backend that LifeWiki runs on
    # to search for files you've created
    LifeWiki::addComponentRoot('plugins/LDAPAuth/htdocs');

    # get some options
    %opts = %{ shift() || {} };
    die "Error: need base, server, port for LDAP auth module\n"
        unless $opts{base} && $opts{server} && $opts{port};

    # must return 1 to indicate that we're setup correctly
    return 1;
}

# verification sub that attempts to authenticate a username and password
# for a user coming in over LDAP given an Apache::Request, note you can use
# $r->param() to get at parameters
sub tryVerify {
    my $r = shift;

    # see if we got a username/password
    my ($un, $pw) = ($r->param('username'), $r->param('password'));
    return LifeWiki::error("Username and password not provided")
        unless $un && $pw;

    # step 1: connect to LDAP server
    my $ldap = Net::LDAP->new($opts{server}, port => $opts{port});
    return LifeWiki::error("Unable to access LDAP server (round 1)")
        unless $ldap;
    $ldap->bind;

    # now search for this username
    my $dn = $ldap->search(base => $opts{base},
                           scope => "sub",
                           filter => "uid=$un")->pop_entry;
    return LifeWiki::error("Username not found in LDAP server")
        unless $dn;

    # extract the userdn and unbind
    my $userdn = $dn->dn();
    $ldap->unbind;

    # now rebind with the userdn
    $ldap = Net::LDAP->new($opts{server}, port => $opts{port});
    return LifeWiki::error("Unable to access LDAP server (round 2)")
        unless $ldap;

    # now attempt to bind to the updated dn
    my $bind = $ldap->bind($userdn);
    return LifeWiki::error("Unable to bind to username on LDAP server")
        unless $bind;

    # and try to extract the full user record
    my $userentry = $ldap->search(base => $opts{base},
                                  scope => "sub",
                                  filter => "uid=$un")->pop_entry;
    return LifeWiki::error("Unable to locate full user record on LDAP server")
        unless $userentry;

    # now get their user password field
    my $up = $userentry->get_value('userPassword');
    return LifeWiki::error("Unable to locate userPassword field in user record from LDAP server")
        unless $up;

    # get auth type and data, then decode it
    return LifeWiki::error("userPassword field from LDAP server ont of expected format; received: $up")
        unless $up =~ /^\{(\w+)\}(.+)$/;
    my ($auth, $data) = ($1, decode_base64($2));

    # what type of auth are they doing?
    if ($auth eq 'MD5') {
        return LifeWiki::error("Password mismatch (MD5) from LDAP server; is your password correct?")
            unless $data eq md5($pw);

    } elsif ($auth eq 'SMD5') {
        my $salt = substr($data, 16);
        my $orig = substr($data, 0, 16);
        return LifeWiki::error("Password mismatch (SMD5) from LDAP server; is your password correct?")
            unless $orig eq md5($pw, $salt);

    } elsif ($auth eq 'SSHA') {
        my $salt = substr($data, 20);
        my $orig = substr($data, 0, 20);
        return LifeWiki::error("Password mismatch (SSHA) from LDAP server; is your password correct?")
            unless $orig eq sha1($pw, $salt);

    } else {
        return LifeWiki::error("userPassword field from LDAP server not of supported format; received: $up");
    }

    # see if we have all the info needed
    my ($nick, $email) = ($userentry->get_value('gecos'), $userentry->get_value('mailLocalAddress'));
    return LifeWiki::error("Necessary information not found in LDAP record: name=$nick; email=$email")
        unless $nick && $email;

    # $res comes out as...?
    my $res = {
        name => $un,
        nick => $nick,
        email => $email,
    };

    return $res;
}

1;
