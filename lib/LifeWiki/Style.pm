#!/usr/bin/perl

package LifeWiki::Style;

use strict;

sub newById {
    my $class = shift;

    my $sid = shift() + 0;
    return undef unless $sid;

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    my ($ownerid, $name, $content) =
        $dbh->selectrow_array('SELECT ownerid, name, content FROM style WHERE styleid = ?',
                              undef, $sid);
    return undef if $dbh->err;
    return undef unless $name;

    my $self = {
        _styleid => $sid,
        _name => $name,
        _ownerid => $ownerid,
        _content => $content,
    };
    bless $self, $class;

    return $self;
}

sub createNew {
    my ($name, $owner) = @_;
    return undef unless $name && $owner;

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    $dbh->do("INSERT INTO style (ownerid, name, content) VALUES (?, ?, NULL)",
             undef, $owner->getUserid, $name);
    return undef if $dbh->err;

    my $sid = $dbh->{mysql_insertid};
    return undef unless $sid;

    $owner->grant('admin_style', $sid);

    return LifeWiki::Style->newById($sid);
}

# class method!
sub getStyleName {
    my $sid = shift() + 0;
    return unless $sid;

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    my ($name) =
        $dbh->selectrow_array('SELECT name FROM style WHERE styleid = ?',
                              undef, $sid);
    return undef if $dbh->err;
    return undef unless $name;
    return $name;
}

sub getStyleId {
    my $self = shift;
    return $self->{_styleid}+0;
}

sub getName {
    my $self = shift;
    return $self->{_name} || "(no name)";

}

sub getContent {
    my $self = shift;
    return $self->{_content} || "";
}

sub getOwner {
    my $self = shift;
    return LifeWiki::User->newFromUserid($self->{_ownerid}+0);
}

sub getOwnerId {
    my $self = shift;
    return $self->{_ownerid}+0;
}

sub setOwnerId {
    my $self = shift;
    my $arg = shift() + 0;
    return LifeWiki::error("You must provide an owner.")
        unless $arg;
    return $arg if $arg == $self->{_ownerid};

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    $dbh->do("UPDATE style SET ownerid = ? WHERE styleid = ?",
             undef, $arg, $self->{_styleid});
    return undef if $dbh->err;
    return $self->{_ownerid} = $arg;
}

sub setName {
    my $self = shift;
    my $arg = shift;
    return LifeWiki::error("You must provide a name.")
        unless $arg;
    return $arg if $arg eq $self->{_name};

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    $dbh->do("UPDATE style SET name = ? WHERE styleid = ?",
             undef, $arg, $self->{_styleid});
    return undef if $dbh->err;
    return $self->{_name} = $arg;
}

sub setContent {
    my $self = shift;
    my $arg = shift;
    return $arg if $arg eq $self->{_content};

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    $dbh->do("UPDATE style SET content = ? WHERE styleid = ?",
             undef, $arg, $self->{_styleid});
    return undef if $dbh->err;
    return $self->{_content} = $arg;
}

1;
