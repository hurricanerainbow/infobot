CREATE TABLE freshmeat (
    projectname_short VARCHAR(64) NOT NULL,
    latest_version VARCHAR(32) DEFAULT 'none'::VARCHAR NOT NULL,
    license VARCHAR(32),
    url_homepage VARCHAR(128),
    desc_short VARCHAR(96) NOT NULL
) WITHOUT OIDS;

REVOKE ALL ON TABLE freshmeat FROM PUBLIC;

ALTER TABLE ONLY freshmeat
    ADD CONSTRAINT freshmeat_pkey PRIMARY KEY (projectname_short, latest_version);
