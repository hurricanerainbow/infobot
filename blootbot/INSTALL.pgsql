Method of installation.
-----------------------

- Debian: (apt-get install postgresql)
- Debian: (apt-get install libpgperl)

---
OLD: SUPPORT FOR PGSQL IS CURRENTLY BROKEN! You'll have to use one of the other
databases instead.
---

Actually, I have implemented pgsql support. It works just fine, but it assumes
that you have precreated the tables for now. To help with this, I have
included a sql file under setup/pgsql/pgsql-schema.sql. Simply psql <dbname>
and the type:

dbname#=> BEGIN;
dbname#=> \i path/to/setup/pgsql/pgsql-schema.sql
.......
dbname#=> COMMIT;

If everything went fine, you should have working Pgsql tables needed for blootbot.
Type "\d" to check if they were created.

In the future I will try to get things working a little smoother. But for now
this should be considered "near production" quality. :)

TODO: 
-----
  - Auto create tables if they dont exist
  - Modify setup.pl to do pgsql work
  - Pgsql db conversions?



----
troubled@freenode
