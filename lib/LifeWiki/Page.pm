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

    my $rv = LifeWiki::runHook('can_edit_namespace', $remote, $nmid);
    return $rv if defined $rv;

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

    my $rv = LifeWiki::runHook('can_read_namespace', $remote, $nmid);
    return $rv if defined $rv;

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

    my $uripage = $page eq 'default' ? '' : $page;
    my $self = {
        _uri => $namespace . '/' . $uripage,
        _pgid => $pgid,
        _nmid => $nmid,
        _namespace => $namespace,
        _name => $page,
        _authorid => $authorid,
        _revnum => $revnum,
    };
    bless $self, $class;

    # call a hook in case they want to edit us
    LifeWiki::runHooks('instantiated_page', $self);

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

    my $uriname = $name eq 'default' ? '' : $name;
    my $self = {
        _uri => $namespace . '/' . $uriname,
        _pgid => $arg,
        _name => $name,
        _authorid => $authorid,
        _revnum => $revnum,
        _namespace => $namespace,
        _nmid => $nmid,
    };
    bless $self, $class;

    LifeWiki::runHooks('instantiated_page', $self);

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
        ('SELECT authorid, revtime, content FROM pagetext WHERE pgid = ? AND revnum = ?',
         undef, $self->{_pgid}, $rev);
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
#$content = LifeWiki::ehtml($content);

    # now convert camel words to links
    my $linkify = sub {
        my ($pre, $line, $owner, $word, $alt, $force) = @_;
        $word ||= 'default';

        # if preceeded by a \, ignore this wiki-word
        return $line if $pre eq '!';

        # do not link words that are purely uppercase
        if (! $force && (uc $word eq $word)) {
            return "$pre$line" if $pre ne '!';
            return $line;
        }

        my $page = LifeWiki::Page->new($remote, $word, $owner ? $owner : $self->{_namespace});
        if ($page) {
            return "$pre<a class='link' href='/" . $page->getURI . "'>" . ($alt || $page->getName) . "</a>";
        } else {
            my $uri = $owner ? "/$owner/$word" : "/$self->{_namespace}/$word";
            return "$pre<a class='newlink' href='$uri'>" . ($alt || $word) . "</a>";
        }
    };

    my $dolinks = sub {
        my $content = shift;
        my $links;
        my $push = sub { my $n = shift; push @$links, [ @_ ]; return $n; };
        my $pop = sub { return $linkify->(@{ shift @$links }); };

        my @temp1; $links = \@temp1;
        $content =~ s/(^|.)(\{(?:(\w+):)?(\w*)(?:\s+([^\]]+?))?\})/$push->('<temp1>', $1, $2, $3, $4, $5, 1)/ges;

        my @temp2; $links = \@temp2;
        $content =~ s/(^|.)((?:(\w+):)?(\w*[A-Z]\w*[A-Z]\w*))\b/$push->('<temp2>', $1, $2, $3, $4)/ges;

        $links = \@temp1;
        $content =~ s/<temp1>/$pop->()/ges;

        $links = \@temp2;
        $content =~ s/<temp2>/$pop->()/ges;
        return $content;
    };

    # setup our data for parsing
    my (%open, $out, $extra);
    my %ac = map { $_ => 1 } qw(hr br img); # auto-close
    my %nli = map { $_ => 1 } qw(a); # do not linkify while open

    # let hooks preparse the content
    my $rv = LifeWiki::runHook('preparse_page_content', \$content);
    goto POSTPARSE if defined $rv && $rv;

    # turn the content into markdown HTML first
    $content = Markdown::Markdown($content);
    my $p = HTML::TokeParser->new(\$content)
        or die "can't create parser: $!";

    # now parse the stream
    while (my $token = $p->get_token) {
        if ($token->[0] eq 'S') {
            # start of an auto-close tag? if so, close and move on
            if ($ac{$token->[1]}) {
                $out .= "<$token->[1] />";
                next;
            }

            # not an auto-closed tag, so mark it as open and then print it to the stream
            # FIXME: the attributes may need to be escaped?
            $open{$token->[1]}++;
            $out .= "<$token->[1] ";
            $out .= join(' ', map { $_ . '="' . $token->[2]->{$_} . '"' } @{$token->[3] || []});
            $out .= ">";

        } elsif ($token->[0] eq 'E') {
            # end of a tag, mark it closed and then close it
            $open{$token->[1]}--;
            $out .= "</$token->[1]>";

        } elsif ($token->[0] eq 'T') {
            # text, we may need to activate links in it (dl == 1)
            my $dl = 1;
            foreach my $tag (keys %nli) {
                $dl = 0
                    if $open{$tag};
            }
            $out .= $dl ? $dolinks->($token->[1]) : $token->[1];

        } else {
            # bah, something else in the stream... comments or process instructions?
            # we don't want to put them in the output (they probably don't matter anyway?)
            print STDERR "OTHER: $token->[0], $token->[1]\n";
        }
    }

    # at this point, if we have some tags open or closed too many times, we should
    # prepend the entry with a warning that the generated HTML appears invalid
    if (%open) {
        $extra = "<p class='content_warning'>The following content has unclosed HTML tags: ";
        $extra .= join(', ', map { "<strong>" . uc($_) . "</strong> ($open{$_} open)" } keys %open);
        $extra .= "</p>\n\n";
    }

    # now call the postparse hook
POSTPARSE:
    LifeWiki::runHook('postparse_page_content', \$content);

    # return; must use $out first, but fall back to $content in case the preparse made
    # us skip down to here
    return ($authorid, $extra . ($out || $content), $revtime);
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
    $dbh->do("REPLACE INTO searchdb (pgid, name, content) VALUES (?, ?, ?)",
             undef, $self->{_pgid}, $self->{_name}, $content);

    # and now run the hook so people know this happened
    LifeWiki::runHooks('page_content_changed', $self, \$content, $remote);

    return 1;
}

sub isEditor {
    my $self = shift;
    my $remote = shift;

    my $rv = LifeWiki::runHook('is_editor', $self, $remote);
    return $rv if defined $rv;

    return 0 unless $remote;
    return _canEditNamespace($remote, $self->{_nmid});
}

# FIXME: I would like this function to be called allocateNamespace or something
# and not have it tied to user creation.  Then it would be moved into LifeWiki::Namespace,
# but that doesn't exist yet.
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

    my $res = $dbh->selectall_arrayref('SELECT revnum, authorid, revtime FROM pagetext WHERE pgid = ?',
                                       undef, $self->{_pgid});
    return undef if $dbh->err;

    $_->[2] = LifeWiki::mysql_time($_->[2])
        foreach @$res;

    return $res;
}

1;
