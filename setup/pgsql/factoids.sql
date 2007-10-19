CREATE TABLE factoids (
    factoid_key VARCHAR(64) NOT NULL,
    requested_by VARCHAR(80) DEFAULT 'nobody' NOT NULL,
    requested_time numeric(11) DEFAULT 0 NOT NULL,
    requested_count numeric(5) DEFAULT 0 NOT NULL,
    created_by VARCHAR(80),
    created_time numeric(11) DEFAULT 0 NOT NULL,
    modified_by VARCHAR(80),
    modified_time numeric(11) DEFAULT 0 NOT NULL,
    locked_by VARCHAR(80),
    locked_time numeric(11) DEFAULT 0 NOT NULL,
    factoid_value text NOT NULL
) WITHOUT OIDS;

REVOKE ALL ON TABLE factoids FROM PUBLIC;

CREATE INDEX factoids_idx_fvalue ON factoids USING hash (factoid_value);

ALTER TABLE ONLY factoids
    ADD CONSTRAINT factoids_pkey_fkey PRIMARY KEY (factoid_key);
