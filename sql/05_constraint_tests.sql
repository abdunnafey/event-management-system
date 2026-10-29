-- =====================================================================
-- EVENT MANAGEMENT SYSTEM
-- File 5 of 5 : 05_constraint_tests.sql
-- Purpose     : PROVE that the database rejects bad data
-- Run after   : 02_sample_data.sql
--
-- EVERY statement below is SUPPOSED TO FAIL. An error here means the
-- constraint is working.
--
-- HOW TO RUN: click inside ONE statement and press Ctrl+Enter.
-- Read the red error in the Output panel and compare it with the
-- "Expected" line. Then move to the next test.
-- (If you use Execute All, Workbench stops at the first error.)
--
-- None of these statements change any data, because they all fail.
-- =====================================================================

USE event_management_db;


-- TEST 1: Duplicate participant email  (UNIQUE constraint)
INSERT INTO participants (participant_name, email, phone, college)
VALUES ('Aarav S', 'aarav.sharma@example.com', '9000000001', 'City Institute of Technology');
-- Expected: Error Code: 1062. Duplicate entry 'aarav.sharma@example.com'
--           for key 'participants.uq_participants_email'


-- TEST 2: Same email in different letter case (still a duplicate)
INSERT INTO participants (participant_name, email, phone, college)
VALUES ('Aarav S', 'AARAV.SHARMA@example.com', '9000000001', 'City Institute of Technology');
-- Expected: Error Code: 1062. Duplicate entry ... for key 'participants.uq_participants_email'


-- TEST 3: Duplicate registration (participant 1 is already in event 8)
INSERT INTO registrations (participant_id, event_id) VALUES (1, 8);
-- Expected: Error Code: 1062. Duplicate entry '1-8'
--           for key 'registrations.uq_registrations_participant_event'


-- TEST 4: Event capacity exceeded (event 5 has 4 seats, all taken)
INSERT INTO registrations (participant_id, event_id) VALUES (5, 5);
-- Expected: Error Code: 1644. Registration failed: the event is full (no seats available).


-- TEST 5: Registering for a cancelled event (event 3)
INSERT INTO registrations (participant_id, event_id) VALUES (5, 3);
-- Expected: Error Code: 1644. Registration failed: the event is cancelled or already completed.


-- TEST 6: Registering for a completed event (event 1)
INSERT INTO registrations (participant_id, event_id) VALUES (6, 1);
-- Expected: Error Code: 1644. Registration failed: the event is cancelled or already completed.


-- TEST 7: Registering for an event that does not exist
INSERT INTO registrations (participant_id, event_id) VALUES (1, 999);
-- Expected: Error Code: 1644. Registration failed: the event does not exist.


-- TEST 8: Participant that does not exist  (FOREIGN KEY)
INSERT INTO registrations (participant_id, event_id) VALUES (999, 8);
-- Expected: Error Code: 1452. Cannot add or update a child row:
--           a foreign key constraint fails (... CONSTRAINT `fk_registrations_participant` ...)


-- TEST 9: Deleting an event that still has registrations  (ON DELETE RESTRICT)
DELETE FROM events WHERE event_id = 8;
-- Expected: Error Code: 1451. Cannot delete or update a parent row:
--           a foreign key constraint fails (... CONSTRAINT `fk_registrations_event` ...)


-- TEST 10: Deleting a participant who still has registrations
DELETE FROM participants WHERE participant_id = 1;
-- Expected: Error Code: 1451. Cannot delete or update a parent row ...


-- TEST 11: Capacity of zero  (CHECK constraint)
INSERT INTO events (event_name, event_date, venue, capacity)
VALUES ('Empty Event', CURDATE() + INTERVAL 5 DAY, 'Room 101', 0);
-- Expected: Error Code: 3819. Check constraint 'chk_events_capacity' is violated.


-- TEST 12: Invalid event status  (CHECK constraint)
INSERT INTO events (event_name, event_date, venue, capacity, status)
VALUES ('Strange Event', CURDATE() + INTERVAL 5 DAY, 'Room 101', 20, 'Postponed');
-- Expected: Error Code: 3819. Check constraint 'chk_events_status' is violated.


-- TEST 13: Invalid phone number (not 10 digits)  (CHECK constraint)
INSERT INTO participants (participant_name, email, phone, college)
VALUES ('Test User', 'test.user@example.com', '12345', 'City Institute of Technology');
-- Expected: Error Code: 3819. Check constraint 'chk_participants_phone' is violated.


-- TEST 14: Invalid email (no @)  (CHECK constraint)
INSERT INTO participants (participant_name, email, phone, college)
VALUES ('Test User', 'test.user.example.com', '9000000002', 'City Institute of Technology');
-- Expected: Error Code: 3819. Check constraint 'chk_participants_email' is violated.


-- TEST 15: Invalid date (30th February does not exist)
INSERT INTO events (event_name, event_date, venue, capacity)
VALUES ('Leap Day Talk', '2027-02-30', 'Room 101', 20);
-- Expected: Error Code: 1292. Incorrect date value: '2027-02-30' for column 'event_date' at row 1


-- TEST 16: Missing required value  (NOT NULL)
INSERT INTO events (event_name, event_date, capacity)
VALUES ('No Venue Event', CURDATE() + INTERVAL 5 DAY, 20);
-- Expected: Error Code: 1364. Field 'venue' doesn't have a default value


-- TEST 17: Reducing capacity below seats already booked (event 8 has 7)
UPDATE events SET capacity = 5 WHERE event_id = 8;
-- Expected: Error Code: 1644. Update failed: capacity cannot be less than the seats already booked.


-- TEST 18: Moving an existing registration into a FULL event
-- Registration 11 is Priya in event 4; try to move it to event 5 (full).
UPDATE registrations SET event_id = 5 WHERE registration_id = 11;
-- Expected: Error Code: 1644. Update failed: the event is full (no seats available).


-- ---------------------------------------------------------------------
-- After all tests, confirm nothing changed:
-- ---------------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM events)        AS total_events,
    (SELECT COUNT(*) FROM participants)  AS total_participants,
    (SELECT COUNT(*) FROM registrations) AS total_registrations;
-- Expected: | 8 | 12 | 29 |
