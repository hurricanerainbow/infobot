<?
function show_news($limit=5) {
  global $db_name,$db_handle;

  $query = "SELECT * from news ORDER BY id desc LIMIT $limit";
  $result = mysql_db_query($db_name,$query,$db_handle);

  while($news = mysql_fetch_array($result))
  {
    ?><p><?
    box_start($news["title"],date("F d, Y",$news["timestamp"])." <br>Posted by ".$news["author"],"90%");
    echo $news["message"];
    box_end();
  }
}

function add_news($author,$title,$message) {
  global $db_name,$db_handle;

  $timestamp = time();
  $query = "INSERT INTO news (timestamp,title,author,message) VALUES ('$timestamp','$title','$author','$message')";
  $result = mysql_db_query($db_name,$query,$db_handle);
  if (!$result)
   print("MySQL Error: " . mysql_error());
}

?>

