<%perl>
    my $args = $m->request_args;

    my $crname = $args->{crname};
    unless ($crname) {
        print "<p>Please enter a namespace to create.</p>";
        return;
    }

print "not done";
</%perl>
