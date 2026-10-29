@echo off
REM Starts the MySQL 8.4 server that was installed in your user folder.
REM It is NOT a Windows service, so run this once after every restart.
set MYSQL_HOME=%LOCALAPPDATA%\Programs\MySQL
set MYSQL_BIN=%MYSQL_HOME%\mysql-8.4.11-winx64\bin

"%MYSQL_BIN%\mysqladmin.exe" -uroot --host=127.0.0.1 ping >nul 2>&1
if %errorlevel%==0 (
    echo MySQL is already running.
    goto :eof
)

start "" /B "%MYSQL_BIN%\mysqld.exe" --defaults-file="%MYSQL_HOME%\my.ini"
echo Starting MySQL...
timeout /t 5 /nobreak >nul
"%MYSQL_BIN%\mysqladmin.exe" -uroot --host=127.0.0.1 ping
