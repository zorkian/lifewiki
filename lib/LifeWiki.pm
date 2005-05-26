#!/usr/bin/perl

package LifeWiki;

use strict;

# lists of hooks that are defined...
#   ( hook_name => [ $runner, $runner, ... ] )
# hooks must return undef meaning "I didn't handle this" or a defined value which
# indicates they're actually returning something.
our %Hooks = ();

# component roots that plugins can modify
our @COMPROOT = ();
our @IMGDIR = ();

# storage for temporary error messages
our @Errors;

BEGIN {
    %LifeWiki::PRIVILEGE_TABLE = (
        create_namespaces => {
            id => 1,
            name => "Create Namespaces",
            desc => "Users with this privilege (no extra id needed) can create top level namespaces.",
        },

        moderate_namespace => {
            id => 2,
            name => "Edit Pages in a Namespace",
            desc => "Gives user full control over pages in a namespace.",
        },

        admin_namespace => {
            id => 3,
            name => "Control a Namespace",
            desc => "Gives user access to delete a namespace and manage moderators.",
        },

        moderate_page => {
            id => 4,
            name => "Moderage a Page",
            desc => "Gives user full control over content on an individual page.",
        },

        read_namespace => {
            id => 5,
            name => "View Pages in Namespace",
            desc => "Gives user ability to read unsecured pages in a secured namespace.",
        },

        read_page => {
            id => 6,
            name => "View Secured Page",
            desc => "Gives user ability to view a secured page.",
        },

        admin_page => {
            id => 7,
            name => "Control a Page",
            desc => "Gives user access to delete a page and manage permissions for it.",
        },
    );
}

sub getDatabase {
    # how we get the dbh for now
    return $HTML::Mason::Commands::dbh;
}

sub printErrors {
    return unless @Errors;

    my $s = scalar(@Errors) == 1 ? '' : 's';
    print("<div class='error_bar'><p>The following error$s occurred with your submission:</p><ul><li>" .
          join("</li><li>", @Errors) .
          "</li></ul></div>");
}

sub clearErrors {
    @Errors = ();
}

sub error {
    print STDERR "(error) $_[0]\n";
    push @Errors, shift();
    return undef;
}

sub clearCaches {
    # clear security caches per request
    %LifeWiki::CACHE_NMID_READSEC = ();
    %LifeWiki::CACHE_NMID_WRITESEC = ();

    # cached page objects
    %LifeWiki::CACHE_PAGE = (); # ( "nmid:pagename" => LifeWiki::Page )
    %LifeWiki::CACHE_PAGE_NOTFOUND = (); # same => 1
}

# add a hook to the system that other people can call and use
sub addHook {
    my $name = shift;
    die "Attempt to add hook with no name\n" unless $name;

    my $runner = shift;
    die "Attempt to add hook '$name' without a runner\n" unless $runner;
    die "Attempt to add hook '$name' with a runner other than a code ref\n"
        unless ref $runner eq 'CODE';

    # add this to our list at the end
    push @{$Hooks{$name} ||= []}, $runner;
}

# removes all hooks for a given name
sub clearHooks {
    my $name = shift;
    return undef unless $Hooks{$name} && @{$Hooks{$name}};
    my $ct = scalar(@{$Hooks{$name}});
    $Hooks{$name} = [];
    return $ct;
}

# run hooks until one returns a defined value, then return that
sub runHook {
    my $name = shift;
    return undef unless $Hooks{$name} && @{$Hooks{$name}};

    foreach my $hook (@{$Hooks{$name}}) {
        my $val = $hook->(@_);
        return $val if defined $val;
    }
    return undef;
}

# run a bunch of hooks and assemble the defined return values into an arrayref
sub runHooks {
    my $name = shift;
    return undef unless $Hooks{$name} && @{$Hooks{$name}};

    my @ret;
    foreach my $hook (@{$Hooks{$name} || []}) {
        my $val = $hook->(@_);
        push @ret, $val if defined $val;
    }
    return \@ret;
}

