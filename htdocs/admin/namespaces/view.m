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

    my $isadmin = $remote->can('admin_namespace', $nm->getNamespaceId);
    my $cansetfp = $remote->can('create_namespaces');
    my $frontpage = $nm->isFrontpage;
    my $desc = $nm->getDescription;
    my $readsec = $nm->getReadSecurity;
    my $writesec = $nm->getWriteSecurity;
</%perl>

<table>

<form method='post' action='/admin/namespaces/edit/<% $arg %>'>

<tr><td><b>Owner:</b></td><td><% $u ? $u->getUsername : "...unknown..." %></td></tr>

<tr><td><b>Description:</b></td><td>
<input type='text' name='description' value='<% $desc %>' <% $isadmin ? '' : 'disabled="disabled"' %> maxlength='60' />
</td></tr>

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

</form>

</table>
