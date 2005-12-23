<%args> $arg </%args>

<%perl>
    $arg += 0;
    unless ($arg) {
        print "<p>You have reached this page in an invalid way.</p>";
        return;
    }

    my $nm = LifeWiki::Namespace->newById($arg);
    unless ($nm) {
        print "<p>That namespace doesn't seem to exist.</p>";
        return;
    }

    $title = $nm->getName;
    my $u = LifeWiki::User->newFromUserid($nm->getOwnerId);

    # assemble a list of styles this user can use
    my @styleids = $u->getAccessList('admin_style');
    my @styles;
    foreach my $sid (@styleids) {
        my $style = LifeWiki::Style->newById($sid);
        next unless $style;

        push @styles, [ $sid, $style->getName ];
    }
    @styles = sort { $a->[1] cmp $b->[1] } @styles;
    push @styles, [ 0, '---' ], [ 0, "Site Default / No Custom Theme" ];

    # other information we need
    my $isadmin = $remote->can('admin_namespace', $nm->getNamespaceId);
    my $cansetfp = $remote->can('create_namespaces');
    my $frontpage = $nm->isFrontpage;
    my $desc = $nm->getDescription;
    my $readsec = $nm->getReadSecurity;
    my $writesec = $nm->getWriteSecurity;
    my $styleid = $nm->getStyleId;
</%perl>

<div class='section'><h2>Namespace Information</h2>

<table>

<form method='post' action='/admin/namespaces/edit/<% $arg %>'>

<tr><td><b>Owner:</b></td><td><% $u ? $u->getLinkedNick : "...unknown..." %></td></tr>

<tr><td><b>Description:</b></td><td>
<input type='text' name='description' value='<% $desc %>' <% $isadmin ? '' : 'disabled="disabled"' %> maxlength='60' />
</td></tr>

<tr><td><b>Custom Theme:</b></td><td>
<select name="styleid" <% $isadmin ? '' : 'disabled="disabled"' %>>
% foreach my $row (@styles) {
<option value="<% $row->[0] %>" <% $styleid == $row->[0] ? 'selected' : '' %>><% $row->[1] %></option>
% }
</select></td></tr>

<tr><td><b>Front Page:</b></td><td>
<input type='checkbox' name='frontpage' value='1' <% $frontpage ? 'checked' : '' %><% $cansetfp ? '' : 'disabled="disabled"' %> />
(check to show on front page)
</td></tr>

<tr><td><b>Read Security:</b></td><td>
<select name="readsec" <% $isadmin ? '' : 'disabled="disabled"' %>>
<option value="public" <% $readsec eq 'public' ? 'selected' : '' %>>Public</option>
<option value="secure" <% $readsec eq 'secure' ? 'selected' : '' %>>Secure</option>
</select></td></tr>

<tr><td><b>Write Security:</b></td><td>
<select name="writesec" <% $isadmin ? '' : 'disabled="disabled"' %>>
<option value="public" <% $writesec eq 'public' ? 'selected' : '' %>>Public</option>
<option value="secure" <% $writesec eq 'secure' ? 'selected' : '' %>>Secure</option>
</select></td></tr>

<tr><td></td><td><input type='submit' value='Save Changes' <% $isadmin ? '' : 'disabled="disabled"' %> /></td></tr>

</form></table></div>

% if ($isadmin) {

<div class='section'><h2>Namespace Access</h2>

<form method='post' action='/admin/namespaces/revoke/<% $arg %>'>

<h3>Administrators</h3>
<p>
<%perl>
    foreach my $row (LifeWiki::getAccessList('admin_namespace', $arg)) {
        my $u = LifeWiki::User->newFromUserid($row->[0]);
        if ($u) {
            my $un = $u->getUserid;
            print " &nbsp; &nbsp; <input type='checkbox' id='an$un' name='admin_namespace:$un' value='1' /> " .
                  "<label for='an$un'>" . $u->getLinkedNick . " ($un)</label><br />";
        }
    }
</%perl>
</p>

<h3>Moderators</h3>
<p>
<%perl>
    foreach my $row (LifeWiki::getAccessList('moderate_namespace', $arg)) {
        my $u = LifeWiki::User->newFromUserid($row->[0]);
        if ($u) {
            my $un = $u->getUserid;
            print " &nbsp; &nbsp; <input type='checkbox' id='mn$un' name='moderate_namespace:$un' value='1' /> " .
                  "<label for='mn$un'>" . $u->getLinkedNick . " ($un)</label><br />";
        }
    }
</%perl>
</p>

<h3>Readers</h3>
<p>
<%perl>
    foreach my $row (LifeWiki::getAccessList('read_namespace', $arg)) {
        my $u = LifeWiki::User->newFromUserid($row->[0]);
        if ($u) {
            my $un = $u->getUserid;
            print " &nbsp; &nbsp; <input type='checkbox' id='rn$un' name='read_namespace:$un' value='1' /> " .
                  "<label for='rn$un'>" . $u->getLinkedNick . " ($un)</label><br />";
        }
    }
</%perl>
</p>

<h3>Revoke Access</h3>

<p>If you checked anything above, use this button to revoke those particular
access levels to this namespace.</p>

<p><input type='submit' value='Revoke Access' /> (immediate!)</p>

</form></div>

<div class='section'>

<h2>Grant Access</h2>

<form method='post' action='/admin/namespaces/grant/<% $arg %>'>

<p>Grant <select name='priv'>
<option value='admin_namespace'>Administrator</option>
<option value='moderate_namespace'>Moderator</option>
<option value='read_namespace' selected>Reader</option>
</select> level access to user id
<input type='text' name='user' size='12' />.</p>

<p><input type='submit' value='Grant Access' /> (immediate!)</p>

</form>

</div>

% }
