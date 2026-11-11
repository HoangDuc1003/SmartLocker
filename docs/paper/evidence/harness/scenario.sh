#!/bin/sh
# Evidence: run one ScenarioSender scenario and dump what the server stored since just before it.
# Usage (repo root, Git Bash): sh docs/paper/evidence/harness/scenario.sh <scenario>  >> docs/paper/evidence/scenarios.log
H=docs/paper/evidence/harness
JDK="C:/Program Files/Java/jdk1.8.0_202/bin"
DB="sqlcmd -S localhost -U sa -P 12345 -d PRJ301_LOCKER -I -W"
SINCE=$($DB -h -1 -Q "SET NOCOUNT ON; SELECT CONVERT(VARCHAR(23), DATEADD(MILLISECOND, -500, SYSUTCDATETIME()), 126)" | tr -d '\r' | head -1)
echo "################ scenario $1 - start (DB UTC) $SINCE"
echo "# command: \"$JDK/java\" -cp \"$H/classes;build/classes;lib/*\" tool.ScenarioSender $1"
"$JDK/java" -Dfile.encoding=UTF-8 -cp "$H/classes;build/classes;lib/*" tool.ScenarioSender "$1" 2>&1
echo "# exit=$?  waiting ${WAIT:-3} s for the server"
sleep "${WAIT:-3}"
sh $H/snap.sh "$SINCE"
