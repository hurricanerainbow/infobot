CREATE TABLE connections (
 server VARCHAR(30) NOT NULL,
 port INT NOT NULL DEFAULT '6667',
 nick VARCHAR(20) NOT NULL,
 nickservpass VARCHAR(8) NOT NULL,
 ircname VARCHAR (20) NOT NULL DEFAULT 'blootbot experimental bot',
 timeadded INT UNSIGNED DEFAULT 'UNIX_TIMESTAMP()',
 PRIMARY KEY (server,port,nick)
);
INSERT INTO connections (server, port, nick, nickservpass, ircname) VALUES ('localhost','6667','abot','0password', 'abot blootbot');
INSERT INTO connections (server, port, nick, nickservpass, ircname) VALUES ('localhost','6667','bbot','0password', 'bbot blootbot');
INSERT INTO connections (server, port, nick, nickservpass, ircname) VALUES ('localhost','6667','cbot','0password', 'cbot blootbot');
