CREATE TABLE connections (
 server VARCHAR(30) NOT NULL,
 port INT NOT NULL DEFAULT '6667',
 nick VARCHAR(20) NOT NULL,
 nickservpass VARCHAR(8) NOT NULL,
 ircname VARCHAR (20) NOT NULL DEFAULT 'blootbot experimental bot',
 timeadded INT UNSIGNED DEFAULT 'UNIX_TIMESTAMP()',
 PRIMARY KEY (server,port,nick)
);
