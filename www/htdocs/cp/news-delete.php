<?
  require("/home/groups/b/bl/blootbot/htdocs/inc/template.inc");
  require("/home/groups/b/bl/blootbot/htdocs/inc/mysql.inc");
  require("/home/groups/b/bl/blootbot/htdocs/inc/news.inc");
  require("/home/groups/b/bl/blootbot/htdocs/inc/news-delete.inc");

  bloot_header("C O N T R O L . P A N E L:  N E W S . D E L E T E");
  ?><center><font face="arial" size="+1">C O N T R O L . P A N E L: N E W S . D E L E T E</font><p></center><?
  ?><font color="red" size="+3">DO NOT REFRESH THIS PAGE!</font><br><?
  ?><font color="red" size="+1"><i>Do not use the back button after submitting!<br>Please <a href="/cp">click here</a> to return to the control panel<?
  ?> or <a href="/cp/news-delete.php">here</a> to return to the news-delete control panel</font><?
  ?></font><?
   if ($id)
        delete_news($id);
  ?><form action="news-delete.php" method="get"><?
  ?><center>ID Number: <input type="text" name="id"> <?
  ?><br><b>ONCE NEWS IS DELETED, IT CAN NOT BE BROUGHT BACK. DELETE WITH CAUTION!. DO NOT ENTER AN INVALID ID, I DON'T KNOW WHAT WILL HAPPEN!<br></b><?
  ?><input type="submit"><?
  ?></center><?
  ?></form><?

  show_all_news();
  bloot_footer();
?>
