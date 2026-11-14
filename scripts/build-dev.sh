#!/bin/sh
# Dev build without NetBeans (Git Bash): compile src/java into build/web, copy web/, reload Tomcat.
# Usage: sh scripts/build-dev.sh [--no-reload]. Wait about 15 s after a reload before testing (CLAUDE.md).
set -e
cd "$(dirname "$0")/.."
JAVAC="${JAVAC:-C:/Program Files/Java/jdk1.8.0_202/bin/javac}"
TOMCAT="${TOMCAT:-E:/apache-tomcat-9.0.113}"
CP="$TOMCAT/lib/servlet-api.jar;$TOMCAT/lib/jsp-api.jar;$TOMCAT/lib/el-api.jar;web/WEB-INF/lib/*"
mkdir -p build/web/WEB-INF/classes
find src/java -name '*.java' > build/sources.txt
"$JAVAC" -nowarn -encoding UTF-8 -source 8 -target 8 -cp "$CP" -d build/web/WEB-INF/classes @build/sources.txt
# resources next to the classes (the Weka model, the arff header)
(cd src/java && find . -type f ! -name '*.java' -exec cp --parents {} ../../build/web/WEB-INF/classes/ \;)
# -u: only newer files; copying an unchanged web.xml made Tomcat reload the app and sign every user out.
# The runtime jars come along from web/WEB-INF/lib (TestNG, JCommander and SLF4J stay in lib/, tests only).
cp -ru web/. build/web/
if [ "$1" != "--no-reload" ]; then
  touch "$TOMCAT/conf/Catalina/localhost/SmartLocker.xml"
  echo "Built; Tomcat reloads SmartLocker (wait about 15 s)."
else
  echo "Built."
fi
