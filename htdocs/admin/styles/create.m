<%perl>
    my $args = $m->request_args;

    my $crname = $args->{crname};
    unless ($crname) {
        print "<p>Please enter a style to create.</p>";
        return;
    }

    my $ns = LifeWiki::Style::createNew($crname, $remote);
    unless ($ns) {
        print "<p>Failed to create the style.  Please verify it doesn't exist first.</p>";
        return;
    }

    $m->redirect("/admin/styles/view/" . $ns->getStyleId);
</%perl>
