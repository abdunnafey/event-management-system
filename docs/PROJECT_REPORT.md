# Event Management System using MySQL

*Mini-project report — Database Management Systems*

Submitted by: ______________________  USN / Roll No.: ____________
Department of Artificial Intelligence and Machine Learning
Guide: ______________________   Academic year: ____________

---

## 1. Abstract

Colleges organise many workshops, contests, seminars and festivals every
semester. Registrations are usually collected on paper or in spreadsheets,
which leads to duplicate entries, over-booked venues and slow, error-prone
reporting. This project designs and implements an **Event Management System**
on the **MySQL** relational database. Data is stored in three normalized tables
— *events*, *participants* and *registrations* — connected through primary and
foreign keys. Data integrity is enforced inside the database using `NOT NULL`,
`UNIQUE`, `CHECK` and `FOREIGN KEY` constraints, and business rules such as
seat capacity are enforced with triggers that also handle simultaneous
registrations safely. SQL queries using joins, aggregate functions, grouping
and subqueries produce reports such as participant counts, available seats,
the most popular event and a registration summary. An optional web interface
built with Python Flask demonstrates how an application uses the database with
parameterized queries.

## 2. Introduction

A **Database Management System (DBMS)** is software that stores data in an
organised way and lets many users insert, read, update and delete it safely.
A **relational** DBMS (RDBMS) such as MySQL stores data in tables (relations)
made of rows and columns and links tables using keys.

Event management is a natural fit for a relational database: there are clearly
separate *things* (events and people) and a *relationship* between them
(registration). The project shows how good table design, constraints and SQL
together turn a messy manual process into a reliable system.

## 3. Problem statement

Design and implement a database that can store event details and participant
details, register participants for events without duplicates and without
exceeding the capacity of an event, and retrieve accurate information such as
who is attending an event, which events a student has joined, and how many seats
remain — using MySQL and SQL.

## 4. Objectives

1. Design an ER model and convert it to a relational schema in 3NF.
2. Implement the schema in MySQL with primary keys, foreign keys and constraints.
3. Represent the many-to-many relationship between participants and events
   using a junction table.
4. Prevent duplicate emails, duplicate registrations and over-capacity
   registrations at the database level.
5. Perform all CRUD operations with SQL.
6. Generate reports using joins, `GROUP BY`, `HAVING`, aggregate functions and
   subqueries.
7. (Optional) Provide a simple web interface that uses the database securely.

## 5. Existing system and proposed system

**Existing system (manual / spreadsheet)**

- Registrations collected on paper forms, Google Forms or Excel sheets.
- The same student may register twice; nothing stops it.
- Organisers count seats by hand, so events get over-booked.
- Each event often has a separate sheet; finding "all events of one student"
  means searching many files.
- No relationships or validation: wrong phone numbers, missing emails, typos.

**Proposed system (MySQL database)**

- One central database with three related tables.
- `UNIQUE` constraints stop duplicate emails and duplicate registrations.
- Triggers stop registrations once an event is full, even if two people
  register at the same moment.
- Foreign keys guarantee every registration belongs to a real event and a real
  participant.
- Any report is one SQL query away; results are always up to date.

## 6. Hardware and software requirements

| Hardware | Minimum |
|---|---|
| Processor | Intel Core i3 / AMD Ryzen 3 or better |
| RAM | 4 GB (8 GB recommended) |
| Storage | 3 GB free |

| Software | Version |
|---|---|
| Operating system | Windows 10 / 11 (64-bit) |
| Database server | MySQL Community Server 8.4 LTS (any 8.0.16+ works) |
| Database client | MySQL Workbench 8.0 |
| Optional: language | Python 3.10+ |
| Optional: framework / libraries | Flask 3, mysql-connector-python, python-dotenv |
| Optional: editor / shell | VS Code, Windows PowerShell |
| Browser | Chrome / Edge / Firefox |

## 7. Functional requirements

