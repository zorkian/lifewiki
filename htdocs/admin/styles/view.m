<%args> $arg </%args>

<%perl>
    $arg += 0;
    unless ($arg) {
        print "<p>You have reached this page in an invalid way.</p>";
        return;
    }

    my $nm = LifeWiki::Style->newById($arg);
    unless ($nm) {
        print "<p>That style doesn't seem to exist.</p>";
        return;
    }

    my $isadmin = $remote->can('admin_style', $nm->getStyleId);
    unless ($isadmin) {
        print "<p>You do not have access to do that.</p>";
        return;
    }

    $title = $nm->getName;
    my $u = $nm->getOwner;
    my $content = $nm->getContent;
</%perl>

<div class='section'><h2>Style Information</h2>

<table>

<form method='post' action='/admin/styles/edit/<% $arg %>'>

<tr><td><b>Owner:</b></td><td><% $u ? $u->getLinkedNick : "...unknown..." %></td></tr>

<tr><td><b>Name:</b></td><td>
<input type='text' name='name' value='<% $title %>' <% $isadmin ? '' : 'disabled="disabled"' %> maxlength='255' />
</td></tr>

<tr><td><b>Content:</b></td><td>
<textarea name='content' rows='30' cols='75' <% $isadmin ? '' : 'disabled="disabled"' %>><% LifeWiki::ehtml($content) %></textarea>
</td></tr>

<tr><td></td><td><input type='submit' value='Save Changes' <% $isadmin ? '' : 'disabled="disabled"' %> /></td></tr>

</form></table></div>

% if ($isadmin) {

<div class='section'><h2>Style Access</h2>

<form method='post' action='/admin/styles/revoke/<% $arg %>'>

<h3>Administrators</h3>
<p>
<%perl>
    foreach my $row (LifeWiki::getAccessList('admin_style', $arg)) {
        my $u = LifeWiki::User->newFromUserid($row->[0]);
        if ($u) {
            my $un = $u->getUserid;
            print " &nbsp; &nbsp; <input type='checkbox' id='an$un' name='admin_style:$un' value='1' /> " .
                  "<label for='an$un'>" . $u->getLinkedNick . " ($un)</label><br />";
        }
    }
</%perl>
</p>

<h3>Revoke Access</h3>

<p>If you checked anything above, use this button to revoke those people from using this
style.  This will disallow people from editing this style.</p>

<p><input type='submit' value='Revoke Access' /> (immediate!)</p>

</form></div>

<div class='section'>

<h2>Grant Access</h2>

<form method='post' action='/admin/styles/grant/<% $arg %>'>

<p>Grant <select name='priv'>
<option value='admin_style'>Administrator</option>
</select> level access to user id
<input type='text' name='user' size='12' />.</p>

<p><input type='submit' value='Grant Access' /> (immediate!)</p>

</form>

</div>

% }
