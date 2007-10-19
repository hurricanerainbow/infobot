CREATE TABLE news (
    channel VARCHAR(16) NOT NULL,
    id numeric DEFAULT 0 NOT NULL,
    "key" VARCHAR(16) NOT NULL,
    value text NOT NULL
) WITHOUT OIDS;

REVOKE ALL ON TABLE news FROM PUBLIC;

ALTER TABLE ONLY news
    ADD CONSTRAINT news_pkey PRIMARY KEY (channel, id, "key");
