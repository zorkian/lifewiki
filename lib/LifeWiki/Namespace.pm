#!/usr/bin/perl

package LifeWiki::Namespace;

use strict;

sub newById {
    my $class = shift;

    my $nmid = shift() + 0;
    return undef unless $nmid;

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    my ($name, $desc, $ownerid, $readsec, $writesec, $frontpage) =
        $dbh->selectrow_array('SELECT name, description, ownerid, readsec, writesec, frontpage FROM namespace WHERE nmid = ?',
                              undef, $nmid);
    return undef if $dbh->err;
    return undef unless $name;

    my $self = {
        _nmid => $nmid,
        _name => $name,
        _desc => $desc,
        _ownerid => $ownerid,
        _readsec => $readsec,
        _writesec => $writesec,
        _frontpage => $frontpage,
    };
    bless $self, $class;

    return $self;
}

sub newByName {
    my $class = shift;

    my $name = shift();
    return undef unless $name;

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    my ($nmid, $desc, $ownerid, $readsec, $writesec, $frontpage) =
        $dbh->selectrow_array('SELECT nmid, description, ownerid, readsec, writesec, frontpage FROM namespace WHERE name = ?',
                              undef, $name);
    return undef if $dbh->err;
    return undef unless $nmid;

    my $self = {
        _nmid => $nmid,
        _name => $name,
        _desc => $desc,
        _ownerid => $ownerid,
        _readsec => $readsec,
        _writesec => $writesec,
        _frontpage => $frontpage,
    };
    bless $self, $class;

    return $self;
}

sub getNamespaceName {
    my $nmid = shift() + 0;
    return undef unless $nmid;

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    my $name = $dbh->selectrow_array('SELECT name FROM namespace WHERE nmid = ?', undef, $nmid);
    return undef if $dbh->err;

    return $name;
}

# list namespaces for the front page, DOES NOT
# return undef on error!
sub getFrontpage {
    my $dbh = LifeWiki::getDatabase();
    return () unless $dbh;

    my $rows = $dbh->selectall_arrayref
        ('SELECT nmid, name, description, ownerid, readsec, writesec FROM namespace ' .
         'WHERE frontpage = 1 ORDER BY description');
    return () if $dbh->err;

    my @res;
    foreach my $row (@$rows) {
        my ($nmid, $name, $desc, $ownerid, $readsec, $writesec) = @$row;
        my $self = {
            _nmid => $nmid,
            _name => $name,
            _desc => $desc,
            _ownerid => $ownerid,
            _readsec => $readsec,
            _writesec => $writesec,
            _frontpage => 1,
        };
        bless $self, 'LifeWiki::Namespace';
        push @res, $self;
    }
    return @res;
}

sub createNew {
    my ($name, $owner) = @_;
    return undef unless $name && $owner;

    my $ons = LifeWiki::Namespace->newByName($name);
    return undef if $ons;

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    $dbh->do("INSERT INTO namespace (ownerid, name) VALUES (?, ?)",
             undef, $owner->getUserid, $name);
    return undef if $dbh->err;

    my $nmid = $dbh->{mysql_insertid};
    return undef unless $nmid;

    $owner->grant('admin_namespace', $nmid);

    return LifeWiki::Namespace->newById($nmid);
}

sub isFrontpage {
    my $self = shift;
    return $self->{_frontpage};
}

sub getNamespaceId {
    my $self = shift;
    return $self->{_nmid};
}

sub getName {
    my $self = shift;
    return $self->{_name};
}

sub getDescription {
    my $self = shift;
    return $self->{_desc} || $self->{_name};
}

sub getURI {
    my $self = shift;
    return "$LifeWiki::SITEROOT/$self->{_name}/";
}

sub getReadSecurity {
    my $self = shift;
    return $self->{_readsec};
}

sub getWriteSecurity {
    my $self = shift;
    return $self->{_writesec};
}

sub getOwnerId {
    my $self = shift;
    return $self->{_ownerid};
}

sub setFrontpage {
    my $self = shift;
    my $arg = (shift()+0) ? 1 : 0;
    return $arg if $arg == $self->{_frontpage};

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    $dbh->do("UPDATE namespace SET frontpage = ? WHERE nmid = ?",
             undef, $arg, $self->{_nmid});
    return undef if $dbh->err;
    return $self->{_frontpage} = $arg;
}

sub setDescription {
    my $self = shift;
    my $arg = shift;
    return $arg if $arg eq $self->{_desc};

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    $dbh->do("UPDATE namespace SET description = ? WHERE nmid = ?",
             undef, $arg, $self->{_nmid});
    return undef if $dbh->err;
    return $self->{_desc} = $arg;
}

sub setWriteSecurity {
    my $self = shift;
    my $arg = shift;
    return $arg if $arg eq $self->{_writesec};

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    $dbh->do("UPDATE namespace SET writesec = ? WHERE nmid = ?",
             undef, $arg, $self->{_nmid});
    return undef if $dbh->err;
    return $self->{_writesec} = $arg;
}

sub setReadSecurity {
    my $self = shift;
    my $arg = shift;
    return $arg if $arg eq $self->{_readsec};

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    $dbh->do("UPDATE namespace SET readsec = ? WHERE nmid = ?",
             undef, $arg, $self->{_nmid});
    return undef if $dbh->err;
    return $self->{_readsec} = $arg;
}

1;
