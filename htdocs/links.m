user:
<div id="toolbar_pane"><div class="toolbar"><ul><div class="toolbar">

% if ($remote) {
    <li><a href="/<% $remote->getUsername %>" title="Your Home">Your Home</a></li>
    <li><a href="/admin" accesskey="a" title="Admin Pages">Administration</a></li>
    <li><a href="/recent" accesskey="r" title="Your Edits">Your Edits</a></li>
    <li><a href="/prefs" accesskey="u" title="User Preferences">Preferences</a></li>
    <li><a href="/logout" title="Logout">Logout</a> (<% $remote->getUsername %>)</li>
% } else {
    <li><a href="/login">Login</a></li>
% }

</div></ul></div></div>

menu: 
<div id="toolbar_pane"><div class="toolbar"><ul><div class="toolbar">

<form method="post" action="/search" enctype="application/x-www-form-urlencoded" style="display: inline">
<input type="text" name="search_term" size="8" value="Search" onfocus="this.value=''" />
<input type="hidden" name="action" value="search" />
</form>

<li><a href="/index" accesskey="h" title="Home Page">Home</a></li>
<li><a href="/changes" accesskey="c" title="Recent Changes">Changes</a></li>

% if ($page) {
%     if ($page->isEditor($remote)) {
        <li><a href="<% $page->getEditURI %>" accesskey="e" title="Edit This Page">Edit</a></li>
%     }
%     if ($remote) {
        <li><a href="<% $page->getRevisionsURI %>" accesskey="r" title="Previous Revision">Revision <% $page->getRevNum %></a></li>
%     } else {
        <li>Revision <% $page->getRevNum %></li>
%     }
% }

</div></ul></div></div>
