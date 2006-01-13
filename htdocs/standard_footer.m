% return unless $page;
% my $u = LifeWiki::User->newFromUserid($page->getAuthorId);

<div class='bar'>

% unless ($remote) {
[<strong><a href="/login">Login</a></strong>]
% }

[<strong><a href="/<% $page->getURI %>">Back to Page</a></strong>]

</div>
