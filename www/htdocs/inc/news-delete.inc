<?
function show_all_news() {
  global $db_name,$db_handle
  $query = "SELECT * from news ORDER BY id desc";

  if (! $result = mysql_db_query($db_name,$query,$db_handle)) {
  echo "MYSQL ERROR";
  }
?><br>ID - Title - Date<br><?
  while($news = mysql_fetch_array($result))
  {
    echo $news["id"];
    ?> - <?
    echo $news["title"];
    ?> - <?
    echo date("F d, Y",$news["timestamp"]);
    ?><br><?
  }
}

function delete_news($id)
{
  global $db_name,$db_handle
  $query = "delete from news where id = $id";

  if (! $result = mysql_db_query($db_name,$query,$db_handle)) {
  echo "MYSQL ERROR";
  }
  ?><br>News ID: <?
  echo $id;
  ?>Has been deleted<?
}
?>
