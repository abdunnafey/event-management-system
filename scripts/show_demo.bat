@echo off
REM Shows the demo queries, then leaves you at the mysql> prompt to type your own SQL.
REM Type  exit  to leave the mysql> prompt.
set MYSQL="%LOCALAPPDATA%\Programs\MySQL\mysql-8.4.11-winx64\bin\mysql.exe" -uroot --host=127.0.0.1
cd /d "%~dp0"
%MYSQL% --table -vvv < demo_queries.sql
echo.
echo ===== You are now in MySQL. Type a query ending with ; and press Enter. Type exit to quit. =====
%MYSQL% event_management_db
