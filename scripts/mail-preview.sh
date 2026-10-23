#!/bin/sh
# Preview (and optionally send) a mail template with sample data. Needs a build first: sh scripts/build-dev.sh
# Usage: sh scripts/mail-preview.sh list
#        sh scripts/mail-preview.sh due_soon [address]     (an address sends the sample for real)
set -e
cd "$(dirname "$0")/.."
JAVA="${JAVA:-C:/Program Files/Java/jdk1.8.0_202/bin/java}"
TOMCAT="${TOMCAT:-E:/apache-tomcat-9.0.113}"
"$JAVA" -Dfile.encoding=UTF-8 -Dsmartlocker.mailConfig=config/mail.local.properties \
  -cp "build/web/WEB-INF/classes;$TOMCAT/lib/servlet-api.jar" service.MailTemplates "$@"
