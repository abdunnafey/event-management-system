# Viva Questions and Answers

Short answers you can say in one or two breaths. Where useful, the answer
points to the exact place in *this* project — examiners like that.

---

### Basics

**1. What is a DBMS?**
Software that stores, manages and retrieves data safely for many users, e.g.
MySQL, Oracle, PostgreSQL. It handles storage, security, backup and
concurrent access so applications don't have to.

**2. What is an RDBMS?**
A DBMS that stores data in **tables (relations)** of rows and columns and links
tables using **keys**. MySQL is an RDBMS. My project has three related tables.

**3. What is MySQL?**
A free, open-source RDBMS from Oracle. It uses SQL. I used MySQL 8.4 with the
InnoDB storage engine, which supports transactions, foreign keys and row locks.

**4. What is SQL?**
Structured Query Language — the standard language to talk to a relational
database. Parts: **DDL** (CREATE, ALTER, DROP), **DML** (INSERT, UPDATE, DELETE),
**DQL** (SELECT), **DCL** (GRANT, REVOKE), **TCL** (COMMIT, ROLLBACK).

**5. DBMS vs file system / spreadsheet?**
DBMS avoids duplicate data, enforces rules (constraints), allows many users at
once, and answers complex questions with queries. A spreadsheet does none of
these reliably.

### Keys and integrity

**6. What is a primary key?**
A column that uniquely identifies each row. It must be **unique and NOT NULL**.
Here: `event_id`, `participant_id`, `registration_id`.

**7. What is a foreign key?**
A column in one table that refers to the primary key of another table.
`registrations.participant_id` → `participants.participant_id` and
`registrations.event_id` → `events.event_id`.

**8. What is referential integrity?**
The rule that a foreign key must always point to a row that actually exists.
I can't register participant 999 if there is no participant 999 (error 1452),
and I can't delete an event that still has registrations (error 1451, because of
`ON DELETE RESTRICT`).

**9. Primary key vs unique key?**
Both prevent duplicates. A table has only **one** primary key and it can't be
NULL; it can have **many** unique keys. `email` is a unique key in participants.

**10. What is a composite key?**
A key made of two or more columns. `UNIQUE (participant_id, event_id)` is a
composite unique key in registrations.

**11. What is a candidate key / surrogate key?**
Candidate key: any column set that could be the primary key (e.g. `email`).
Surrogate key: an artificial number with no business meaning, like
`participant_id` (AUTO_INCREMENT).

**12. What constraints did you use?**
PRIMARY KEY, FOREIGN KEY, UNIQUE, NOT NULL, CHECK, DEFAULT.
Example CHECKs: `capacity > 0`, status in a fixed list, phone = 10 digits.

### Normalization

**13. What is normalization?**
Organising tables to remove duplicate data and avoid insert, update and delete
anomalies, by splitting a big table into smaller related ones.

**14. What is 1NF?**
Every cell holds a single (atomic) value; no lists or repeating groups.
So "events: Workshop, Hackathon" in one cell is not allowed.

**15. What is 2NF?**
1NF + no **partial dependency**: every non-key column depends on the *whole*
primary key, not part of it. Participant name depends only on the participant,
so it moved out of the registration table.

**16. What is 3NF?**
2NF + no **transitive dependency**: non-key columns depend only on the key, not
on other non-key columns. My three tables are in 3NF.

**17. What are anomalies?**
- *Insertion*: can't add an event until someone registers.
- *Update*: venue changed in one row but not in others.
- *Deletion*: deleting the last registration loses the event details.
Normalization removes all three.

**18. Why don't you store "available seats" in a column?**
It is derived data; it would go out of date. I calculate it in the view
`vw_event_seat_summary`.

### Queries

**19. What is a JOIN?**
Combines rows from two or more tables using a related column.
`registrations JOIN participants ON participant_id` gives the names of the
people registered for an event.

**20. Types of JOIN?**
- **INNER JOIN**: only matching rows.
- **LEFT JOIN**: all rows from the left table + matches (NULL if none). I use it
  to show events with 0 registrations.
- **RIGHT JOIN**: opposite of left.
- **FULL OUTER JOIN**: all rows from both (MySQL emulates it with UNION).
- **CROSS JOIN**: every combination. **SELF JOIN**: a table joined to itself.

