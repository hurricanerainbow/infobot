#!/bin/sh

BOTDIR=/home/apt/bot
BOTNICK=blootbot
PIDFILE=$BOTDIR/$BOTNICK.pid

if [ -f $PIDFILE ]; then	# exists.
    PID=`cat $PIDFILE`
    if [ -d /proc/$PID ]; then	# already running.
	exit 0
    fi

    # blootbot removes the pid file.
    echo "stale pid file; removing."
#    rm -f $PIDFILE
fi

cd $BOTDIR
./blootbot
