<?
  require("/home/groups/b/bl/blootbot/htdocs/inc/template.inc");
  require("/home/groups/b/bl/blootbot/htdocs/inc/mysql.inc");
  require("/home/groups/b/bl/blootbot/htdocs/inc/news.inc");

  bloot_header("C O N T R O L . P A N E L:  N E W S");
  ?><center><font face="arial" size="+1">C O N T R O L . P A N E L: N E W S</font><p></center><?
  ?><font color="red" size="+3">DO NOT REFRESH THIS PAGE!</font><br><?
  ?><font color="red" size="+1"><i>Do not use the back button after submitting!<br>Please <a href="/cp">click here</a> to return to the control panel<?
  ?> or <a href="/cp/news.php">here</a> to return to the news control panel</font><?
  ?></font><?
   if ($author && $title && $message)
        add_news($author,$title,$message);

  ?><form action="news.php" method="get"><?
  ?><center>Title: <input type="text" name="title"> <?
  ?>Author: <input type="text" name="author"><?
  ?><br><b>WARNING: Once news is added, it CAN NOT BE CHANGED. Make sure that all the fields are filled out and use propper HTML.</b><br><?
  ?><input type="submit"><br>Message:<br><?
  ?><textarea name="message" rows=10 cols=40><?
  ?></textarea></center><?
  ?></form><?

  bloot_footer();
?>
