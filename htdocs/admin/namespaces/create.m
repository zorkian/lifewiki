<%perl>
    my $args = $m->request_args;

    my $crname = $args->{crname};
    unless ($crname) {
        print "<p>Please enter a namespace to create.</p>";
        return;
    }

    my $ns = LifeWiki::Namespace::createNew($crname, $remote);
    unless ($ns) {
        print "<p>Failed to create the namespace.  Please verify it doesn't exist first.</p>";
        return;
    }

    $m->redirect("/admin/namespaces/view/" . $ns->getNamespaceId);
</%perl>
