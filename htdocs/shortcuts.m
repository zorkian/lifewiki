  shortcuts:
  <div id="toolbar_pane">
    <!-- Dynamic Links -->
    <ul>
% foreach my $ns (LifeWiki::Namespace::getFrontpage()) {
      <li><a href="<% $ns->getURI %>"><% $ns->getDescription %></a></li>
% }
    </ul>

    <!-- Static Links -->
    <ul>
      <li><a href="http://www.sixapart.com/">Corporate Homepage</a></li>
      <li><a href="http://intranet.sixapart.com/mt/">Internal Blogs</a></li>
      <li><a href="/index/NewAtSixApart">New at Six Apart?</a></li>

      <li><a href="/index/PeoPle">People at Six Apart</a></li>
    </ul>
  </div>
