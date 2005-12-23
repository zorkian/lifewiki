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
    my ($name, $content) = map { $args->{$_} } qw(name content);

    $nm->setName($name);
    $nm->setContent($content);

    $m->redirect("/admin/styles/view/$arg");
</%perl>
