CREATE TABLE uptime (
	uptime	INT UNSIGNED DEFAULT '0',	# start.
	endtime	INT UNSIGNED DEFAULT '0',	# end.

	string	VARCHAR(128) NOT NULL,

	PRIMARY KEY (uptime)
);
