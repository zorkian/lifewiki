#!/usr/bin/perl

package LifeWiki::Page;

use strict;

sub _getNamespaceId {
    my $name = shift();
    return undef unless $name;

    # try cacheing it in process cache (yes yes, whatever)
    my $nmid = $LifeWiki::CACHE_NMIDS{$name};
    unless ($nmid) {
        my $dbh = LifeWiki::getDatabase();
        return undef unless $dbh;

        $nmid = $dbh->selectrow_array('SELECT nmid FROM namespace WHERE name = ?', undef, $name);
        return undef if $dbh->err;

        $LifeWiki::CACHE_NMIDS{$name} = $nmid;
    }
    return $nmid;
}

sub _canEditNamespace {
    my ($remote, $nmid) = @_;
    return undef unless $remote && $nmid;

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    # allow public writes?
    my $writelevel =
        $LifeWiki::CACHE_NMID_WRITESEC{$nmid} ||=
            $dbh->selectrow_array('SELECT writesec FROM namespace WHERE nmid = ?', undef, $nmid);
    return 1 if $writelevel eq 'public';

    # nope, do you have access anyway?
    return $remote->can('admin_namespace', $nmid) ||
           $remote->can('moderate_namespace', $nmid);
}

sub _canReadNamespace {
    my ($remote, $nmid) = @_;
    return undef unless $nmid;

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    # allow public writes?
    my $readlevel =
        $LifeWiki::CACHE_NMID_READSEC{$nmid} ||=
            $dbh->selectrow_array('SELECT readsec FROM namespace WHERE nmid = ?', undef, $nmid);
    return 1 if $readlevel eq 'public';

    # do you have access anyway?
    return undef unless $remote;
    return $remote->can('admin_namespace', $nmid) ||
           $remote->can('moderate_namespace', $nmid) ||
           $remote->can('read_namespace', $nmid);
}