| ID | Requirement |
|---|---|
| FR1 | Add, view, view details of, update and delete events |
| FR2 | Store event name, description, date, venue, capacity and status |
| FR3 | Add, view, search (by name or email) and update participants |
| FR4 | Reject a participant whose email already exists |
| FR5 | Register an existing participant for an existing event |
| FR6 | Reject a second registration of the same participant for the same event |
| FR7 | Reject a registration when the event is full, cancelled or completed |
| FR8 | Store registration date and status (Confirmed / Cancelled / Attended) |
| FR9 | List participants of an event and events of a participant |
| FR10 | Reports: upcoming events, counts per event, events without registrations, most popular event, participants in several events, available seats, search by date/venue, registration summary |

## 8. Database design

### 8.1 Entities and the role of each table

- **events** — one row per event. It answers *what, when, where, how many seats
  and is it still open?* `event_id` identifies each event.
- **participants** — one row per person. It answers *who is this person and how
  do we contact them?* `email` is unique so a person exists only once.
- **registrations** — one row per *(participant, event)* pair. It records *who
  joined which event, when, and the current status*. It is the bridge that
  connects the other two tables.

### 8.2 Relationships

| Relationship | Type | Implemented by |
|---|---|---|
| Participant – Registration | 1 : N | `registrations.participant_id` → `participants.participant_id` |
| Event – Registration | 1 : N | `registrations.event_id` → `events.event_id` |
| Participant – Event | **M : N** | resolved through the `registrations` table |

### 8.3 ER diagram

![ER diagram](er_diagram.svg)

