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

    $title = $nm->getName;
    my $u = LifeWiki::User->newFromUserid($nm->getOwnerId);

    my $isadmin = $remote->can('admin_namespace', $nm->getNamespaceId);

</%perl>

    <b>Owner:</b> <% $u ? $u->getUsername : "...unknown..." %><br />
% if ($isadmin) {
    <b>Read Security:</b> <% $nm->getReadSecurity %> (you can change one day)<br />
    <b>Write Security:</b> <% $nm->getWriteSecurity %> (you can change one day)<br />
    <br />
    You're an admin so soon this page will have options for you to change the security...
% } else {
    <b>Read Security:</b> <% $nm->getReadSecurity %><br />
    <b>Write Security:</b> <% $nm->getWriteSecurity %>
% }
