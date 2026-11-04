#!/bin/sh
# Compile and run the TestNG tests (Git Bash). The *DatabaseIntegrationTest classes need SQL Server running.
# Usage: DB_URL='jdbc:sqlserver://localhost:1433;databaseName=SL_X;encrypt=false' sh scripts/test.sh [test.PricingTest,...]
# (default: every class in test/test). The tests write to the database, so only an SL_* database is accepted.
set -e
DB_NAME=$(printf '%s' "$DB_URL" | sed -n 's/.*;databaseName=\([^;]*\).*/\1/p')
case "$DB_URL:$DB_NAME" in
  *PRJ301_LOCKER*) DB_NAME= ;;
esac
case "$DB_NAME" in
  SL_*) ;;
  *) echo "DB_URL must name an SL_* database (see scripts/proof/README.md); got: '$DB_URL'" >&2; exit 2 ;;
esac
cd "$(dirname "$0")/.."
JDK="${JDK:-C:/Program Files/Java/jdk1.8.0_202/bin}"
TOMCAT="${TOMCAT:-E:/apache-tomcat-9.0.113}"
CP="$TOMCAT/lib/servlet-api.jar;$TOMCAT/lib/jsp-api.jar;lib/*"
mkdir -p build/classes build/test-classes
find src/java -name '*.java' > build/sources.txt
"$JDK/javac" -nowarn -encoding UTF-8 -source 8 -target 8 -cp "$CP" -d build/classes @build/sources.txt
(cd src/java && find . -type f ! -name '*.java' -exec cp --parents {} ../../build/classes/ \;)
"$JDK/javac" -nowarn -encoding UTF-8 -source 8 -target 8 -cp "build/classes;$CP" -d build/test-classes test/support/*.java test/test/*.java
CLASSES="${1:-$(cd test && ls test/*.java | sed 's#/#.#; s#\.java$##' | paste -sd, -)}"
"$JDK/java" -Dfile.encoding=UTF-8 -cp "build/test-classes;build/classes;$CP" org.testng.TestNG -usedefaultlisteners false -listener support.FailurePrinter -testclass "$CLASSES"
