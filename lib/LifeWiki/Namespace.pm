#!/usr/bin/perl

package LifeWiki::Namespace;

use strict;

sub newById {
    my $class = shift;

    my $nmid = shift() + 0;
    return undef unless $nmid;

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    my ($name, $ownerid, $readsec, $writesec) =
        $dbh->selectrow_array('SELECT name, ownerid, readsec, writesec FROM namespace WHERE nmid = ?',
                              undef, $nmid);
    return undef if $dbh->err;

    my $self = {
        _nmid => $nmid,
        _name => $name,
        _ownerid => $ownerid,
        _readsec => $readsec,
        _writesec => $writesec,
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

sub getNamespaceId {
    my $self = shift;
    return $self->{_nmid};
}

sub getName {
    my $self = shift;
    return $self->{_name};
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

1;
