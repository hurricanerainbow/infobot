#!/usr/bin/perl
# setup_users: setup MYSQL/PGSQL side of things for blootbot.
# written by the xk.
###

require "src/core.pl";
require "src/Misc.pl";
require "src/logger.pl";

&loadConfig("files/infobot.config");
my $dbname = $param{'DBName'};
my $query;

if ($dbname eq "") {
  print "error: appears that teh config file was not loaded properly.\n";
  exit 1;
}

if ($param{'DBType'} =~ /mysql/i) {
    if (!scalar @ARGV) {
	print "hi there.\n\n";

	print "if you're running a new version of mysql (debian potato), run\n";
	print "this script with the '1' parameter while '0' for older versions\n";
	print "(debian slink).\n";
	exit 0;
    }

    my $mysqlversion;
    if ($ARGV[0] =~ /^\d+$/) {
	if ($ARGV[0] == 0) {
	    $mysqlversion = 0;
	} elsif ($ARGV[0] == 1) {
	    $mysqlversion = 1;
	} else {
	    print "error: wrong integer?\n";
	}
    } else {
	print "error: wrong argument?\n";
	exit 1;
    }

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
    &openDB();

    # Step 2.
    if (!&sqlGet("user","user",$param{'mysqlUser'},"user")) {
	print "  Adding user $param{'mysqlUser'} $dbname/user table...\n";

	$query = "INSERT INTO user VALUES ".
		"('localhost', '$param{'mysqlUser'}', ".
		"password('$param{'mysqlPass'}'), ";

	if ($mysqlversion) {
	    $query .= "'Y','Y','Y','Y','N','N','N','N','N','N','N','N','N','N')";
	} else {
	    $query .= "'Y','Y','Y','Y','N','N','N','N','N','N')";
	}

	&dbRaw("create(user)", $query);
    }

    # Step 3. what's this for?
    if (!&sqlGet("db","db",$param{'mysqlUser'},"db")) {
	print "  Adding 'db' entry\n";

	$query = "INSERT INTO db VALUES ".
		"('localhost', '$dbname', ".
		"'$param{'mysqlUser'}', ";

	if ($mysqlversion) {
	    $query .= "'Y','Y','Y','Y','Y','N','N','N','N','N')";
	} else {
	    $query .= "'Y','Y','Y','Y','Y','N')";
	}

	&dbRaw("create(db)", $query);
    }

    # grant.
    print "  Granting user access to table.\n";
    $query = "GRANT SELECT,INSERT,UPDATE,DELETE ON $dbname TO $param{'mysqlUser'}";
    &dbRaw($query);

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
    &openDB();

    print "FIXME\n";
}

&closeDB();
