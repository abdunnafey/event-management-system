@echo off
REM Rebuilds event_management_db from scratch: runs 01_schema.sql then 02_sample_data.sql.
REM All data you added is deleted. Same as running the two files in Workbench.
set MYSQL="%LOCALAPPDATA%\Programs\MySQL\mysql-8.4.11-winx64\bin\mysql.exe" -uroot --host=127.0.0.1
cd /d "%~dp0..\sql"
%MYSQL% < 01_schema.sql >nul || goto :fail
%MYSQL% < 02_sample_data.sql >nul || goto :fail
%MYSQL% -e "SELECT (SELECT COUNT(*) FROM events) AS events, (SELECT COUNT(*) FROM participants) AS participants, (SELECT COUNT(*) FROM registrations) AS registrations" event_management_db
echo Database reset complete (expected 8 / 12 / 29).
goto :eof
:fail
echo Reset FAILED - is MySQL running? Try scripts\start_mysql.bat
