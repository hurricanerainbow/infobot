#!/bin/sh
echo -n "DEBUG:  "; grep DEBUG `find blootbot src -type f`| wc -l
echo -n "WARN:   "; grep WARN `find blootbot src -type f` | wc -l
echo -n "FIXME:  "; grep FIXME `find blootbot src -type f` | wc -l
echo -n "status: "; grep status `find blootbot src -type f` | wc -l
echo -n "ERROR:  "; grep ERROR `find blootbot src -type f` | wc -l
echo -n "TODO:   "; grep TODO `find blootbot src -type f` | wc -l
