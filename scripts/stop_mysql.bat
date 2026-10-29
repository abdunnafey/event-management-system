@echo off
REM Shuts the MySQL server down cleanly.
"%LOCALAPPDATA%\Programs\MySQL\mysql-8.4.11-winx64\bin\mysqladmin.exe" -uroot --host=127.0.0.1 shutdown
echo MySQL stopped.
