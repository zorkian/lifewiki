#!/usr/bin/perl

package LifeWiki;

use strict;

# lists of hooks that are defined...
#   ( hook_name => [ $runner, $runner, ... ] )
# hooks must return undef meaning "I didn't handle this" or a defined value which
# indicates they're actually returning something.
our %Hooks = ();

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

sub setAuthAgent {
    my $auth = shift();
    my $args = shift();

    eval "use LifeWiki::Auth::$auth;";
    eval "LifeWiki::Auth::${auth}::enable(\$args);";
    if ($@) {
        $@ = "Error: $auth module unable to load\n";
        return undef;
    }

    return 1;
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
    foreach my $hook (@{$Hooks{$name}}) {
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
    $a =~ s/\&/&amp;/g;
    $a =~ s/\"/&quot;/g;
    $a =~ s/\'/&\#39;/g;
    $a =~ s/</&lt;/g;
    $a =~ s/>/&gt;/g;
    return $a;
}

# also taken from LiveJournal
sub rand_chars {
    my $length = shift;
    my $chal = "";
    my $digits = "abcdefghijklmnopqrstuvwzyzABCDEFGHIJKLMNOPQRSTUVWZYZ0123456789";
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
