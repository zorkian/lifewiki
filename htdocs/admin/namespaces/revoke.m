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
    foreach my $key (keys %$args) {
        next unless $args->{$key} == 1;
        next unless $key =~ /^((?:admin|moderate|read)_namespace):(\w+)$/;
        my ($pname, $user) = ($1, $2);

        my $u = LifeWiki::User->newFromUser($user);
        next unless $u;

        # hah
        next if $u->getUserid == $remote->getUserid;

        $u->revoke($pname, $arg);
    }

    $m->redirect("/admin/namespaces/view/$arg");
</%perl>
