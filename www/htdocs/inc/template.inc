<?
function bloot_header($title)
{
        ?><!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN"><?
        ?><html><head><title>B L O O T B O T . <? echo $title;
        ?></title><meta http-equiv="Content-Type" content="text/html;charset=iso-8859-1"><?
        ?></head><body bgcolor="#333333" link="3333bb"><?
        ?><table width="100%" border="0" cellspacing="0" cellpadding="3"><?
        ?><tr><?
        ?><td width="145" height="96"><a href="/"><?
        ?><img src="/img/logo.gif" width="145" height="96" border="0"><?
        ?></a></td><td valign="top"><?
        ?><div align="right"><?
        ?><font size="+3" color="#999999"><i><?
        ?>The slowest and most bloated bot in the world</i><?
        ?></font></div></td></tr><?
        ?><tr> <td rowspan="2" valign="top"><?
        bloot_menu();
        ?><br><?
        ?></td><?
        ?><td valign="top" width="100%" height="412"><?
}

function bloot_menu()
{
        ?><table width="100%" border="0" cellspacing="0" cellpadding="3"><?
        ?><tr bgcolor="#666666"> <?
        ?><td colspan="2" height="23"><font color="#FFFFFF" size="+1"><center><b>Download</center><?
        ?></b></font></td><?
        ?></tr><?
        ?><tr bgcolor="#999999"><?
        ?><td colspan="2"><?
	?><b>Releases:</b><?
        ?><p>CVS tarball<br><?
        ?>[<a href="/pub/blootbot-cvs.tar.gz">HTTP</a> | <a href="ftp://blootbot.sourceforge.net/pub/blootbot/blootbot-cvs.tar.gz">FTP</a>]<br><?
        ?><br><?
        ?><p>1.2.0 [Stable] tarball<br><?
        ?>[<a href="/pub/blootbot-1.2.0.tar.gz">HTTP</a> | <a href="ftp://blootbot.sourceforge.net/pub/blootbot/blootbot-1.2.0.tar.gz">FTP</a>]<br><?
        ?><br><?
        ?><p>1.1.0 [Old] tarball<br><?
        ?>[<a href="/pub/blootbot-1.1.0.tar.gz">HTTP</a> | <a href="ftp://blootbot.sourceforge.net/pub/blootbot/blootbot-1.1.0.tar.gz">FTP</a>]<br><?
        ?><br><?
        ?><p>1.0.3 [Old] tarball<br><?
        ?>[<a href="/pub/blootbot-1.0.3.tar.gz">HTTP</a> | <a href="ftp://blootbot.sourceforge.net/pub/blootbot/blootbot-1.0.3.tar.gz">FTP</a>]<br><?
        ?><br><?
	?>CVS Development:<br><?
	?>CVS <A HREF="http://sourceforge.net/cvs/?group_id=8794">download</A> info<BR><?
	?>* Download CVS <a href="http://cvs.sourceforge.net/cvstarballs/blootbot-cvsroot.tar.gz">Backup</a><br><?
        ?>* View <a href="http://cvs.sourceforge.net/viewcvs.py/blootbot/blootbot/"><?
        ?> CVS Tree</a></p><?
        ?></td><?
        ?></tr><?
        ?></table><?
        ?><br><?
        ?><table width="%" border="0" cellspacing="0" cellpadding="3"><?
        ?><tr bgcolor="#666666"><?
        ?><td colspan="2" height="23"><font color="#FFFFFF" size="+1"><b><center>Support</center><?
        ?></b></font></td><?
        ?></tr><?
        ?><tr bgcolor="#999999"><?
        ?><td colspan="2"><?
        ?><p><b>Documentation:</b><br><?
        ?><a href="/not.php">Installation<br><?
        ?>FAQ<br><?
        ?>Development</a><br><?
        ?><b>E-mail:</b><br><?
        ?><a href="http://sourceforge.net/support/?func=addsupport&amp;group_id=8794">Request<?
        ?> Support</a><br><?
        ?><b>Other:</b> <br><?
        ?><a href="http://sourceforge.net/bugs/?group_id=8794">BUG list</a><br><?
        ?><a href="http://sourceforge.net/forum/?group_id=8794">Discussion<?
        ?> Forum</a></p><?
        ?></td><?
        ?></tr><?
        ?></table><?
        ?><br><?
        ?><table width="100%" border="0" cellspacing="0" cellpadding="3"><?
        ?><tr bgcolor="#666666"><?
        ?><td colspan="2" height="23"><font color="#FFFFFF" size="+1"><b><center>Development</center><?
        ?></b></font></td><?
        ?></tr><?
        ?><tr bgcolor="#999999"><?
        ?><td colspan="2"><?
        ?><p>Report <a href="http://sourceforge.net/bugs/?func=addbug&amp;group_id=8794"><?
        ?> a BUG</a><br><?
        ?>View <a href="pub/TODO"><?
        ?> ToDo List</a><br><?
        ?><a href="http://sourceforge.net/project/admin/?group_id=8794">Admin<?
        ?></a></p><?
        ?></td><?
        ?></tr><?
        ?></table><?
}
function bloot_footer()
{
	?></td><?
        ?></tr><?
        ?><tr><? 
        ?><td valign="bottom" align="right"> <?
        ?><p><font color="#FFFFFF"><b><i>Hosted by:</i></b></font><br><?
        ?><a href="http://sourceforge.net"><?                           
        ?><img src="http://sourceforge.net/sflogo.php?group_id=0&type=1" width="88" height="31" border="0"<?
        ?>alt="SourceForge Logo"><?
        ?></a> </p><?              
        ?></td><?    
        ?></tr><?
        ?></table><?
        ?><p>&nbsp;</p><?
        ?></body><?      
        ?></html><?
}

function box_start($title,$author,$width)
{
	?><table width="<? echo $width 
	?>" border="0" cellspacing="0" cellpadding="3" align="center"><?
	?><tr bgcolor="#666666"><?
	?><td width="70%"><font color="#FFFFFF" size="+1"><? echo $title;
	?></font></td><?
	?><td width="100"><?
	?><div align="right"><i><font color="#333333"><? echo $author;
	?></font></i></div><?
	?></td><?
	?></tr><?
	?><tr bgcolor="#999999"><?
	?><td colspan="2"><?
	?><p><?
}

function box_end()
{
	?></td><?
	?></tr><?
	?></table><?
}

?>
