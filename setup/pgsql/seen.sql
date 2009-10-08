CREATE TABLE seen (
   nick character varying(20) NOT NULL, 
   "time" numeric NOT NULL, 
   channel character varying(30) NOT NULL, 
   host character varying(80) NOT NULL, 
   message text NOT NULL, 
   CONSTRAINT seen_pkey PRIMARY KEY (nick)
) WITHOUT OIDS;
