#!/usr/bin/perl

package LifeWiki::User;

use strict;

sub new {
    die "unable to load a user this way";
}

sub _new {
    my $self = {};
    bless $self, shift();
    return $self;
}

sub createAccount {
    my $class = shift();

    my %opts = ( @_ );
    return undef unless $opts{username} || $opts{external};

    my $u = $class->newFromUser($opts{username});
    if ($u) {
        return $u if $u->getPassword eq $opts{password};
        return undef;
    }

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    $dbh->do("INSERT INTO user (user, password, email, nickname) VALUES (?, ?, ?, ?)",
             undef, $opts{username}, $opts{password}, $opts{email}, $opts{nickname});
    return undef if $dbh->err;

    my $userid = $dbh->{mysql_insertid};
    return undef unless $userid;

    if ($opts{external}) {
        $dbh->do("INSERT INTO externalusers VALUES (?, 'U', ?)",
                 undef, $opts{external}, $userid);
        return undef if $dbh->err;

        $dbh->do("INSERT INTO externalusers VALUES (?, 'I', ?)",
                 undef, $userid, $opts{external});
        return undef if $dbh->err;

        $u = $class->newFromExternal($opts{external});
    }

    $u ||= $class->newFromUser($opts{username});
    return undef unless $u;

    LifeWiki::Page->noteUserCreation($u, \%opts);
    return $u;
}

sub newFromExternal {
    my $class = shift;
    my $ext = shift;

    # make sure we have a database
    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    # get the row from the database
    my $userid = $dbh->selectrow_array('SELECT extto FROM externalusers WHERE extfrom = ? AND exttype = ?',
                                       undef, $ext, 'U');
    return undef if $dbh->err;
    return undef unless $userid > 0;

    # now with the userid we can return it
    return $class->newFromUserid($userid);
}

sub newFromUser {
    my $self = shift()->_new();
    my $user = shift();

    # make sure we have a database
    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    # get the row from the database
    my $row = $dbh->selectrow_hashref('SELECT * FROM user WHERE user = ?', undef, $user);
    return undef if $dbh->err;
    return undef unless $row && ref $row eq 'HASH';

    # copy things we know about
    $self->{$_} = $row->{$_}
        foreach keys %$row;
    return $self;
}

sub newFromUserid {
    my $self = shift()->_new();
    my $userid = shift()+0;

    # make sure we have a database
    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    # get the row from the database
    my $row = $dbh->selectrow_hashref('SELECT * FROM user WHERE userid = ?', undef, $userid);
    return undef if $dbh->err;
    return undef unless $row && ref $row eq 'HASH';

    # copy things we know about
    $self->{$_} = $row->{$_}
        foreach keys %$row;
    return $self;
}

sub getUserid {
    return $_[0]->{userid};
}

sub getPassword {
    return $_[0]->{password};
}

sub getUsername {
    return $_[0]->{user};
}

sub _canonicalize {
    my $un = shift;
    $un =~ s/^\s+//;
    $un =~ s/\s+$//;
    return $un
        if $un =~ /^[\w\d_]{1,15}$/;
    return undef;
}

sub _canonicalize_nick {
    my $un = shift;
    $un =~ s/^\s+//;
    $un =~ s/\s+$//;
    return undef
        if $un =~ /[<>&]/;
    return $un;
}

sub setUsername {
    my $self = shift;
    return LifeWiki::error('changing a username is not supported')
        if $self->getUsername;

    my $username = LifeWiki::User::_canonicalize(shift);
    return LifeWiki::error('invalid username; must be 1-15 characters, numbers, or underscores')
        unless $username;

    my $u = LifeWiki::User->newFromUser($username);
    return LifeWiki::error('username already in use; please try again')
        if $u;

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    $dbh->do("UPDATE user SET user = ? WHERE userid = ?",
             undef, $username, $self->getUserid);
    return LifeWiki::error($dbh->errstr) if $dbh->err;

    $self->{user} = $username;

    LifeWiki::Page->noteUserCreation($self);
    return 1;
}