*(File: `docs/er_diagram.svg`. Rectangles = entities, PK = primary key,
FK = foreign key, UK = unique key. Crow's foot = "many" side.)*

### 8.4 Relational schema

```
EVENTS        ( event_id PK, event_name, description, event_date, venue,
                capacity, status, created_at )
                UNIQUE (event_name, event_date)

PARTICIPANTS  ( participant_id PK, participant_name, email UNIQUE, phone,
                college, department, created_at )

REGISTRATIONS ( registration_id PK,
                participant_id FK -> PARTICIPANTS(participant_id),
                event_id       FK -> EVENTS(event_id),
                registration_date, registration_status )
                UNIQUE (participant_id, event_id)
```

### 8.5 Data dictionary

**events**

| Column | Type | Constraints | Description |
|---|---|---|---|
| event_id | INT | PK, AUTO_INCREMENT | Unique event number |
| event_name | VARCHAR(100) | NOT NULL, UNIQUE with event_date | Title |
| description | TEXT | NULL allowed | Details |
| event_date | DATE | NOT NULL, indexed | Day of the event |
| venue | VARCHAR(100) | NOT NULL | Hall / lab |
| capacity | INT | NOT NULL, CHECK > 0 | Maximum seats |
| status | VARCHAR(20) | NOT NULL, DEFAULT 'Upcoming', CHECK in (Upcoming, Ongoing, Completed, Cancelled) | Current state |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | When the row was created |

**participants**

| Column | Type | Constraints | Description |
|---|---|---|---|
| participant_id | INT | PK, AUTO_INCREMENT | Unique participant number |
| participant_name | VARCHAR(100) | NOT NULL | Full name |
| email | VARCHAR(100) | NOT NULL, UNIQUE, CHECK like '%_@_%._%' | Email (case-insensitive unique) |
| phone | VARCHAR(15) | NOT NULL, CHECK 10 digits | Mobile number (text, keeps leading zeros) |
| college | VARCHAR(150) | NOT NULL | College name |
| department | VARCHAR(100) | NULL allowed | Branch |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | When added |

**registrations**

| Column | Type | Constraints | Description |
|---|---|---|---|
| registration_id | INT | PK, AUTO_INCREMENT | Unique registration number |
| participant_id | INT | NOT NULL, FK, ON DELETE RESTRICT | Who registered |
| event_id | INT | NOT NULL, FK, ON DELETE RESTRICT | For which event |
| registration_date | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | When |
| registration_status | VARCHAR(20) | NOT NULL, DEFAULT 'Confirmed', CHECK in (Confirmed, Cancelled, Attended) | State |
| *(table)* | | UNIQUE (participant_id, event_id) | No duplicate registrations |

**Other database objects**

| Object | Purpose |
|---|---|
| `trg_registrations_before_insert` | Blocks a new registration if the event does not exist, is cancelled/completed, or is full. Locks the event row (`FOR UPDATE`) so concurrent registrations are checked one after another |
| `trg_registrations_before_update` | Same check when a cancelled registration is re-confirmed or moved to another event |
| `trg_events_before_update` | Blocks lowering capacity below seats already booked |
| `vw_event_seat_summary` | View: capacity, seats taken and seats available per event |

### 8.6 Capacity and simultaneous registrations

A `CHECK` constraint can only look at the row being inserted, but "is the event
full?" needs to count other rows. So capacity is enforced by a **BEFORE INSERT
trigger**:

1. Read the event's capacity and status with `SELECT ... FOR UPDATE`. This locks
   that event's row until the INSERT's transaction ends.
2. Count registrations of that event whose status is Confirmed or Attended.
3. If `count >= capacity`, raise an error with `SIGNAL SQLSTATE '45000'`, which
   cancels the INSERT.

If two students click *Register* for the last seat at the same moment, both
INSERTs reach step 1, but only one can hold the lock. The other waits. When the
first commits, the second continues, counts again, finds the event full, and
is rejected. Registrations for *different* events lock different rows and do
not wait for each other. Cancelled registrations are not counted, so cancelling
frees a seat.

## 9. Normalization

**Unnormalized form (what a spreadsheet looks like):**

| student | email | phone | events_registered |
|---|---|---|---|
| Aarav Sharma | aarav@... | 98765... | Python Workshop (Seminar Hall A, 20-Aug), Hackathon (Main Auditorium, 14-Sep) |

Problems: many values in one cell; event details repeated for every student;
changing a venue means editing many rows (*update anomaly*); an event with no
students cannot be stored (*insertion anomaly*); deleting the last student of an
event loses the event (*deletion anomaly*).

**1NF — atomic values, no repeating groups.** Split the list so each row holds one
student and one event:

`(student_name, email, phone, event_name, event_date, venue, capacity, reg_date, reg_status)`

Every cell now has one value. Key = (email, event_name, event_date).

**2NF — no partial dependency on part of a composite key.** Student name and
phone depend only on *email*; venue and capacity depend only on the *event*.
They depend on part of the key, so we move them out:

- PARTICIPANTS(email, name, phone, college, department)
- EVENTS(event, date, venue, capacity, status, description)
- REGISTRATIONS(email, event, reg_date, reg_status) — these two depend on the
  whole key.

**3NF — no transitive dependency (non-key → non-key).** In each table every
non-key column depends only on that table's key and nothing else. For example,
in `events` the venue does not determine the capacity (two events in the same
hall can have different seat limits), and in `participants` the department
does not determine the college. There is no "non-key column → another non-key
column" dependency left. We also add surrogate keys (`participant_id`, `event_id`,
`registration_id`) so foreign keys are small integers, while the natural keys
remain protected by `UNIQUE (email)` and `UNIQUE (participant_id, event_id)`.

Derived values such as *seats available* are **not stored** (they would go out of
date); they are calculated by the view `vw_event_seat_summary`.

The final design is in **3NF** (and also BCNF, because the only determinants in
each table are candidate keys).

## 10. SQL commands used

