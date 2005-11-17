% return unless $page;
% my $u = LifeWiki::User->newFromUserid($page->getAuthorId);

<div class='bar'>

% if ($page->isEditor($remote)) {
[<strong><a href="<% $page->getEditURI %>">Edit</a></strong>]
% }

[<strong><a href="<% $page->getDiffURI %>">Diff</a></strong>]

<%perl>
    my $vals = LifeWiki::runHooks('page_footer_extra', $page, $remote);
    foreach my $row (@{$vals || []}) {
        next unless $row;
        print $row;
    }
</%perl>

<em>
% if ($u) {
    Change #<% $page->getRevNum %> by <% $u->getLinkedNick %> at <% $page->getRevTime %>.
% } else {
    Change #<% $page->getRevNum %> by some unknown user at <% $page->getRevTime %>.
% }
</em>
</div>
