#!/usr/bin/perl

package LifeWiki::Plugin::FileUpload::File;

use strict;

# eventually this functionality will be in this module...
sub newByAttachmentId {
    my ($class, $aid) = @_;
    return undef unless $class && $aid;

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    my $row = $dbh->selectrow_arrayref('SELECT attachid, pgid, filename, revnum FROM fileattachments WHERE attachid = ?',
                                       undef, $aid+0);
    return undef if $dbh->err || ! $row;

    my $self = {
        _attachid => $row->[0],
        _pgid => $row->[1],
        _filename => $row->[2],
        _revnum => $row->[3],        
    };

    my $content = $dbh->selectall_hashref('SELECT revnum, savetime, authorid, filesize FROM fileattachmentscontent WHERE attachid = ?',
                                          'revnum', undef, $self->{_attachid});
    return undef if $dbh->err || ! $content;

    foreach my $revnum (keys %$content) {
        $self->{_rev}->{$revnum} = {
            _savetime => $content->{$revnum}->{savetime},
            _authorid => $content->{$revnum}->{authorid},
            _filesize => $content->{$revnum}->{filesize},
        };
    }

    bless $self, $class;
    return $self;
}

sub uploadRevision {
    my ($self, $remote, $file) = @_;
    return unless $self && $remote && $file;

    my $size = length($file);
    my $dbh = LifeWiki::getDatabase();
    return undef unless $size && $dbh;

    my $newnum = $self->{_revnum} + 1;
    $dbh->do("INSERT INTO fileattachmentscontent (attachid, revnum, savetime, authorid, filesize) VALUES (?, ?, UNIX_TIMESTAMP(), ?, ?)",
             undef, $self->{_attachid}, $newnum, $remote->getUserid, $size);
    return undef if $dbh->err;

    open FILE, ">$LifeWiki::Plugin::FileUpload::opts{path}/$self->{_attachid}.$newnum"
        or return undef;
    print FILE $file;
    close FILE;

    $dbh->do("UPDATE fileattachments SET revnum = ? WHERE attachid = ? AND revnum = ?",
             undef, $newnum, $self->{_attachid}, $self->{_revnum});
    return undef if $dbh->err;

    my $class = ref $self;
    return $class->newByAttachmentId($self->{_attachid});
}

sub newUpload {
    my ($class, $page, $remote, $name, $file) = @_;
    return unless $class && $page && $remote && $name && $file;

    my $size = length($file);
    my $dbh = LifeWiki::getDatabase();
    return undef unless $size && $dbh;

    $dbh->do("INSERT INTO fileattachments (attachid, pgid, filename, revnum) VALUES (NULL, ?, ?, 1)",
             undef, $page->getPageId, $name);
    return undef if $dbh->err;

    my $aid = $dbh->{mysql_insertid};
    return undef unless $aid;

    $dbh->do("INSERT INTO fileattachmentscontent (attachid, revnum, savetime, authorid, filesize) VALUES (?, 1, UNIX_TIMESTAMP(), ?, ?)",
             undef, $aid, $remote->getUserid, $size);
    if ($dbh->err) {
        $dbh->do("DELETE FROM fileattachments WHERE attachid = ? AND pgid = ?",
                 undef, $aid, $page->getPageId);
        return undef;
    }

    open FILE, ">$LifeWiki::Plugin::FileUpload::opts{path}/$aid.1"
        or return undef;
    print FILE $file;
    close FILE;

    return $class->newByAttachmentId($aid);
}

sub getFilesOnPage {
    my ($class, $page) = @_;
    return unless $class && $page;

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    my $aids = $dbh->selectcol_arrayref('SELECT attachid FROM fileattachments WHERE pgid = ?',
                                        undef, $page->getPageId);
    return undef if $dbh->err || ! $aids;

    my @res;
    push @res, $class->newByAttachmentId($_)
        foreach @$aids;

    @res = grep { defined $_ } @res;
    return \@res;
}

