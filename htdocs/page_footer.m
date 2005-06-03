% return unless $page;
% my $u = LifeWiki::User->newFromUserid($page->getAuthorId);

<div style="background-color: #eee; width: 100%;">

% if ($page->isEditor($remote)) {
[<strong><a href="<% $page->getEditURI %>">Edit</a></strong>]
% }

[<strong><a href="<% $page->getDiffURI %>">Diff</a></strong>]

<em>
% if ($u) {
    Change #<% $page->getRevNum %> by <% $u->getLinkedNick %> at <% $page->getRevTime %>.
% } else {
    Change #<% $page->getRevNum %> by some unknown user at <% $page->getRevTime %>.
% }
</em>
</div>
