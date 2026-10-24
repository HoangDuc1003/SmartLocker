# Image for a hosted server such as Render (docs/deploy-render.md). Same steps as scripts/build-dev.sh.
FROM tomcat:9.0-jdk8-temurin AS build
WORKDIR /src
COPY lib lib
COPY src/java src/java
COPY web web
RUN mkdir -p out/WEB-INF/classes out/WEB-INF/lib \
 && find src/java -name '*.java' > sources.txt \
 && javac -nowarn -encoding UTF-8 -source 8 -target 8 \
      -cp "$CATALINA_HOME/lib/*:lib/*" -d out/WEB-INF/classes @sources.txt \
 && (cd src/java && find . -type f ! -name '*.java' -exec cp --parents {} /src/out/WEB-INF/classes/ \;) \
 && cp -r web/. out/ \
 && cp lib/gson-*.jar lib/jbcrypt-*.jar lib/mssql-jdbc-*.jar lib/weka.jar out/WEB-INF/lib/

FROM tomcat:9.0-jre8-temurin
RUN rm -rf "$CATALINA_HOME/webapps/"*
COPY --from=build /src/out "$CATALINA_HOME/webapps/SmartLocker"
# the bare address opens the app
RUN mkdir "$CATALINA_HOME/webapps/ROOT" \
 && printf '<%% response.sendRedirect("/SmartLocker/"); %%>' > "$CATALINA_HOME/webapps/ROOT/index.jsp"
# mail is optional: upload mail.local.properties as a Render secret file, the templates ship with the image
COPY config/mail-templates /opt/smartlocker/mail-templates
ENV JAVA_OPTS="-Xmx320m -XX:+UseSerialGC -Dfile.encoding=UTF-8 -Duser.timezone=Asia/Ho_Chi_Minh"
EXPOSE 8080
CMD if [ -f /etc/secrets/mail.local.properties ]; then \
      cp /etc/secrets/mail.local.properties /opt/smartlocker/ \
      && export JAVA_OPTS="$JAVA_OPTS -Dsmartlocker.mailConfig=/opt/smartlocker/mail.local.properties"; \
    fi; \
    exec catalina.sh run
