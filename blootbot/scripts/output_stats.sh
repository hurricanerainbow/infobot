#!/bin/sh

cd src/
echo -n "DEBUG:  "; grep DEBUG `find -type f`| wc -l
echo -n "WARN:   "; grep WARN `find -type f` | wc -l
echo -n "FIXME:  "; grep FIXME `find -type f` | wc -l
echo -n "status: "; grep status `find -type f` | wc -l
echo -n "ERROR:  "; grep ERROR `find -type f` | wc -l
