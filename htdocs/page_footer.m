% return unless $page;
% my $u = LifeWiki::User->newFromUserid($page->getAuthorId);

<div style="background-color: #eee">
<em>
% if ($u) {
    Last changed by <a href="/<% $u->getUsername %>"><% $u->getNick %></a> at <% $page->getRevTime %>.
% } else {
    Last changed by some unknown user at <% $page->getRevTime %>.
% }
</em>
</div>
