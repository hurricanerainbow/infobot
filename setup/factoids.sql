CREATE TABLE factoids (
	factoid_key VARCHAR(64) NOT NULL,

	requested_by VARCHAR(64),
	requested_time INT,
	requested_count SMALLINT UNSIGNED,
	created_by VARCHAR(64),
	created_time INT,

	modified_by VARCHAR(192),
	modified_time INT,

	locked_by VARCHAR(64),
	locked_time INT,

	factoid_value TEXT NOT NULL,

	PRIMARY KEY (factoid_key)
);
