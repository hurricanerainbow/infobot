CREATE TABLE uptime (
    uptime numeric DEFAULT 0,
    endtime numeric DEFAULT 0,
    string VARCHAR(128) NOT NULL
) WITHOUT OIDS;

REVOKE ALL ON TABLE uptime FROM PUBLIC;

ALTER TABLE ONLY uptime
    ADD CONSTRAINT uptime_pkey PRIMARY KEY (uptime);
