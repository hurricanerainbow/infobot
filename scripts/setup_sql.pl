#!/usr/bin/perl
# setup_tables: setup MYSQL/PGSQL side of things for blootbot.
# written by the xk.
###

require "src/core.pl";
require "src/logger.pl";
require "src/modules.pl";
require "src/Misc.pl";
require "src/interface.pl";

$bot_src_dir = "./src/";

# read param stuff from blootbot.config.
&loadConfig("files/blootbot.config");
&loadDBModules();
my $dbname = $param{'DBName'};
my $query;

if ($dbname eq "") {
  print "error: appears that teh config file was not loaded properly.\n";
  exit 1;
}

if ($param{'DBType'} =~ /mysql/i) {
    use DBI;

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
	&ERROR("error: adminuser || adminpass is NULL.");
	exit 1;
    }

    # open the db.
    &openDB($dbname, $adminuser, $adminpass);

    # retrieve a list of db's from the server.
    my %db;
    foreach ($dbh->func('_ListTables')) {
	$db{$_} = 1;
    }

    # Step 4.
    print "Step 4: Creating the tables.\n";

    # factoid db.
    if (!exists $db{'factoids'}) {
	print "  creating new table factoids...\n";

	$query = "CREATE TABLE factoids (".
		"factoid_key VARCHAR(64) NOT NULL,".

		"requested_by VARCHAR(64),".
		"requested_time INT,".
		"requested_count SMALLINT UNSIGNED,".
		"created_by VARCHAR(64),".
		"created_time INT,".

		"modified_by VARCHAR(192),".
		"modified_time INT,".

		"locked_by VARCHAR(64),".   
		"locked_time INT,".

		"factoid_value TEXT NOT NULL,".

		"PRIMARY KEY (factoid_key)".
	")";

	&dbRaw("create(factoids)", $query);
    }

    # freshmeat.
    if (!exists $db{'freshmeat'}) {
	print "  creating new table freshmeat...\n";

	$query = "CREATE TABLE freshmeat (".
		"name VARCHAR(64) NOT NULL,".
		"stable VARCHAR(32),".
		"devel VARCHAR(32),".
		"section VARCHAR(40),".
		"license VARCHAR(32),".
		"homepage VARCHAR(128),".
		"download VARCHAR(128),".
		"changelog VARCHAR(128),".
		"deb VARCHAR(128),".
		"rpm VARCHAR(128),".
		"link CHAR(55),".
		"oneliner VARCHAR(96) NOT NULL,".

		"PRIMARY KEY (name)".
	")";

	&dbRaw("create(freshmeat)", $query);
    }

    # karma.
    if (!exists $db{'karma'}) {
	print "  creating new table karma...\n";

	$query = "CREATE TABLE karma (".
		"nick VARCHAR(20) NOT NULL,".
		"karma SMALLINT UNSIGNED,".

		"PRIMARY KEY (nick)".
	")";

	&dbRaw("create(karma)", $query);
    }

    # rootwarn.
    if (!exists $db{'rootwarn'}) {
	print "  creating new table rootwarn...\n";

	$query = "CREATE TABLE rootwarn (".
		"nick VARCHAR(20) NOT NULL,".
		"attempt SMALLINT UNSIGNED,".
		"time INT NOT NULL,".
		"host VARCHAR(80) NOT NULL,".
		"channel VARCHAR(20) NOT NULL,".

		"PRIMARY KEY (nick)".
	")";

	&dbRaw("create(rootwarn)", $query);
    }

    # seen.
    if (!exists $db{'seen'}) {
	print "  creating new table seen...\n";

	$query = "CREATE TABLE seen (".
		"nick VARCHAR(20) NOT NULL,".
		"time INT NOT NULL,".
		"channel VARCHAR(20) NOT NULL,".
		"host VARCHAR(80) NOT NULL,".
		"messagecount SMALLINT UNSIGNED,".
		"hehcount SMALLINT UNSIGNED,".
		"message TINYTEXT NOT NULL,".

		"PRIMARY KEY (nick)".
	")";

	&dbRaw("create(seen)", $query);
    }

    ### USER SETUP.
    &closeDB();
    &openDB("mysql", $adminuser, $adminpass);

    # Step 1.
    &status("Step 1: Adding user information.");

    # Step 2.
    if (!&dbGet("user","user",$param{'SQLUser'},"user")) {
	&status("  Adding user $param{'SQLUser'} $dbname/user table...");

	$query = "INSERT INTO user VALUES ".
		"('localhost', '$param{'SQLUser'}', ".
		"password('$param{'SQLPass'}'), ";

	$query .= "'Y','Y','Y','Y','N','N','N','N','N','N','N','N','N','N')";
###	$query .= "'Y','Y','Y','Y','N','N','N','N','N','N')";

	&dbRaw("create(user)", $query);
    }

    # Step 3. what's this for?
    if (!&dbGet("db","db",$param{'SQLUser'},"db")) {
	&status("  Adding 'db' entry");

	$query = "INSERT INTO db VALUES ".
		"('localhost', '$dbname', ".
		"'$param{'SQLUser'}', ";

	$query .= "'Y','Y','Y','Y','Y','N','N','N','N','N')";
###	$query .= "'Y','Y','Y','Y','Y','N')";

	&dbRaw("create(db)", $query);
    }

    # grant.
    &status("  Granting user access to table.");
    $query = "GRANT SELECT,INSERT,UPDATE,DELETE ON $dbname TO $param{'SQLUser'}";
    &dbRaw("??", $query);

    # flush.
    &status("Flushing privileges...");
    $query = "FLUSH PRIVILEGES";		# DOES NOT WORK on slink?
    &dbRaw("mysql(flush)", $query);

    # create database.
    &status("Creating database $param{'DBName'}...");
    $query = "CREATE DATABASE $param{'DBName'}";
    &dbRaw("create(db $param{'DBName'})", $query);

} elsif ($param{'DBType'} =~ /pgsql|postgres/i) {
    if ($param{'DBType'} =~ /pgsql|postgres/i) { use Pg; } # for runtime.
    my $dbh = Pg::connectdb("dbname=$dbname");

    if (PGRES_CONNECTION_OK eq $conn->status) {
	print "  opened mysql connection to $param{'mysqlHost'}\n";
    } else {
	print "  error: cannot connect to $param{'mysqlHost'}.\n";
	print "  $conn->errorMessage\n";
	exit 1;
    }

    # retrieve a list of db's from the server.
    my %db;
    foreach ($dbh->func('_ListTables')) {
	$db{$_} = 1;
    }

    # Step 4.
    print "Step 4: Creating the tables.\n";

    # factoid db.
    if (!exists $db{'factoids'}) {
	print "  creating new table factoids...\n";

	$query = "CREATE TABLE factoids (".
		"factoid_key varying(64) NOT NULL,".

		"requested_by varying(64),".
		"requested_time numeric(11,0),".
		"requested_count numeric(5,0),".
		"created_by varying(64),".
		"created_time numeric(11,0),".

		"modified_by character varying(192),".
		"modified_time numeric(11,0),".

		"locked_by character varying(64),".
		"locked_time numeric(11,0),".

		"factoid_value text NOT NULL,".

		"PRIMARY KEY (factoid_key)".
	")";

	&dbRaw("create(factoids)", $query);
    }

    # freshmeat.
    if (!exists $db{'freshmeat'}) {
	print "  creating new table freshmeat...\n";

	$query = "CREATE TABLE freshmeat (".
		"name charcter varying(64) NOT NULL,".
		"stable character varying(32),".
		"devel character varying(32),".
		"section character varying(40),".
		"license character varying(32),".
		"homepage character varying(128),".
		"download character varying(128),".
		"changelog character varying(128),".
		"deb character varying(128),".
		"rpm character varying(128),".
		"link character varying(55),".
		"oneliner character varying(96) NOT NULL,".

		"PRIMARY KEY (name)".
	")";

	&dbRaw("create(freshmeat)", $query);
    }

    # karma.
    if (!exists $db{'karma'}) {
	print "  creating new table karma...\n";

	$query = "CREATE TABLE karma (".
		"nick character varying(20) NOT NULL,".
		"karma numeric(5,0),".

		"PRIMARY KEY (nick)".
	")";

	&dbRaw("create(karma)", $query);
    }

    # rootwarn.
    if (!exists $db{'rootwarn'}) {
	print "  creating new table rootwarn...\n";

	$query = "CREATE TABLE rootwarn (".
		"nick character varying(20) NOT NULL,".
		"attempt numeric(5,0),".
		"time numeric(11,0) NOT NULL,".
		"host character varying(80) NOT NULL,".
		"channel character varying(20) NOT NULL,".

		"PRIMARY KEY (nick)".
	")";

	&dbRaw("create(rootwarn)", $query);
    }

    # seen.
    if (!exists $db{'seen'}) {
	print "  creating new table seen...\n";

	$query = "CREATE TABLE seen (".
		"nick character varying(20) NOT NULL,".
		"time numeric(11,0) NOT NULL,".
		"channel character varying(20) NOT NULL,".
		"host character varying(80) NOT NULL,".
		"messagecount numeric(5,0),".
		"hehcount numeric(5,0),".
		"message text NOT NULL,".

		"PRIMARY KEY (nick)".
	")";

	&dbRaw("create(seen)", $query);
    }
}

print "Done.\n";

&closeDB();