sub getAttachmentId {
    return $_[0]->{_attachid};
}

sub getRevNum {
    return $_[0]->{_revnum};
}

sub getFilename {
    return $_[0]->{_filename};
}

sub getAuthorId {
    my ($self, $rev) = @_;
    unless ($rev) {
        return $self->{_rev}->{$self->{_revnum}}->{_authorid};
    }
    return undef unless $self->{_rev}->{$rev};
    return $self->{_rev}->{$rev}->{_authorid};
}

sub getSaveTime {
    my ($self, $rev) = @_;
    unless ($rev) {
        return $self->{_rev}->{$self->{_revnum}}->{_savetime};
    }
    return undef unless $self->{_rev}->{$rev};
    return $self->{_rev}->{$rev}->{_savetime};
}

sub getFilesize {
    my ($self, $rev) = @_;
    unless ($rev) {
        return $self->{_rev}->{$self->{_revnum}}->{_filesize};
    }
    return undef unless $self->{_rev}->{$rev};
    return $self->{_rev}->{$rev}->{_filesize};
}

sub getPageId {
    return $_[0]->{_pgid};
}

sub isValidRevNum {
    return $_[1] >= 1 && $_[1] <= $_[0]->{_revnum};
}

sub getViewLink {
    my ($self, $rev) = @_;
    unless ($rev) {
        return "/attachments/view/$self->{_pgid}/$self->{_attachid}.$self->{_revnum}";
    }
    return undef unless $self->{_rev}->{$rev};
    return "/attachments/view/$self->{_pgid}/$self->{_attachid}.$rev";
}

sub getDownloadLink {
    my ($self, $rev) = @_;
    unless ($rev) {
        return "/attachments/download/$self->{_pgid}/$self->{_attachid}.$self->{_revnum}";
    }
    return undef unless $self->{_rev}->{$rev};
    return "/attachments/download/$self->{_pgid}/$self->{_attachid}.$rev";
}

sub getReviseLink {
    return "/attachments/revise/$_[0]->{_pgid}/$_[0]->{_attachid}.$_[0]->{_revnum}";
}

sub getDeleteLink {
    return "/attachments/delete/$_[0]->{_pgid}/$_[0]->{_attachid}.$_[0]->{_revnum}";
}

sub getRevisionsLink {
    return "/attachments/revisions/$_[0]->{_pgid}/$_[0]->{_attachid}.$_[0]->{_revnum}";
}

sub getFileContents {
    my ($self, $revnum) = @_;
    return unless $self;

    $revnum ||= $self->{_revnum};
    return unless $revnum && $self->{_rev}->{$revnum};

    my $fc;
    open FILE, "<$LifeWiki::Plugin::FileUpload::opts{path}/$self->{_attachid}.$revnum"
        or return undef;
    read FILE, $fc, $self->getFilesize($revnum);
    close FILE;

    return $fc;
}

sub deleteAttachment {
    my $self = shift;
    return unless $self;

    # database cleanup
    my $dbh = LifeWiki::getDatabase();
    return unless $dbh;

    # delete ourselves!
    foreach my $revnum (1..$self->{_revnum}) {
        unlink "$LifeWiki::Plugin::FileUpload::opts{path}/$self->{_attachid}.$revnum";
    }

    # do db work
    $dbh->do("DELETE FROM fileattachments WHERE attachid = ?",
             undef, $self->{_attachid});
    $dbh->do("DELETE FROM fileattachmentscontent WHERE attachid = ?",
             undef, $self->{_attachid});

    # all done
    return 1;
}

sub getContentType {
    my $default = "application/octet-stream";

    my $self = shift;
    return $default unless $self;

    my $types = $LifeWiki::Plugin::FileUpload::opts{mime_types};
    return $default unless $types;

    my $fn = lc $self->getFilename;
    return $default unless $fn =~ /\.(.+?)$/;
    my $ext = $1;

    return $types->{$ext} || $default;
}

1;