**21. DELETE vs DROP vs TRUNCATE?**
| | DELETE | TRUNCATE | DROP |
|---|---|---|---|
| Removes | chosen rows (WHERE) | all rows | whole table (structure + data) |
| Type | DML | DDL | DDL |
| Rollback | yes (in a transaction) | no | no |
| Triggers fire | yes | no | no |
| Speed | slowest | fast | fast |

**22. WHERE vs HAVING?**
WHERE filters **rows before** grouping; HAVING filters **groups after** GROUP BY
and can use aggregates. In Q7: `WHERE status IN ('Confirmed','Attended')` then
`HAVING COUNT(*) > 1`.

**23. What are aggregate functions?**
Functions that turn many rows into one value: COUNT, SUM, AVG, MIN, MAX.
I use COUNT for participants per event and MAX for the most popular event.

**24. What is GROUP BY?**
Puts rows with the same value into groups so an aggregate is calculated per
group, e.g. count of registrations *per event*.

**25. What is a subquery?**
A query inside another query. My "most popular event" query compares each
event's count with `(SELECT MAX(cnt) FROM (...))`. `NOT EXISTS` finds events
with no registrations.

**26. What is a view?**
A saved SELECT that behaves like a virtual table. `vw_event_seat_summary` shows
seats taken and seats available for every event.

**27. What is a trigger?**
SQL code that runs automatically before or after INSERT, UPDATE or DELETE on a
table. My `BEFORE INSERT` trigger on registrations blocks a registration when
the event is full or cancelled.

### Project-specific

**28. Why is a separate Registration table required?**
Participants and events have a **many-to-many** relationship. A relational table
can't store a list in a column, so the junction table `registrations` stores one
row per participant–event pair, turning M:N into two 1:N relationships. It also
stores data that belongs to the link: registration date and status.

**29. How are duplicate registrations prevented?**
With a composite `UNIQUE (participant_id, event_id)` constraint. A second
registration for the same pair fails with error 1062. The database itself
blocks it, so it works from Workbench and from the web app.

**30. How are duplicate emails prevented?**
`UNIQUE (email)` on participants. The collation is case-insensitive, so
`Aarav@...` and `aarav@...` are treated as the same email.

**31. How is event capacity managed?**
A `BEFORE INSERT` trigger reads the event's capacity, counts the Confirmed and
Attended registrations, and if `count >= capacity` raises an error with
`SIGNAL SQLSTATE '45000'`. Cancelled registrations don't count, so cancelling
frees a seat. Another trigger stops capacity being reduced below seats booked.

**32. What if two students register for the last seat at the same time?**
The trigger reads the event row with `SELECT ... FOR UPDATE`, which locks that
row. The second registration waits until the first finishes, then counts again,
sees the event full and is rejected. So we never overbook.

**33. Why ON DELETE RESTRICT and not CASCADE?**
CASCADE would silently delete all registrations when an event is deleted — we
would lose history. RESTRICT forces the organiser to cancel the event instead
(set status to Cancelled), which keeps the records.

**34. Why is phone VARCHAR, not INT?**
We never do maths on phone numbers; they can start with 0 or contain +, and a
10-digit number can overflow INT. A CHECK with REGEXP ensures exactly 10 digits.

**35. What is AUTO_INCREMENT?**
MySQL automatically gives the next number (1, 2, 3, ...) to the primary key on
INSERT. `LAST_INSERT_ID()` returns the number just generated.

**36. What is a transaction? ACID?**
A group of statements that succeed or fail together.
**A**tomicity (all or nothing), **C**onsistency (rules always hold),
**I**solation (concurrent transactions don't disturb each other),
**D**urability (committed data survives crashes). InnoDB provides ACID.

**37. How does the web app prevent SQL injection?**
It uses **parameterized queries**: `cursor.execute("... WHERE email = %s", (email,))`.
The value is sent separately from the SQL text, so user input is never
executed as SQL. The password is read from an environment variable (`.env`),
not written in the code.

**38. What is an index? Did you use one?**
A data structure that makes searching faster, like a book's index. Primary and
unique keys create indexes automatically; I also added `idx_events_date` for
searching events by date.

**39. What is CHECK constraint and from which MySQL version does it work?**
A rule each row must satisfy, e.g. `CHECK (capacity > 0)`. MySQL enforces
CHECK from **8.0.16**; earlier versions parsed it but ignored it.

**40. How do you reset the database?**
Run `01_schema.sql` (it begins with `DROP DATABASE IF EXISTS`) and then
`02_sample_data.sql`.
