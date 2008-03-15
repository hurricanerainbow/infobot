CREATE TABLE uptime (
 uptime INT UNSIGNED DEFAULT '0',
 endtime INT UNSIGNED DEFAULT '0',
 string VARCHAR(128) NOT NULL,
 PRIMARY KEY (uptime)
);

-- uptime is start time
-- endtime is endtime :)