sub setNick {
    my $self = shift;

    my $username = LifeWiki::User::_canonicalize_nick(shift);
    return LifeWiki::error('invalid nickname; must be 1-100 reasonable characters')
        unless $username;

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    $dbh->do("UPDATE user SET nickname = ? WHERE userid = ?",
             undef, $username, $self->getUserid);
    return LifeWiki::error($dbh->errstr) if $dbh->err;

    $self->{nickname} = $username;
    return 1;
}

sub getNick {
    return $_[0]->{nickname};
}

sub getLinkedNick {
    my $tmp = $_[0]->{nickname} || $_->[0]->{user};
    return qq(<a href="/$_[0]->{user}">$tmp</a>);
}

sub newFromCookies {
    # need a database
    my $dbh = LifeWiki::getDatabase();
    die "no database" unless $dbh;

    # create a bare object
    my $class = shift();
    
    # now get our cookies
    my $cookies = shift();
    die "expected hashref to newFromCookies"
        unless ref $cookies eq 'HASH';

    # see if they gave us a session
    return undef unless
        my $session = $cookies->{session};
    $session = $session->value;
    return undef unless
        $session =~ /^(.+?):(.+?):(.*)$/;
    my ($userid, $unique, $opts) = ($1, $2, $3);

    # do some checking
    return undef unless
        $userid =~ /^\d+$/ &&
        $unique =~ /^[\w\d]{1,36}$/  &&
        $opts   =~ /^[\w\d]*$/;

    # now we can hit up the database to load this user
    my $self = $class->newFromUserid($userid)
        or return undef;

    # now see if the session they gave was good
    # FIXME: implement this

    return $self;
}

sub generateSession {
    my $self = shift;

    my $dbh = LifeWiki::getDatabase();
    die "no db" unless $dbh;

    my $sess = LifeWiki::rand_chars(36);
    $dbh->do("INSERT INTO sessions (userid, session, goodto) VALUES (?, ?, UNIX_TIMESTAMP() + 86400)",
             undef, $self->getUserid, $sess);
    return undef if $dbh->err;

    return $sess;
}

sub can {
    my $self = shift;
    my ($privname, $extraid) = @_;

    my $priv = $LifeWiki::PRIVILEGE_TABLE{$privname};
    die "No such privilege $privname\n" unless $priv;

    my $privid = $priv->{id};
    return undef unless $privid;

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    my $ct = $dbh->selectrow_array('SELECT COUNT(*) FROM access WHERE userid = ? AND privid = ? AND extraid = ?',
                                   undef, $self->getUserid, $privid, $extraid || 0);
    return undef if $dbh->err;
    return $ct ? 1 : 0;
}

sub revoke {
    my $self = shift;
    my ($privname, $extraid) = @_;

    my $priv = $LifeWiki::PRIVILEGE_TABLE{$privname};
    die "No such privilege $privname\n" unless $priv;

    my $privid = $priv->{id};
    return undef unless $privid;

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    $dbh->do("DELETE FROM access WHERE userid = ? AND privid = ? AND extraid = ?",
             undef, $self->getUserid, $privid, $extraid || 0);
    return undef if $dbh->err;
    return 1;
}

sub grant {
    my $self = shift;
    my ($privname, $extraid) = @_;

    my $priv = $LifeWiki::PRIVILEGE_TABLE{$privname};
    die "No such privilege $privname\n" unless $priv;

    my $privid = $priv->{id};
    return undef unless $privid;

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    $dbh->do("REPLACE INTO access (userid, privid, extraid) VALUES (?, ?, ?)",
             undef, $self->getUserid, $privid, $extraid || 0);
    return undef if $dbh->err;
    return 1;
}

sub getAccessList {
    my $self = shift;
    my $privname = shift;

    my $priv = $LifeWiki::PRIVILEGE_TABLE{$privname};
    die "No such privilege $privname\n" unless $priv;

    my $privid = $priv->{id};
    return undef unless $privid;

    my $dbh = LifeWiki::getDatabase();
    return undef unless $dbh;

    my $ids = $dbh->selectcol_arrayref('SELECT extraid FROM access WHERE userid = ? AND privid = ?',
                                       undef, $self->getUserid, $privid);
    return undef if $dbh->err;
    return undef unless $ids && ref $ids eq 'ARRAY';
    return @$ids;
}

1;
