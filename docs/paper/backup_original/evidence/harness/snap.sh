#!/bin/sh
# Evidence: dump what the server stored since $1 (DB UTC, ISO 8601). sqlcmd -v rejects ':' in values, so the date is substituted with sed.
H=docs/paper/evidence/harness
sed "s/\$(since)/$1/" $H/snapshot.sql > $H/snapshot.tmp.sql
echo "# command: sed \"s/\$(since)/$1/\" $H/snapshot.sql > $H/snapshot.tmp.sql; sqlcmd -S localhost -U sa -P *** -d PRJ301_LOCKER -I -W -i <that file>"
sqlcmd -S localhost -U sa -P 12345 -d PRJ301_LOCKER -I -W -i "$(cygpath -w "$PWD/$H/snapshot.tmp.sql")" 2>&1
