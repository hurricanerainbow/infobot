CREATE TABLE connections (
    server character varying(30) NOT NULL,
    port integer DEFAULT 6667 NOT NULL,
    nick character varying(20) NOT NULL,
    nickservpass character varying(8) NOT NULL,
    ircname character varying(20) DEFAULT 'blootbot IRC bot'::character varying NOT NULL,
    timeadded numeric DEFAULT 0
) WITHOUT OIDS;

REVOKE ALL ON TABLE connections FROM PUBLIC;

ALTER TABLE ONLY connections
    ADD CONSTRAINT connections_pkey PRIMARY KEY (server, port, nick);
