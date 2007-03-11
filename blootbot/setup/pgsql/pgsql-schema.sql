SET client_encoding = 'UNICODE';
SET check_function_bodies = false;

REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;

SET search_path = public, pg_catalog;

CREATE TABLE factoids (
    factoid_key character varying(64) NOT NULL,
    factoid_value text NOT NULL,
    created_by character varying(80),
    modified_by character varying(80),
    locked_by character varying(80),
    requested_time numeric(11,0) DEFAULT 0 NOT NULL,
    requested_count numeric(5,0) DEFAULT 0 NOT NULL,
    locked_time numeric(11,0) DEFAULT 0 NOT NULL,
    created_time numeric(11,0) DEFAULT 0 NOT NULL,
    modified_time numeric(11,0) DEFAULT 0 NOT NULL,
    requested_by character varying(80) DEFAULT 'nobody'::character varying NOT NULL
) WITHOUT OIDS;

REVOKE ALL ON TABLE factoids FROM PUBLIC;

CREATE TABLE botmail (
    srcwho character varying(20) NOT NULL,
    dstwho character varying(20) NOT NULL,
    srcuh character varying(80) NOT NULL,
    msg text NOT NULL,
    "time" numeric DEFAULT 0 NOT NULL
) WITHOUT OIDS;

REVOKE ALL ON TABLE botmail FROM PUBLIC;

SET SESSION AUTHORIZATION 'blootbot';

CREATE TABLE connections (
    server character varying(30) NOT NULL,
    port integer DEFAULT 6667 NOT NULL,
    nick character varying(20) NOT NULL,
    nickservpass character varying(8) NOT NULL,
    ircname character varying(20) DEFAULT 'blootbot experimental bot'::character varying NOT NULL,
    timeadded timestamp without time zone DEFAULT now()
) WITHOUT OIDS;

REVOKE ALL ON TABLE connections FROM PUBLIC;

CREATE TABLE freshmeat (
    projectname_short character varying(64) NOT NULL,
    latest_version character varying(32) DEFAULT 'none'::character varying NOT NULL,
    license character varying(32),
    url_homepage character varying(128),
    desc_short character varying(96) NOT NULL
) WITHOUT OIDS;

REVOKE ALL ON TABLE freshmeat FROM PUBLIC;

CREATE TABLE news (
    channel character varying(16) NOT NULL,
    id numeric DEFAULT 0 NOT NULL,
    "key" character varying(16) NOT NULL,
    value text NOT NULL
) WITHOUT OIDS;

REVOKE ALL ON TABLE news FROM PUBLIC;

CREATE TABLE onjoin (
    nick character varying(20) NOT NULL,
    channel character varying(16) NOT NULL,
    message character varying(255) NOT NULL,
    modified_by character varying(20) DEFAULT 'nobody'::character varying NOT NULL,
    modified_time numeric DEFAULT 0 NOT NULL
) WITHOUT OIDS;

REVOKE ALL ON TABLE onjoin FROM PUBLIC;

CREATE TABLE rootwarn (
    nick character varying(20) NOT NULL,
    attempt numeric,
    "time" integer NOT NULL,
    host character varying(80) NOT NULL,
    channel character varying(20) NOT NULL
) WITHOUT OIDS;

REVOKE ALL ON TABLE rootwarn FROM PUBLIC;

CREATE TABLE seen (
    nick character varying(20) NOT NULL,
    "time" numeric NOT NULL,
    channel character varying(20) NOT NULL,
    host character varying(80) NOT NULL,
    message text NOT NULL,
    hehcount numeric DEFAULT 0::numeric NOT NULL,
    messagecount numeric DEFAULT 0::numeric NOT NULL
) WITHOUT OIDS;

REVOKE ALL ON TABLE seen FROM PUBLIC;

CREATE TABLE stats (
    nick character varying(20) NOT NULL,
    "type" character varying(8) NOT NULL,
    channel character varying(16) DEFAULT 'PRIVATE'::character varying NOT NULL,
    counter numeric DEFAULT 0,
    "time" numeric DEFAULT 0 NOT NULL
) WITHOUT OIDS;

REVOKE ALL ON TABLE stats FROM PUBLIC;

CREATE TABLE uptime (
    uptime numeric DEFAULT 0 NOT NULL,
    endtime numeric DEFAULT 0,
    string character varying(128) NOT NULL
) WITHOUT OIDS;

REVOKE ALL ON TABLE uptime FROM PUBLIC;

CREATE TABLE karma (
    nick character varying(20) DEFAULT ''::character varying NOT NULL,
    karma numeric
);

REVOKE ALL ON TABLE karma FROM PUBLIC;

CREATE INDEX factoids_idx_fvalue ON factoids USING hash (factoid_value);

ALTER TABLE ONLY factoids
    ADD CONSTRAINT factoids_pkey_fkey PRIMARY KEY (factoid_key);

ALTER TABLE ONLY botmail
    ADD CONSTRAINT botmail_pkey PRIMARY KEY (srcwho, dstwho);

ALTER TABLE ONLY connections
    ADD CONSTRAINT connections_pkey PRIMARY KEY (server, port, nick);

ALTER TABLE ONLY freshmeat
    ADD CONSTRAINT freshmeat_pkey PRIMARY KEY (projectname_short, latest_version);

ALTER TABLE ONLY news
    ADD CONSTRAINT news_pkey PRIMARY KEY (channel, id, "key");

ALTER TABLE ONLY onjoin
    ADD CONSTRAINT onjoin_pkey PRIMARY KEY (nick, channel);

ALTER TABLE ONLY rootwarn
    ADD CONSTRAINT rootwarn_pkey PRIMARY KEY (nick);

ALTER TABLE ONLY seen
    ADD CONSTRAINT seen_pkey PRIMARY KEY (nick, channel);

ALTER TABLE ONLY stats
    ADD CONSTRAINT stats_pkey PRIMARY KEY (nick, "type", channel);

ALTER TABLE ONLY uptime
    ADD CONSTRAINT uptime_pkey PRIMARY KEY (uptime);

ALTER TABLE ONLY karma
    ADD CONSTRAINT karma_pkey PRIMARY KEY (nick);