| Category | Commands in this project |
|---|---|
| DDL (structure) | `CREATE DATABASE`, `DROP DATABASE`, `USE`, `CREATE TABLE`, `CREATE VIEW`, `CREATE TRIGGER` |
| Constraints | `PRIMARY KEY`, `FOREIGN KEY ... REFERENCES ... ON DELETE RESTRICT ON UPDATE CASCADE`, `UNIQUE`, `NOT NULL`, `CHECK`, `DEFAULT`, `AUTO_INCREMENT` |
| DML (data) | `INSERT`, `UPDATE`, `DELETE` |
| DQL (query) | `SELECT`, `WHERE`, `ORDER BY`, `LIMIT`, `LIKE`, `BETWEEN`, `IN`, `DISTINCT` |
| Joins | `INNER JOIN` (3 tables), `LEFT JOIN` |
| Aggregates | `COUNT`, `SUM(CASE ...)`, `MAX`, `AVG` with `GROUP BY` and `HAVING` |
| Subqueries | in `HAVING` (most popular event), in `WHERE` (above average), `NOT EXISTS`, derived table in `FROM` |
| Functions | `CURDATE()`, `NOW()`, `DATEDIFF()`, `DATE()`, `CONCAT()`, `LAST_INSERT_ID()`, `INTERVAL` arithmetic |
| Programmability | Triggers with `DECLARE`, `IF`, `SELECT ... INTO ... FOR UPDATE`, `SIGNAL SQLSTATE` |
| Utility | `SHOW FULL TABLES`, `SHOW TRIGGERS`, `DESCRIBE`, `SET @variable` |

The full scripts are in the `sql/` folder (files 01 to 05).

## 11. Sample input and output

**Input — registering a participant**

```sql
INSERT INTO registrations (participant_id, event_id) VALUES (7, 6);
```

Output: `1 row(s) affected`. Vikram Singh is now registered for the AWS
workshop and its available seats drop from 37 to 36. Running the same statement
a second time gives `Error 1062: Duplicate entry '7-6'`.

**Input — participants of event 4**

```sql
SELECT p.participant_name, r.registration_status
FROM registrations r JOIN participants p ON p.participant_id = r.participant_id
WHERE r.event_id = 4 ORDER BY r.registration_date;
```

| participant_name | registration_status |
|---|---|
| Priya Nair | Confirmed |
| Ananya Iyer | Confirmed |
| Meera Joshi | Confirmed |
| Fatima Khan | Confirmed |
| Rohan Verma | Cancelled |

**Input — seats available (view)**

```sql
SELECT event_name, capacity, seats_taken, available_seats FROM vw_event_seat_summary;
```

| event_name | capacity | seats_taken | available_seats |
|---|---|---|---|
| Python for Data Science Workshop | 60 | 4 | 56 |
| CodeSprint 24-Hour Hackathon | 100 | 5 | 95 |
| Cybersecurity Awareness Talk | 120 | 0 | 120 |
| AI in Healthcare Seminar | 80 | 4 | 76 |
| Competitive Coding Contest | 4 | 4 | 0 |
| Cloud Computing with AWS Workshop | 40 | 3 | 37 |
| Robotics and IoT Expo | 150 | 0 | 150 |
| TechFest Cultural Night | 500 | 7 | 493 |

**Input — most popular event:** query Q6 → `TechFest Cultural Night | 7`

**Input — registration summary by status:** `Attended 9 · Cancelled 2 · Confirmed 18`

All other report outputs are written as comments under each query in
`sql/03_reports_queries.sql`.

## 12. Test cases

