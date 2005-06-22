#!/usr/bin/perl

package LifeWiki::Plugin::BlueTheme;

use strict;

# the init function is called as soon as a plugin is loaded.  you can do any
# initialization stuff you'd like to do here.
sub init {
    # adding a component root enables the Mason backend that LifeWiki runs on
    # to search for files you've created
    LifeWiki::setTheme('plugins/BlueTheme/htdocs/theme');
    LifeWiki::addComponentRoot('plugins/BlueTheme/htdocs');

    # must return 1 to indicate that we're setup correctly
    return 1;
}
