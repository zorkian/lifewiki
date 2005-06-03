% if ($remote) {
<div class='box'>
You are <% $remote->getLinkedNick %>.
</div>
% }

user:
<div class='box'>
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
</div>

menu: 
<div class='box'>
<ul>

<li><a href="/index" accesskey="h" title="Home Page">Home</a></li>
<li><a href="/changes" accesskey="c" title="Recent Changes">Recent Changes</a></li>

</ul>
</div>

  shortcuts:
<div class='box'>
    <ul>
% foreach my $ns (LifeWiki::Namespace::getFrontpage()) {
      <li><a href="<% $ns->getURI %>"><% $ns->getDescription %></a></li>
% }
    </ul>
</div>

<form method="post" action="/search" enctype="application/x-www-form-urlencoded" style="display: inline">   
<p>
<input type="text" name="search_term" size="16" value="Search" onfocus="this.value=''" />
<input type="hidden" name="action" value="search" />
</p></form>