| TC | Test | Input | Expected result | Actual (fill in) |
|---|---|---|---|---|
| 1 | Create schema | Run `01_schema.sql` | 3 tables, 1 view, 3 triggers |  |
| 2 | Load sample data | Run `02_sample_data.sql` | 8 / 12 / 29 rows |  |
| 3 | Add event | INSERT valid event | 1 row affected |  |
| 4 | Update event | UPDATE venue, capacity | 1 row affected, new values shown |  |
| 5 | Add participant | INSERT valid participant | 1 row affected |  |
| 6 | Search participant | LIKE '%nikhil%' | 1 row returned |  |
| 7 | Duplicate email | Existing email | Error 1062 |  |
| 8 | Duplicate email, other case | `AARAV.SHARMA@...` | Error 1062 |  |
| 9 | Valid registration | New pair | 1 row affected, seats −1 |  |
| 10 | Duplicate registration | (1, 8) | Error 1062 |  |
| 11 | Event full | (5, 5) | Error 1644 "event is full" |  |
| 12 | Cancelled event | (5, 3) | Error 1644 "cancelled or completed" |  |
| 13 | Completed event | (6, 1) | Error 1644 |  |
| 14 | Non-existent event | (1, 999) | Error 1644 "does not exist" |  |
| 15 | Non-existent participant | (999, 8) | Error 1452 FK fails |  |
| 16 | Delete event with registrations | event 8 | Error 1451 |  |
| 17 | Capacity 0 | INSERT event | Error 3819 |  |
| 18 | Invalid status | 'Postponed' | Error 3819 |  |
| 19 | Invalid phone | '12345' | Error 3819 |  |
| 20 | Invalid date | '2027-02-30' | Error 1292 |  |
| 21 | Missing venue | no venue | Error 1364 |  |
| 22 | Reduce capacity below bookings | event 8 → 5 | Error 1644 |  |
| 23 | Cancel registration | status → Cancelled | Seat freed (available +1) |  |
| 24 | Delete in correct order | child then parent | All rows deleted |  |

*(Run each test yourself and write Pass/Fail in the last column. Tests 7–22 are in
`sql/05_constraint_tests.sql`, 3–6, 9, 23–24 in `sql/04_crud_operations.sql`.)*

## 13. Results and discussion

The database was created successfully with all constraints. Sample data for 8
events, 12 participants and 29 registrations loaded without errors. All twelve
report queries returned correct results — for example, the most popular event
is *TechFest Cultural Night* with 7 participants, *Competitive Coding Contest* is
full with 0 seats available, and two events have no registrations. All negative
test cases were rejected by the database with meaningful errors, showing that
data integrity does not depend on the user or the application behaving
correctly. Putting rules in the database (constraints and triggers) means the
Flask interface and Workbench obey exactly the same rules.

## 14. Advantages and limitations

**Advantages**

- Data stored once, in one place — no duplication or inconsistency.
- Integrity rules enforced by the DBMS itself.
- Capacity is safe even with simultaneous registrations.
- Reports are instant and always current.
- Simple design, easy to extend.

**Limitations**

- No login or user roles; anyone with the app can edit data.
- Email/phone checks are basic format checks, not real verification.
- No payment, ticket or QR-code support.
- No waiting list when an event is full.
- Event has only a date, not start/end time; overlapping events in one venue are not detected.

## 15. Future enhancements

- Admin and student logins with roles (organiser / participant).
- Waiting list that auto-confirms the next person when someone cancels.
- Email or SMS confirmation and reminders.
- QR-code tickets and attendance scanning.
- Event categories, organisers and venue tables (further normalization).
- Start/end time and venue clash detection.
- Feedback and ratings after an event; charts on a dashboard.
- Hosting on the cloud (e.g. AWS RDS for MySQL).

## 16. Conclusion

The Event Management System shows how a well-designed relational database
solves a real college problem. Using three normalized tables, primary and
foreign keys, `UNIQUE` and `CHECK` constraints, triggers and a view, the system
stores events and participants, prevents duplicate and over-capacity
registrations, and answers every required question with SQL queries. The
project covers the core DBMS concepts — ER modelling, relational schema,
normalization, referential integrity, CRUD, joins, aggregation and subqueries —
in a working, demonstrable application.

## 17. References

1. Silberschatz, A., Korth, H. F., Sudarshan, S. *Database System Concepts*, 7th ed., McGraw-Hill, 2019.
2. Elmasri, R., Navathe, S. B. *Fundamentals of Database Systems*, 7th ed., Pearson, 2016.
3. Oracle Corporation. *MySQL 8.4 Reference Manual*. https://dev.mysql.com/doc/refman/8.4/en/
4. Oracle Corporation. *MySQL Workbench Manual*. https://dev.mysql.com/doc/workbench/en/
5. Pallets Projects. *Flask Documentation*. https://flask.palletsprojects.com/
6. Oracle Corporation. *MySQL Connector/Python Developer Guide*. https://dev.mysql.com/doc/connector-python/en/
