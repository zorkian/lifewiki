<%args> $arg </%args>

<%perl>
    $arg += 0;
    unless ($arg) {
        print "<p>You have reached this page in an invalid way.</p>";
        return;
    }
    
    my $nm = LifeWiki::Namespace->newById($arg);
    unless ($nm) {
        print "<p>That namespace doesn't seem to exist.</p>";
        return;
    }
    
    my $args = $m->request_args;
    my ($pname, $user) = ($args->{priv}, $args->{user});
    unless ($pname =~ /^(?:admin|moderate|read)_namespace$/) {
        print "<p>Invalid privilege selected.</p>";
        return;
    }

    my $priv = $LifeWiki::PRIVILEGE_TABLE{$pname};
    unless ($priv) {
        print "<p>Invalid privilege selected.</p>";
        return;
    }

    my $u = LifeWiki::User->newFromUser($user);
    unless ($u) {
        print "<p>The username you entered was invalid.</p>";
        return;
    }

    $u->grant($pname, $arg);
    $m->redirect("/admin/namespaces/view/$arg");
</%perl>
