Method of installation.
-----------------------

- Debian: (apt-get install postgresql)
- Debian: (apt-get install libpg-perl)


As of now, blootbot has full pgsql support. It seems to be working 100%, but it
assumes that you have precreated the database and user for now. As long as you
already created the database and user and stored this info in the blootbot.config,
then the tables will automatically be created on startup. Until I get setup.pl
fixed, run the following commands as root (or postgres if root doesnt have
permission to create users/db's):

> createuser --no-adduser --no-createdb --pwprompt --encrypted <user>
> createdb --owner=<user> <dbname> [<description>]

Dont forget to replace <user> and so forth with actual values you intend to use,
and dont include the <>'s ;) If you run these commands, you should get a user
with an encrypted password that cannot create new db's or user's (as it should be!),
and the user will own the newly created database <dbname>. Congrats!

If everything went fine, you should have everything blootbot needs to use pgsql.
Next simply cd to the base directory you installed the bot to and type:

./blootbot


Thats it! Everything the bot needs should be automatically created when it loads
for the first time.

In the future I will try to get around to editing the setup.pl file to ask the
same questions it does for mysql (your root password etc) so that you can skip
manually creating the database/user. But for now, this should be just fine for
most of you techies out there.


----
troubled@freenode
