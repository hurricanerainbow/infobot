#
# db_mysql.pl: {my,pg}SQL database frontend.
#      Author: dms
#     Version: v0.1 (20010908)
#     Created: 20010908
#

package main;

if (&IsParam("useStrict")) { use strict; }

sub SQLDebug {
    return unless (&IsParam("SQLDebug"));

    return unless (fileno SQLDEBUG);

    print SQLDEBUG $_[0]."\n";
}

1;