# get a pointer to the available hooks
sub getHookRef {
    return \%Hooks;
}

# shamelessly taken from LiveJournal.com source code
sub ehtml {
    # fast path for the commmon case:
    return $_[0] unless $_[0] =~ /[&\"\'<>]/;

    # this is faster than doing one substitution with a map:
    my $a = $_[0];
#    $a =~ s/\&/&amp;/g;
#    $a =~ s/\"/&quot;/g;
#    $a =~ s/\'/&\#39;/g;
    $a =~ s/</&lt;/g;
    $a =~ s/>/&gt;/g;
    return $a;
}

sub addComponentRoot {
    my $root = shift;
    $root = "$ENV{LIFEWIKIHOME}/$root";
    die "Root '$root' doesn't exist or is not a directory\n" unless -d $root;

    unshift @COMPROOT, [ scalar(@COMPROOT)+1 => $root ];
}

sub addImageDir {
    my ($uri, $path) = @_;
    my $root = "$ENV{LIFEWIKIHOME}/$path";
    die "Root '$root' doesn't exist or is not a directory\n" unless -d $root;
    die "Image path '$uri' not in proper format '/images/FOO'\n"
        unless $uri =~ m!^/images/.+$!;

    unshift @IMGDIR, [ $uri, $root ];
}

sub setTheme {
    my $root = shift;
    $root = "$ENV{LIFEWIKIHOME}/$root";
    die "Theme directory '$root' doesn't exist or is not a directory\n" unless -d $root;

    # note that we have a custom theme
    $LifeWiki::CUSTOM_THEME_DIR = $root;
}

sub findRelevantPages {
    my $term = shift;
    return undef unless $term;

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    my $res = $dbh->selectcol_arrayref(qq{
            SELECT pgid FROM searchdb WHERE MATCH (name, content) AGAINST (?)
        }, undef, $term);
    return undef if $dbh->err;
    return undef unless $res && @$res;

    my @ret;
    foreach my $pgid (@$res) {
        my $pg = LifeWiki::Page->newByPageId($pgid);
        push @ret, $pg if $pg;
    }
    return \@ret;
}

# given a privilege name and an optional extraid, return a list of userids for people
# that have this access.  returns an array of arrayrefs, [ userid, extraid ].
sub getAccessList {
    my ($pname, $extra) = @_;

    my $priv = $LifeWiki::PRIVILEGE_TABLE{$pname};
    return () unless $priv;

    $extra = undef unless $extra > 0;

    my $dbh = LifeWiki::getDatabase();
    return () unless $dbh;

    my $rows;
    if ($extra) {
        $rows = $dbh->selectall_arrayref('SELECT userid, extraid FROM access WHERE privid = ? AND extraid = ?',
                                         undef, $priv->{id}, $extra);
    } else {
        $rows = $dbh->selectall_arrayref('SELECT userid, extraid FROM access WHERE privid = ?',
                                         undef, $priv->{id});
    }
    return () if $dbh->err;
    return @$rows;
}

# also taken from LiveJournal
sub rand_chars {
    my $length = shift;
    my $chal = "";
    my $digits = "abcdefghijklmnopqrstuvwzyzABCDEFGHIJKLMNOPQRSTUVWZYZ0123456789";

    # perldoc -f srand; kinda
    srand(time ^ $$);
    
    for (1..$length) {
        $chal .= substr($digits, int(rand(62)), 1);
    }
    return $chal;
}

# and still taken from LiveJournal
sub mysql_time
{
    my ($time, $gmt) = @_;
    $time ||= time();
    my @ltime = $gmt ? gmtime($time) : localtime($time);
    return sprintf("%04d-%02d-%02d %02d:%02d:%02d",
                   $ltime[5]+1900,
                   $ltime[4]+1,
                   $ltime[3],
                   $ltime[2],
                   $ltime[1],
                   $ltime[0]);
}

1;
