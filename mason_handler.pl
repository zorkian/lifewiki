#!/usr/bin/perl

package LifeWiki::HTML;

use strict;
use lib "$ENV{LIFEWIKIHOME}/lib";

use HTML::Mason::ApacheHandler;
use Apache::Request;

# import our configuration from the user
require "$ENV{LIFEWIKIHOME}/etc/config.pl";

{
    package HTML::Mason::Commands;

    # Define perl modules available to all components.
    use Apache::Cookie;
    use Apache::DBI;
    use DBI;
    use Digest::MD5 qw(md5_hex);

    # now bring in our modules
    use LifeWiki;
    use LifeWiki::User;
    use LifeWiki::Page;
    use LifeWiki::Namespace;

    # our custom handlers
    use LifeWiki::Auth::LDAP;

    # require the markdown library
    $blosxom::version = 1; # hah
    require 'Markdown.pl';

    # now setup the authentication agent we want
    LifeWiki::setAuthAgent("LDAP", {
        server => 'ldap.sixapart.com',
        base => 'ou=People,dc=sixapart,dc=com',
        port => 389,
    })
        or die "Unable to load auth module: $@\n";

    # setup a connection to our database
    my ($db, $h, $un, $pw) = map { $LifeWiki::DBCONFIG{$_} } qw(database host username password);
    $HTML::Mason::Commands::dbh = DBI->connect("DBI:mysql:$db:$h", $un, $pw);
}

# Create Mason object.
my $ah = HTML::Mason::ApacheHandler->new(
    comp_root           => '/home/mark/lifewiki/htdocs',
    data_dir            => '/home/mark/lifewiki/mason',
    autohandler_name    => 'autohandler',
    dhandler_name       => 'dhandler',
    error_mode          => 'output',
    allow_globals       => [qw/ %opts $dbh $remote %cookies $head $title $page $did_post /],
    autoflush           => 0,
    code_cache_max_size => 10485760,
    static_source       => 0,
);

sub handler
{
    my $r = shift;

    # setup the user and such
    %HTML::Mason::Commands::opts = ();
    %HTML::Mason::Commands::cookies = Apache::Cookie->fetch;
    $HTML::Mason::Commands::remote = LifeWiki::User->newFromCookies(\%HTML::Mason::Commands::cookies);
    $HTML::Mason::Commands::did_post = ($r->method eq 'POST' ? 1 : 0);
    $HTML::Mason::Commands::title = "boring lack of a title";
    $HTML::Mason::Commands::page = undef;
    $HTML::Mason::Commands::head = "";

    # now run the request
    my $status = $ah->handle_request($r);
    return $status;
}

1;
