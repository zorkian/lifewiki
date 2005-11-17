#!/usr/bin/perl

package LifeWiki::Plugin::FileUpload;

use strict;

our %opts;

# the init function is called as soon as a plugin is loaded.  you can do any
# initialization stuff you'd like to do here.
sub init {
    # adding a component root enables the Mason backend that LifeWiki runs on
    # to search for files you've created
    LifeWiki::addComponentRoot('plugins/FileUpload/htdocs');
    LifeWiki::addLibraryPath('plugins/FileUpload/lib');
    eval 'use LifeWiki::Plugin::FileUpload::File; 1;'
        or die "Error: unable to load in plugins we need\n";

    # get some options
    %opts = %{ shift() || {} };
    die "Error: need path for file storage\n"
        unless $opts{path};

    # make sure our directory exists
    die "Error: path does not exist\n"
        unless -e $opts{path} && -d $opts{path};
    open FILE, ">$opts{path}/.writeable"
        or die "Error: path is not writeable\n";
    print FILE time() . "\n";
    close FILE;

    # load mime types
    if ($opts{mime_types_from}) {
        open FILE, "<$opts{mime_types_from}"
            or die "Error: unable to open MIME file: $!\n";
        $opts{mime_types} = {};
        while (<FILE>) {
            next unless /^(\w\S+?)((?:\s+\w+)+)\s*\r?\n$/;
            my ($type, $exts) = ($1, $2);
            my @exts = split /\s+/, $exts;
            foreach my $ext (@exts) {
                $opts{mime_types}->{$ext} = $type;
            }
        }
        close FILE;
    }

    # register some hooks
    LifeWiki::addHook('page_footer_extra', sub {
        my ($page, $remote) = @_;
        return unless $page && $remote;
        return if $opts{allowed_namespaces} && ! $opts{allowed_namespaces}->{$page->getNamespaceId};
        return unless $page->isEditor($remote);

        # give people a link to attach things
        return " [<a href='/attachments/upload/" . $page->getPageId() . "'><strong>Attach</strong></a>] ";
    });

    # and now add information about a page content
    LifeWiki::addHook('postparse_page_content', sub {
        my ($page, $contentref) = @_;
        return unless $contentref && $page;
        return if $opts{allowed_namespaces} && ! $opts{allowed_namespaces}->{$page->getNamespaceId};

        # show people if things are attached
        my $files = LifeWiki::Plugin::FileUpload::File->getFilesOnPage($page);
        return if ! defined $files;
        return if ! scalar(@$files);

        # now show the files
        my $out;
        foreach my $file (sort { lc $a->getFilename cmp lc $b->getFilename } @$files) {
            $out .= "<div class='bar'>";
            my $au = LifeWiki::User->newFromUserid($file->getAuthorId);
            $out .= sprintf('<a href="%s"><strong>%s</strong></a> (%d bytes, <a href="%s">view file</a>)<br />',
                            $file->getDownloadLink, $file->getFilename, $file->getFilesize,
                            $file->getViewLink);
            $out .= sprintf('Revision #%d by %s dated %s.<br />', $file->getRevNum,
                            ($au ? $au->getLinkedNick : 'unknown author'),
                            LifeWiki::mysql_time($file->getSaveTime));
            if ($page->isEditor(LifeWiki::getRemote())) {
                $out .= sprintf('[<a href="%s"><strong>Update</strong></a>] [<a href="%s"><strong>Delete</strong></a>] ',
                                $file->getReviseLink, $file->getDeleteLink);
            }
            $out .= sprintf('[<a href="%s"><strong>History</strong></a>]',
                            $file->getRevisionsLink);
            $out .= "</div>";
        }

        $$contentref .= $out if $out;
        return;
    });

    # must return 1 to indicate that we're setup correctly
    return 1;
}


1;
