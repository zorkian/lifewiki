% if ($remote) {
You are <% $remote->getLinkedNick %>.<br /><br />
% }

user:
<ul>

% if ($remote) {
% if ($remote->hasHome) {
    <li><a href="/<% $remote->getHomeURL %>" title="Your Home">Your Home</a></li>
% }
    <li><a href="/admin" accesskey="a" title="Admin Pages">Administration</a></li>
    <li><a href="/recent" accesskey="r" title="Your Edits">Your Edits</a></li>
    <li><a href="/prefs" accesskey="u" title="User Preferences">Preferences</a></li>
    <li><a href="/logout" title="Logout">Logout</a></li>
% } else {
    <li><a href="/login">Login</a></li>
% }

</ul>

menu: 

<ul>

<li><a href="/index" accesskey="h" title="Home Page">Home</a></li>
<li><a href="/changes" accesskey="c" title="Recent Changes">Changes</a></li>

% if ($page) {
%     if ($page->isEditor($remote)) {
        <li><a href="<% $page->getEditURI %>" accesskey="e" title="Edit This Page">Edit</a></li>
%     }
%     if ($remote) {
        <li><a href="<% $page->getRevisionsURI %>" accesskey="r" title="Previous Revision">Revision <% $page->getRevNum %></a></li>
        <li><a href="<% $page->getDiffURI %>" title="Colored Differences to Last Version">Show Changes</a></li>
%     } else {
        <li>Revision <% $page->getRevNum %></li>
%     }
% }

</ul>

  shortcuts:
    <ul>
% foreach my $ns (LifeWiki::Namespace::getFrontpage()) {
      <li><a href="<% $ns->getURI %>"><% $ns->getDescription %></a></li>
% }
    </ul>

search:
 <form method="post" action="/search" enctype="application/x-www-form-urlencoded" style="display: inline">   
<p>
<input type="text" name="search_term" size="16" value="Search" onfocus="this.value=''" />
<input type="hidden" name="action" value="search" />
</p></form>


