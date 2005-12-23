<%args> $arg </%args>

<%perl>
    $arg += 0;
    unless ($arg) {
        print "<p>You have reached this page in an invalid way.</p>";
        return;
    }
    
    my $nm = LifeWiki::Style->newById($arg);
    unless ($nm) {
        print "<p>That style doesn't seem to exist.</p>";
        return;
    }
    
    my $args = $m->request_args;
    my ($pname, $user) = ($args->{priv}, $args->{user});
    unless ($pname =~ /^(?:admin)_style$/) {
        print "<p>Invalid privilege selected.</p>";
        return;
    }

    my $priv = $LifeWiki::PRIVILEGE_TABLE{$pname};
    unless ($priv) {
        print "<p>Invalid privilege selected.</p>";
        return;
    }

    my $u = LifeWiki::User->newFromUserid($user);
    unless ($u) {
        print "<p>The user id you entered was invalid.</p>";
        return;
    }

    $u->grant($pname, $arg);
    $m->redirect("/admin/styles/view/$arg");
</%perl>
