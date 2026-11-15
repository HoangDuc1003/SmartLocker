@echo off
set "JAVA_HOME=C:\Program Files\Java\jdk1.8.0_202"
set "CATALINA_HOME=E:\apache-tomcat-9.0.113"
set "CATALINA_BASE=C:\sl-wt\tomcat-8081"
set "DB_URL=jdbc:sqlserver://localhost:1433;databaseName=SL_SIM;encrypt=false"
"%CATALINA_HOME%\bin\catalina.bat" run
