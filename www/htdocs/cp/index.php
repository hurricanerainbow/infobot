<?
  require("/home/groups/b/bl/blootbot/htdocs/inc/template.inc");
  require("/home/groups/b/bl/blootbot/htdocs/inc/mysql.inc");
  require("/home/groups/b/bl/blootbot/htdocs/inc/news.inc");

  bloot_header("C O N T R O L . P A N E L");
?>

<center><font face="arial" size="+1">C O N T R O L . P A N E L</font><p></center>
<? box_start("Main Functions",".","90%"); ?>
<br><b>News Functions:</b><br>
<a href="news.php">Add News</a><br>
<a href="news-delete.php">Delete News</a><p>
<? box_end(); ?>

<?
  bloot_footer();
?>
