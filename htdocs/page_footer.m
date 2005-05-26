% return unless $page;
% my $u = LifeWiki::User->newFromUserid($page->getAuthorId);

<div style="background-color: #eee">
% if ($page->isEditor($remote)) {
[<strong><a href="<% $page->getEditURI %>">Edit</a></strong>]
% }
<em>
% if ($u) {
    Last changed by <% $u->getLinkedNick %> at <% $page->getRevTime %>.
% } else {
    Last changed by some unknown user at <% $page->getRevTime %>.
% }
</em>
</div>
