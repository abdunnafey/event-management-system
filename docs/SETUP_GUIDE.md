# Setup Guide (Windows)

Part A installs MySQL. Part B builds and tests the database (the required
project). Part C is the optional web interface. Do them in order.

**Which MySQL version?** The scripts need **MySQL 8.0.16 or newer** (that is
when MySQL started enforcing `CHECK` constraints). MySQL 8.0 reached end of
life in April 2026, so for a new install choose **MySQL 8.4 LTS** (Long-Term
Support). Everything in this project works the same on 8.0.16+, 8.4 and 9.x.

---

## Already set up on this laptop (October 2026)

MySQL was installed for you as a **portable (ZIP) install**, without a Windows
service, so no administrator rights were needed:

| Item | Value |
|---|---|
| Version | MySQL Community Server **8.4.11 LTS** |
| Program folder | `%LOCALAPPDATA%\Programs\MySQL\mysql-8.4.11-winx64` |
| Config file | `%LOCALAPPDATA%\Programs\MySQL\my.ini` |
| Data folder | `%LOCALAPPDATA%\Programs\MySQL\data` |
| Host / port | `127.0.0.1` / `3306` (only reachable from this laptop) |
| User / password | `root` / *empty password* |
| MySQL Workbench | **26.10**, Start menu → *MySQL* → *MySQL Workbench* |

Helper scripts in the `scripts/` folder (double-click them):

| Script | Does |
|---|---|
| `start_mysql.bat` | Starts MySQL. **Run it after every restart**, because there is no service |
| `stop_mysql.bat` | Stops MySQL cleanly |
| `reset_database.bat` | Runs `01_schema.sql` + `02_sample_data.sql` → fresh 8 / 12 / 29 data |

In **MySQL Workbench** create a connection with Hostname `127.0.0.1`, Port
`3306`, Username `root` and leave the password empty (just press OK when
asked). Then continue with **Part B** below. Part A3 (Services) does not
apply to this install; use `start_mysql.bat` instead.

*Optional — set a root password:* open a query tab and run
`ALTER USER 'root'@'localhost' IDENTIFIED BY 'YourNewPassword';`. After that, the
helper scripts need `-p` added and `web/.env` needs `DB_PASSWORD=YourNewPassword`.

The rest of Part A shows the normal installer route, for another computer.

---

## Part A — Install MySQL Server and MySQL Workbench

### A1. Install MySQL Server

1. Open https://dev.mysql.com/downloads/mysql/
2. Choose **MySQL Community Server 8.4 LTS**, operating system **Microsoft Windows**,
   and download the **MSI Installer** (64-bit). On the next page click
   *"No thanks, just start my download"* (no account needed).
