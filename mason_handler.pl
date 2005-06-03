#!/usr/bin/perl

package LifeWiki::HTML;

use strict;
use lib "$ENV{LIFEWIKIHOME}/lib";

# import our configuration from the user
require "$ENV{LIFEWIKIHOME}/etc/config.pl";

use HTML::Mason::ApacheHandler;
use Apache::Request;

{
    package HTML::Mason::Commands;

    # Define perl modules available to all components.
    use Apache::Cookie;
    use Apache::DBI;
    use DBI;
    use Cache::FileCache;
    use HTML::TokeParser;
    use HTML::Diff;

    # now bring in our modules
    use LifeWiki;
    use LifeWiki::User;
    use LifeWiki::Page;
    use LifeWiki::Namespace;

    # require the markdown library
    $blosxom::version = 1; # hah
    require 'Markdown.pl';

    # now that we have what we need, process plugins
    foreach my $plugin (@LifeWiki::PLUGINS) {
        my ($name, $opts);
        if (ref $plugin) {
            ($name, $opts) = @$plugin;
        } else {
            $name = $plugin;
        }

        my $path = "$ENV{LIFEWIKIHOME}/plugins/$name";
        die "Plugin directory $path does not exist or is not a directory\n" unless -d $path;

        eval "require '$path/plugin.pl';";
        my $rv = eval "return LifeWiki::Plugin::${name}::init(\$opts);";
        die "Plugin $name failed to return 1 ($rv) from init(): $@\n" unless $rv;
    }

    # now setup the httpd.conf
    Apache->httpd_conf(qq{
# Basic configuration
DirectoryIndex index index.html
ServerName $LifeWiki::DOMAIN
DocumentRoot $LifeWiki::DOCROOT

# Handle everything default
<Location />
    DefaultType text/html
    SetHandler perl-script
    PerlHandler LifeWiki::HTML
</Location>

# Serve regular files outside of the scope of Mason
<LocationMatch "\.(css|js|png|jpg|jpeg|gif)">
    SetHandler default-handler
</LocationMatch>

# DO NOT serve files with a .m extension and do not serve the
# autohandlers and dhandlers that we have setup
<LocationMatch "(\.m|dhandler|autohandler)$">
    SetHandler perl-script
    PerlInitHandler Apache::Constants::NOT_FOUND
</LocationMatch>
    });

    # and now, if we have a custom theme...
    if ($LifeWiki::CUSTOM_THEME_DIR) {
        Apache->httpd_conf("Alias /theme $LifeWiki::CUSTOM_THEME_DIR");
    }

    # now setup image aliases
    if (@LifeWiki::IMGDIR) {
        Apache->httpd_conf("Alias $_->[0] $_->[1]")
            foreach @LifeWiki::IMGDIR;
    }
}

# push onto the component root at the end
push @LifeWiki::COMPROOT, [ base => "$ENV{LIFEWIKIHOME}/htdocs" ];

# Create Mason object.
my $ah = HTML::Mason::ApacheHandler->new(
    comp_root           => \@LifeWiki::COMPROOT,
    data_dir            => "$ENV{LIFEWIKIHOME}/mason",
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

    # setup a connection to our database
    my ($db, $h, $un, $pw) = map { $LifeWiki::DBCONFIG{$_} } qw(database host username password);
    $HTML::Mason::Commands::dbh = DBI->connect("DBI:mysql:$db:$h", $un, $pw);

    # setup the user and such
    %HTML::Mason::Commands::opts = ();
    %HTML::Mason::Commands::cookies = Apache::Cookie->fetch;
    $HTML::Mason::Commands::remote = LifeWiki::User->newFromCookies(\%HTML::Mason::Commands::cookies);
    $HTML::Mason::Commands::did_post = ($r->method eq 'POST' ? 1 : 0);
    $HTML::Mason::Commands::title = "boring lack of a title";
    $HTML::Mason::Commands::page = undef;
    $HTML::Mason::Commands::head = "";

    # lifewiki engine setup
    LifeWiki::clearErrors();

    # and now reset the caches
    LifeWiki::clearCaches();

    # now run the request
    my $status = $ah->handle_request($r);
    return $status;
}

1;
