#!/usr/bin/perl
# setup_users: setup MYSQL/PGSQL side of things for blootbot.
# written by the xk.
###

require "src/core.pl";
require "src/Misc.pl";
require "src/logger.pl";
require "src/modules.pl";
$bot_src_dir = "./src";

&loadConfig("files/blootbot.config");
&loadDBModules();

my $dbname = $param{'DBName'};
my $query;

if ($dbname eq "") {
  print "error: appears that teh config file was not loaded properly.\n";
  exit 1;
}

if ($param{'DBType'} =~ /mysql/i) {

    print "Enter root information...\n";
    # username.
    print "Username: ";
    chop (my $adminuser = <STDIN>);

    # passwd.
    system "stty -echo";
    print "Password: ";
    chop(my $adminpass = <STDIN>);
    print "\n";
    system "stty echo";

    if ($adminuser eq "" or $adminpass eq "") {
	print "error: adminuser || adminpass is NULL.\n";
	exit 1;
    }

    # Step 1.
    print "Step 1: Adding user information.\n";

    # open the db.
    &openDB("mysql", $adminuser, $adminpass);

    # Step 2.
    if (!&dbGet("user","user",$param{'SQLUser'},"user")) {
	print "  Adding user $param{'SQLUser'} $dbname/user table...\n";

	$query = "INSERT INTO user VALUES ".
		"('localhost', '$param{'SQLUser'}', ".
		"password('$param{'SQLPass'}'), ";

	$query .= "'Y','Y','Y','Y','N','N','N','N','N','N','N','N','N','N')";
###	$query .= "'Y','Y','Y','Y','N','N','N','N','N','N')";

	&dbRaw("create(user)", $query);
    }

    # Step 3. what's this for?
    if (!&dbGet("db","db",$param{'SQLUser'},"db")) {
	print "  Adding 'db' entry\n";

	$query = "INSERT INTO db VALUES ".
		"('localhost', '$dbname', ".
		"'$param{'SQLUser'}', ";

	$query .= "'Y','Y','Y','Y','Y','N','N','N','N','N')";
###	$query .= "'Y','Y','Y','Y','Y','N')";

	&dbRaw("create(db)", $query);
    }

    # grant.
    print "  Granting user access to table.\n";
    $query = "GRANT SELECT,INSERT,UPDATE,DELETE ON $dbname TO $param{'SQLUser'}";
    &dbRaw("??", $query);

    # flush.
    print "Flushing privileges...\n";
    $query = "FLUSH PRIVILEGES";		# DOES NOT WORK on slink?
    &dbRaw("mysql(flush)", $query);

    # create database.
    print "Creating database $param{'DBName'}...\n";
    $query = "CREATE DATABASE $param{'DBName'}";
    &dbRaw("create(db $param{'DBName'})", $query);
} elsif ($param{'DBType'} =~ /pg|postgres/i) {
    use Pg;
#    &openDB();

    print "FIXME\n";
}

&closeDB();