3. Run the `.msi`. Choose **Typical** setup → Install.
   If it asks for the *Microsoft Visual C++ Redistributable*, install that first
   (it links you to Microsoft's download) and run the MySQL installer again.
4. At the end, leave **"Run MySQL Configurator"** ticked and click Finish.
5. In **MySQL Configurator**:
   - *Type and Networking*: Config type **Development Computer**, port **3306**. Next.
   - *Accounts and Roles*: type a **root password** twice. **Write it down** — you
     will need it in Workbench and in the web app's `.env` file.
   - *Windows Service*: keep **Configure MySQL Server as a Windows Service** and
     **Start the MySQL Server at System Startup** ticked. Service name `MySQL84`
     (or `MySQL80` on 8.0) — remember this name.
   - Leave the sample databases unticked. Click **Execute**, then **Finish**.

### A2. Install MySQL Workbench

1. Open https://dev.mysql.com/downloads/workbench/
2. Download **MySQL Workbench** (Windows MSI) and install with default options.

### A3. Check the server is running

Press the Windows key, type **Services**, open it, and find **MySQL84** (or
MySQL80). Status should be **Running**. If not: right-click → Start.

---

## Part B — Build and test the database in Workbench

### B1. Configure the connection

1. Open MySQL Workbench. On the home screen you normally see a tile
   **Local instance MySQL84** (or similar). Click it and enter your root password
   (tick *Save password in vault* to avoid retyping).
2. No tile? Click the **⊕** next to *MySQL Connections*:
   - Connection Name: `Local MySQL`
   - Hostname: `127.0.0.1`   Port: `3306`   Username: `root`
   - Click **Test Connection**, enter the password → *Successfully made the MySQL connection*. OK.
3. If Workbench shows *"Incompatible/nonstandard server version"* for 8.4 or
   9.x, click **Continue Anyway**. It works fine.

You now see the **SQL Editor**: Navigator on the left (*Schemas* tab), the query
area in the middle, and the **Output** panel at the bottom (green ✔ = success,
red ✖ = error with code and message).

### B2. Open and execute a script

Two ways to run SQL in Workbench:

| Button / shortcut | Runs |
|---|---|
| ⚡ (plain lightning) or **Ctrl+Shift+Enter** | The **whole file** (or the selected text) |
| ⚡ with cursor (I-beam) or **Ctrl+Enter** | Only the **one statement** where the cursor is |

To open one of the project files: **File → Open SQL Script…** → choose the file.
(To write your own instead: **File → New Query Tab**, type, and save with Ctrl+S
as a `.sql` file.)

### B3. Run the scripts in this exact order

**Step 1 – `sql/01_schema.sql`** → Execute all (Ctrl+Shift+Enter)

- Output panel: about 15 green rows, no red.
- Result tabs at the bottom: `SHOW FULL TABLES` shows `events`, `participants`,
  `registrations` (BASE TABLE) and `vw_event_seat_summary` (VIEW).
  `SHOW TRIGGERS` lists 3 triggers.
- In the Navigator, right-click in the *Schemas* list → **Refresh All**. You will
  see `event_management_db`. **Double-click it** so it becomes bold — that makes
  it the default database for any new query tab.

> Why `DELIMITER $$`? A trigger body contains several `;`. `DELIMITER $$` tells
> Workbench "the statement ends at `$$` now", so the whole trigger is sent as one
> statement. `DELIMITER ;` switches back. This is why you must run file 01 with
> **Execute all**, not by selecting half a trigger.

**Step 2 – `sql/02_sample_data.sql`** → Execute all

- The result tab with columns `total_events | total_participants | total_registrations`
  shows `8 | 12 | 29`. The next three tabs show the full contents of each table.

**Step 3 – `sql/03_reports_queries.sql`** → run **one query at a time**

Click inside a query (for example Q4) and press **Ctrl+Enter**. Compare the
result grid with the comment block below the query. Counts and names must
match exactly; dates will differ from the comments because the sample data uses
dates relative to *today*.

**Step 4 – `sql/04_crud_operations.sql`** → Execute all

Click through the result tabs to see the new event/participant being created,
searched, updated, registered, cancelled and finally deleted. The final tab
shows `8 | 12 | 29` again, proving the clean-up worked.

**Step 5 – `sql/05_constraint_tests.sql`** → one statement at a time (Ctrl+Enter)

Every statement here is **supposed to fail**. Each red error in the Output panel
should match the "Expected" comment. This is your proof of data integrity for
the demo. At the end, run the final `SELECT` → still `8 | 12 | 29`.

### B4. Look at table contents

- Navigator → expand `event_management_db` → *Tables* → hover over `events` →
  click the small **grid icon** on the right. Workbench runs
  `SELECT * FROM events LIMIT 1000` and shows all rows.
- Or type in a query tab: `SELECT * FROM registrations;` → Ctrl+Enter.
- Structure of a table: `DESCRIBE events;`
- The view works like a table: `SELECT * FROM vw_event_seat_summary;`

### B5. Reset the database for a fresh demo

Run `01_schema.sql` (Execute all) and then `02_sample_data.sql` (Execute all).
File 01 starts with `DROP DATABASE IF EXISTS event_management_db`, so all old
data, including anything you added through the web app, is deleted and the
sample data is loaded again with ids starting from 1.

### B6. Common errors and how to fix them

| Error | Meaning | Fix |
|---|---|---|
| **1046** No database selected | Query tab doesn't know which DB to use | Run `USE event_management_db;` or double-click the schema in the Navigator |
| **1146** Table '...registrations' doesn't exist | Ran a later file before 01 | Run `01_schema.sql` first |
| **1064** You have an error in your SQL syntax ... near '...' | Typo: missing comma, quote, bracket; or a reserved word | Look at the text right after *near* — the mistake is just before it. For triggers: make sure the `DELIMITER $$` lines were executed too (Execute all) |
| **1062** Duplicate entry 'x' for key '...' | UNIQUE / PRIMARY KEY violated | Use a different email, or the participant is already registered for that event |
| **1452** Cannot add or update a child row: a foreign key constraint fails | `participant_id` or `event_id` does not exist in the parent table | `SELECT * FROM participants;` and use an id that exists. Insert parents before children |
| **1451** Cannot delete or update a parent row | Trying to delete an event/participant that still has registrations | Delete those registrations first, or set the event status to `Cancelled` instead |
| **1292** Incorrect date value | Date doesn't exist or wrong format | Use `'YYYY-MM-DD'`, e.g. `'2027-02-28'`, never `'28-02-2027'` |
| **3819** Check constraint '...' is violated | Value breaks a CHECK rule | Capacity > 0; status one of the allowed words; phone 10 digits; email has @ and a dot |
| **1644** Registration failed: ... | One of our triggers rejected it (event full / cancelled / completed) | Expected behaviour. Choose another event |
| **1364** Field 'x' doesn't have a default value | A NOT NULL column was left out | Include that column in the INSERT |
| **1175** You are using safe update mode | Workbench blocks UPDATE/DELETE without a key in WHERE | Add `WHERE <primary key> = ...`, or run `SET SQL_SAFE_UPDATES = 0;` for that session |
| **2003** Can't connect to MySQL server on '127.0.0.1:3306' | Server not running | Services → MySQL84 → Start |
| **1045** Access denied for user 'root'@'localhost' | Wrong password | Re-enter it; in Workbench right-click the tile → Edit Connection → Clear / Store in vault |

### B7. Verification checklist (do this before your review)

- [ ] `SHOW FULL TABLES;` → 3 tables + 1 view
- [ ] `SHOW TRIGGERS;` → 3 triggers
- [ ] Counts after file 02: 8 events, 12 participants, 29 registrations
- [ ] Q4 in file 03: TechFest Cultural Night = 7, Robotics and IoT Expo = 0
- [ ] Q8: Competitive Coding Contest shows 0 available seats
- [ ] File 05 TEST 4 fails with *the event is full*
- [ ] File 05 TEST 3 fails with *Duplicate entry '1-8'*
- [ ] File 05 TEST 9 fails with error 1451

If all boxes are ticked, the database project is complete and working.

---

## Part C — Optional Flask web interface

Requirements: Python 3.10 or newer (`python --version` in PowerShell) and the
database from Part B already created and loaded.

### C1. Open the project in VS Code

File → Open Folder → choose the `event-management-system` folder.
Open a terminal: **Terminal → New Terminal** (it is PowerShell by default).

### C2. Create a virtual environment and install packages

```powershell
cd web
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

Your prompt now starts with `(.venv)`.

> If you get *"running scripts is disabled on this system"*, either run
> `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` once and try again, or
> skip activation and prefix every command with `.\.venv\Scripts\python.exe -m`,
> e.g. `.\.venv\Scripts\python.exe -m pip install -r requirements.txt`.

```powershell
pip install -r requirements.txt
```

This installs **Flask** (web framework), **mysql-connector-python** (lets Python
talk to MySQL) and **python-dotenv** (reads the `.env` file).

### C3. Put the database password in an environment file

```powershell
Copy-Item .env.example .env
notepad .env
```

Change `DB_PASSWORD=your_mysql_root_password` to your real root password and
`FLASK_SECRET_KEY` to any long random text. Save and close.
The password is **not** written in the code; `db.py` reads it from the
environment. `.env` is listed in `.gitignore` so it is never uploaded.

### C4. Run

```powershell
python app.py
```

You should see `Running on http://127.0.0.1:5000`. Open that address in a
browser. Stop the server with **Ctrl+C**.

### C5. Test the web app (demo script)

1. **Dashboard** shows 8 events, 5 upcoming, 12 participants, 27 active registrations.
2. **Events → + Add event**: leave capacity empty → red validation message.
   Fill everything correctly → "Event created successfully."
3. **Events** search box: type `Seminar` → 3 events. Pick a date in the date box → only that day.
4. **Participants → + Add participant** with email `aarav.sharma@example.com`
   → "A participant with this email already exists."
5. **Register**: choose any participant and *Competitive Coding Contest (FULL)*
   → "Registration failed: the event is full (no seats available)."
6. Register Aarav Sharma for *TechFest Cultural Night* → "already registered".
7. Open *TechFest Cultural Night* → **Delete** → refused because it has registrations.
8. On an event page change a registration to *Cancelled* → seats available goes up by 1.
9. **Summary** page shows per-event counts, most popular event, empty events,
   and participants in more than one event.

Reset all data afterwards with Part B5.

### C6. Web app troubleshooting

| Problem | Fix |
|---|---|
| `ModuleNotFoundError: No module named 'flask'` | The virtual environment isn't active. Run `.\.venv\Scripts\Activate.ps1` again, then `pip install -r requirements.txt` |
| Page says *Cannot talk to the database* / 1045 Access denied | Wrong `DB_PASSWORD` in `web/.env` |
| *Cannot talk to the database* / 2003 | MySQL service stopped (Part A3) |
| 1049 Unknown database 'event_management_db' | Run `01_schema.sql` and `02_sample_data.sql` |
| `Address already in use` | Another `python app.py` is still running; close that terminal or press Ctrl+C there |
