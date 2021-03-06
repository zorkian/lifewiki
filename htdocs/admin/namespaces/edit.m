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
    my ($desc, $fp, $readsec, $writesec, $styleid) = map { $args->{$_} } qw(description frontpage readsec writesec styleid);

    $desc ||= $nm->getName;
    $fp += 0;
    $readsec = 'secure' unless $readsec eq 'public';
    $writesec = 'secure' unless $writesec eq 'public';
    $styleid += 0;

    $nm->setDescription($desc);
    $nm->setReadSecurity($readsec);
    $nm->setWriteSecurity($writesec);
    $nm->setStyleId($styleid);
    $nm->setFrontpage($fp) if $remote->can('create_namespaces');

    $m->redirect("/admin/namespaces/view/$arg");
</%perl>
