#!/usr/bin/perl

package LifeWiki::Plugin::WhatLinksHere;

use strict;

# the init function is called as soon as a plugin is loaded.  you can do any
# initialization stuff you'd like to do here.
sub init {
    # add a hook to process when content changes
    LifeWiki::addHook('page_content_changed', \&newContent);

    # must return 1 to indicate that we're setup correctly
    return 1;
}

sub newContent {
    my %opts = (@_);
    die "page_content_changed didn't get right opts\n"
        unless $opts{remote} && $opts{page} && $opts{content};

    print STDERR $opts{page}->getName . " changed\n";
}
