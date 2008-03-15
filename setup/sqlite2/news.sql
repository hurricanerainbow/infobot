CREATE TABLE news (
 channel VARCHAR(30) NOT NULL,
 id INT UNSIGNED DEFAULT '0',
 key VARCHAR(16) NOT NULL,
 value TEXT NOT NULL,
 PRIMARY KEY (channel,id,key)
);
-- limit value to ~450 or so.
