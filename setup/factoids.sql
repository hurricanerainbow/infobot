CREATE TABLE factoids (
	factoid_key VARCHAR(64) NOT NULL,

	requested_by VARCHAR(64) NOT NULL DEFAULT 'nobody',
	requested_time INT NOT NULL DEFAULT '0',
	requested_count SMALLINT UNSIGNED NOT NULL DEFAULT '0',
	created_by VARCHAR(64),
	created_time INT NOT NULL DEFAULT '0',

	modified_by VARCHAR(192),
	modified_time INT NOT NULL DEFAULT '0',

	locked_by VARCHAR(64),
	locked_time INT NOT NULL DEFAULT '0',

	factoid_value TEXT NOT NULL,

	PRIMARY KEY (factoid_key)
);