# $remote is the person viewing this page
# $arg is the page we're looking for
# $viewing is the URI we're currently viewing
# $vivify is on if we should create the page if it doesn't exist
sub new {
    my ($class, $remote, $arg, $viewing, $vivify) = @_;
    return undef unless $arg;

    # see if the page we want has a namespace
    my @args = split(/\//, $arg);
    return undef if scalar(@args) > 2;

    # by default, get all info from the $arg ...
    my ($namespace, $page);
    if (scalar(@args) == 2) {
        ($namespace, $page) = @args;
    } else {
        # if we have something in viewing, maybe it's a namespace?
        if ($viewing) {
            $page = $args[0];

            @args = split(/\//, $viewing);
            return undef unless scalar(@args) >= 1;

            $namespace = $args[0];
        } else {
            # nope, all we have is a namespace
            $namespace = $args[0];
            $page = 'default';
        }
    }
    $page ||= 'default';

    # and now we verify the namespace exists
    my $nmid = _getNamespaceId($namespace);
    return undef unless $nmid;

    # make sure this user can read the namespace
    return undef unless _canReadNamespace($remote, $nmid);

    # see if we can't return a cached page?
    return $LifeWiki::CACHE_PAGE{"$nmid:$page"}
        if $LifeWiki::CACHE_PAGE{"$nmid:$page"};

    # return undef if we've cached it doesn't exist
    return undef
        if $LifeWiki::CACHE_PAGE_NOTFOUND{"$nmid:$page"};

    # get database for the load
    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    # now let's load the page?
    my ($pgid, $authorid, $revnum) = $dbh->selectrow_array
        ('SELECT pgid, authorid, revnum FROM page WHERE nmid = ? AND name = ?', undef, $nmid, $page);
    return undef if $dbh->err;

    # vivify if we can/should?
    if (!$pgid && $vivify) {
        return undef unless $remote;

        # can we edit this namespace?
        return undef unless _canEditNamespace($remote, $nmid);

        # automatically create this page
        $dbh->do("INSERT INTO page (nmid, authorid, name, revnum) VALUES (?, ?, ?, ?)",
                 undef, $nmid, $remote->getUserid, $page, 0);
        return undef if $dbh->err;

        $pgid = $dbh->{mysql_insertid};
        return undef unless $pgid;

        # insert the base empty revision
        $dbh->do("INSERT INTO pagetext (pgid, revnum, revtime, authorid, content) VALUES (?, ?, UNIX_TIMESTAMP(), ?, ?)",
                 undef, $pgid, 0, $remote->getUserid, '');

        # now return this page, but with vivify turned off
        return LifeWiki::Page->new($remote, $namespace . '/' . $page);
    }

    # if it doesn't exist, note that and return
    unless ($pgid) {
        $LifeWiki::CACHE_PAGE_NOTFOUND{"$nmid:$page"} = 1;
        return undef;
    }

    my $self = {
        _uri => $namespace . '/' . $page,
        _pgid => $pgid,
        _nmid => $nmid,
        _namespace => $namespace,
        _name => $page,
        _authorid => $authorid,
        _revnum => $revnum,
    };
    bless $self, $class;

    # cache it
    $LifeWiki::CACHE_PAGE{"$nmid:$page"} = $self;

    return $self;
}

sub newByPageId {
    my $class = shift();
    my $arg = shift()+0;
    return undef unless $arg;

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    # now let's load the page?
    my ($name, $nmid, $authorid, $revnum) = $dbh->selectrow_array
        ('SELECT name, nmid, authorid, revnum FROM page WHERE pgid = ?', undef, $arg);
    return undef if $dbh->err;

    # get namespace information
    my $namespace = LifeWiki::Namespace::getNamespaceName($nmid);
    return undef unless $namespace;

    my $self = {
        _uri => $namespace . '/' . $name,
        _pgid => $arg,
        _name => $name,
        _authorid => $authorid,
        _revnum => $revnum,
        _namespace => $namespace,
        _nmid => $nmid,
    };
    bless $self, $class;

    return $self;
}

sub getPageId {
    my $self = shift;
    return $self->{_pgid};
}

sub getURI {
    my $self = shift;
    return $self->{_uri};
}

sub getName {
    my $self = shift();
    return $self->{_name};
}

sub getNamespace {
    my $self = shift();
    return $self->{_namespace};
}

sub getNamespaceId {
    my $self = shift;
    return $self->{_nmid};
}

sub getRevNum {
    my $self = shift;
    return $self->{_revnum};
}

sub getRevTime {
    my $self = shift;

    # cache our content
    $self->getContent
        unless $self->{_revinfo}->{$self->{_revnum}};

    return $self->{_revinfo}->{$self->{_revnum}}->[2];
}

sub getEditURI {
    my $self = shift;
    return "/edit/$self->{_pgid}";
}

sub getRevisionsURI {
    my $self = shift;
    return "/revisions/$self->{_pgid}";
}

sub getDiffURI {
    my $self = shift;
    my ($from, $to) = @_;
    my $uri = "/diff/$self->{_pgid}";
    if ($from) {
        $uri .= "/$from";
        if ($to) {
            $uri .= "/$to";
        }
    }
    return $uri;
}

# optional argument is what revision number to get, undef for current
sub getContent {
    my $self = shift;

    my $rev = shift;
    $rev ||= $self->{_revnum};
    return @{$self->{_revinfo}->{$rev}}
        if $self->{_revinfo}->{$rev};

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    my ($authorid, $revtime, $content) = $dbh->selectrow_array
        ('SELECT authorid, revtime, content FROM pagetext WHERE pgid = ? AND revnum = ?', undef, $self->{_pgid}, $rev);
    $revtime = LifeWiki::mysql_time($revtime);
    $self->{_revinfo}->{$rev} = [ $authorid, $content, $revtime ];

    return ($authorid, $content, $revtime);
}

sub isBlank {
    my $self = shift;
    my $content = ($self->getContent)[1];
    return (length($content) == 0 ? 1 : 0);
}

sub getEscapedContent {
    my $self = shift;

    my ($authorid, $content, $revtime) = $self->getContent;
    return undef unless $content;

    return ($authorid, LifeWiki::ehtml($content), $revtime);
}

sub getOutputContent {
    my $self = shift;
    my $remote = shift;
    my $revnum = shift;

    my ($authorid, $content, $revtime) = $self->getContent($revnum);

    # escape HTML first
    $content = LifeWiki::ehtml($content);

    # now convert camel words to links
    my $linkify = sub {
        my ($pre, $line, $owner, $word, $alt) = @_;

        # if preceeded by a \, ignore this wiki-word
        return $line if $pre eq '!';

        my $page = LifeWiki::Page->new($remote, $word, $owner ? $owner : $self->{_namespace});
        if ($page) {
            return "$pre<a class='link' href='/" . $page->getURI . "'>" . ($alt || $page->getName) . "</a>";
        } else {
            my $uri = $owner ? "/$owner/$word" : "/$self->{_namespace}/$word";
            return "$pre<a class='newlink' href='$uri'>" . ($alt || $word) . "</a>";
        }
    };

    my $links;
    my $push = sub { my $n = shift; push @$links, [ @_ ]; return $n; };
    my $pop = sub { return $linkify->(@{ shift @$links }); };

    my @temp1; $links = \@temp1;
    $content =~ s/(^|.)(\{(?:(\w+):)?(\w+)(?:\s+([^\]]+?))?\})/$push->('<temp1>', $1, $2, $3, $4, $5)/ges;

    my @temp2; $links = \@temp2;
    $content =~ s/(^|.)((?:(\w+):)?(\w*[A-Z]\w*[A-Z]\w*))\b/$push->('<temp2>', $1, $2, $3, $4)/ges;

    $links = \@temp1;
    $content =~ s/<temp1>/$pop->()/ges;

    $links = \@temp2;
    $content =~ s/<temp2>/$pop->()/ges;

    return ($authorid, Markdown::Markdown($content), $revtime);
}

sub setContent {
    my ($self, $remote, $content) = @_;
    return undef unless $self && $remote && $content;

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    # update the revision count
    $dbh->do("UPDATE page SET revnum = revnum + 1 WHERE pgid = ?", undef, $self->{_pgid});
    return undef if $dbh->err;

    # now get the new one (FIXME: racy as fuck here)
    my $revnum = $dbh->selectrow_array("SELECT revnum FROM page WHERE pgid = ?", undef, $self->{_pgid});
    return undef if $dbh->err;

    # and now add the latest content
    $dbh->do("INSERT INTO pagetext (pgid, revnum, revtime, authorid, content) VALUES (?, ?, UNIX_TIMESTAMP(), ?, ?)",
             undef, $self->{_pgid}, $revnum, $remote->getUserid, $content);
    return undef if $dbh->err;

    # now note the update
    $dbh->do("REPLACE INTO changes (pgid, authorid, modtime) VALUES (?, ?, UNIX_TIMESTAMP())",
             undef, $self->{_pgid}, $remote->getUserid);

    # and update our search text
    $dbh->do("UPDATE searchdb SET content = ? WHERE pgid = ?",
             undef, $content, $self->{_pgid});

    # and now run the hook so people know this happened
    LifeWiki::runHooks('page_content_changed',
        page => $self,
        remote => $remote,
        content => $content,
    );

    return 1;
}

sub isEditor {
    my $self = shift;
    my $remote = shift;
    return 0 unless $remote;

    # unacknowledged accounts can't edit
    return 0 unless $remote->getUsername;

    return _canEditNamespace($remote, $self->{_nmid});
}

sub noteUserCreation {
    my $class = shift;
    my $u = shift;
    return undef unless $u;

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    my $namespace = $u->getUsername;
    if (defined $namespace) {
        $dbh->do("INSERT INTO namespace (ownerid, name, readsec, writesec) VALUES (?, ?, ?, ?)",
                 undef, $u->getUserid, $namespace, 'public', 'secure');
        return undef if $dbh->err;

        my $nmid = $dbh->{mysql_insertid};
        return undef unless $nmid;

        $dbh->do("INSERT INTO access (userid, privid, extraid) VALUES (?, ?, ?)",
                 undef, $u->getUserid, $LifeWiki::PRIVILEGE_TABLE{admin_namespace}->{id}, $nmid);
        return undef if $dbh->err;
    }

    return 1;
}

sub getAuthorId {
    my $self = shift;

    my $rev = shift;
    $rev ||= $self->{_revnum};
    return $self->{_revinfo}->{$rev}->[0]
        if $self->{_revinfo}->{$rev};

    # falls back to hitting the database
    my ($authorid, $content) = $self->getContent($rev);
    return $authorid;
}

sub getRevisionInfo {
    my $self = shift;

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    my $res = $dbh->selectall_arrayref('SELECT revnum, authorid, revtime FROM pagetext WHERE pgid = ?', undef, $self->{_pgid});
    return undef if $dbh->err;

    $_->[2] = LifeWiki::mysql_time($_->[2])
        foreach @$res;

    return $res;
}

1;
