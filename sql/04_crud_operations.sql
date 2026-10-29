-- =====================================================================
-- EVENT MANAGEMENT SYSTEM
-- File 4 of 5 : 04_crud_operations.sql
-- Purpose     : Demonstrate CREATE, READ, UPDATE, DELETE on every table
-- Run after   : 02_sample_data.sql
--
-- This script creates its OWN new event, participant and registration,
-- works with them, and deletes them again at the end. So after it finishes
-- the sample data is exactly as it was, and the reports in file 3 still
-- give the same answers.
--
-- LAST_INSERT_ID() returns the id that AUTO_INCREMENT just generated.
-- We store it in a user variable (@name) instead of guessing the number.
-- =====================================================================

USE event_management_db;


-- =====================================================================
-- A. EVENT MANAGEMENT
-- =====================================================================

-- CREATE: add a new event (status uses its DEFAULT value 'Upcoming')
INSERT INTO events (event_name, description, event_date, venue, capacity)
VALUES ('ML Model Deployment Bootcamp',
        'Packaging ML models with Flask and Docker and deploying them.',
        CURDATE() + INTERVAL 50 DAY,
        'Computer Lab 2',
        30);
SET @new_event_id = LAST_INSERT_ID();
SELECT @new_event_id AS new_event_id;          -- 9 on a fresh database

-- READ: view all events
SELECT event_id, event_name, event_date, venue, capacity, status
FROM   events
ORDER  BY event_date;

-- READ: view the details of one particular event
SELECT * FROM events WHERE event_id = @new_event_id;

-- UPDATE: change venue and capacity
UPDATE events
   SET venue    = 'Seminar Hall B',
       capacity = 50
 WHERE event_id = @new_event_id;               -- 1 row affected

SELECT event_id, event_name, venue, capacity
FROM   events
WHERE  event_id = @new_event_id;
-- | 9 | ML Model Deployment Bootcamp | Seminar Hall B | 50 |


-- =====================================================================
-- B. PARTICIPANT MANAGEMENT
-- =====================================================================

-- CREATE
INSERT INTO participants (participant_name, email, phone, college, department)
VALUES ('Nikhil Rao', 'nikhil.rao@example.com', '9123456780',
        'City Institute of Technology', 'AI & ML');
SET @new_participant_id = LAST_INSERT_ID();     -- 13 on a fresh database

-- READ: all participants
SELECT participant_id, participant_name, email, phone, department
FROM   participants
ORDER  BY participant_name;

-- READ: search by name OR email (partial match with LIKE)
SET @search = 'nikhil';
SELECT participant_id, participant_name, email, phone
FROM   participants
WHERE  participant_name LIKE CONCAT('%', @search, '%')
   OR  email            LIKE CONCAT('%', @search, '%');
-- | 13 | Nikhil Rao | nikhil.rao@example.com | 9123456780 |

-- UPDATE: change phone number and department
UPDATE participants
   SET phone      = '9123456781',
       department = 'Data Science'
 WHERE participant_id = @new_participant_id;    -- 1 row affected

SELECT participant_id, participant_name, phone, department
FROM   participants
WHERE  participant_id = @new_participant_id;


-- =====================================================================
-- C. EVENT REGISTRATION
-- =====================================================================

-- CREATE: register the new participant for the new event.
-- registration_date and registration_status use their DEFAULT values.
INSERT INTO registrations (participant_id, event_id)
VALUES (@new_participant_id, @new_event_id);
SET @new_registration_id = LAST_INSERT_ID();    -- 30 on a fresh database

-- Also register the new participant for an existing event (event 6)
INSERT INTO registrations (participant_id, event_id)
VALUES (@new_participant_id, 6);

-- READ: registrations of the new participant
SELECT r.registration_id, e.event_name, r.registration_status, r.registration_date
FROM   registrations r
JOIN   events e ON e.event_id = r.event_id
WHERE  r.participant_id = @new_participant_id;
-- 2 rows: ML Model Deployment Bootcamp, Cloud Computing with AWS Workshop

-- Seats for the new event: 1 taken, 49 available
SELECT event_name, capacity, seats_taken, available_seats
FROM   vw_event_seat_summary
WHERE  event_id = @new_event_id;
-- | ML Model Deployment Bootcamp | 50 | 1 | 49 |

-- UPDATE: participant cancels -> the seat is released
UPDATE registrations
   SET registration_status = 'Cancelled'
 WHERE registration_id = @new_registration_id;

SELECT event_name, seats_taken, available_seats
FROM   vw_event_seat_summary
WHERE  event_id = @new_event_id;
-- | ML Model Deployment Bootcamp | 0 | 50 |

-- UPDATE: participant changes their mind -> confirmed again
-- (the update trigger re-checks capacity before allowing this)
UPDATE registrations
   SET registration_status = 'Confirmed'
 WHERE registration_id = @new_registration_id;


-- =====================================================================
-- D. DELETE  (child rows first, then parent rows)
--
-- Because of ON DELETE RESTRICT you must delete (or keep) registrations
-- before deleting the event or participant they point to. Trying it the
-- other way round is shown in 05_constraint_tests.sql (error 1451).
-- =====================================================================

-- 1) delete the child rows in registrations
DELETE FROM registrations
 WHERE participant_id = @new_participant_id;     -- 2 rows affected

-- 2) now the parent rows can be deleted
DELETE FROM events
 WHERE event_id = @new_event_id;                 -- 1 row affected

DELETE FROM participants
 WHERE participant_id = @new_participant_id;     -- 1 row affected

-- Back to the original sample data:
SELECT
    (SELECT COUNT(*) FROM events)        AS total_events,
    (SELECT COUNT(*) FROM participants)  AS total_participants,
    (SELECT COUNT(*) FROM registrations) AS total_registrations;
-- | 8 | 12 | 29 |

-- Note: AUTO_INCREMENT never re-uses deleted ids, so the next new event
-- will be id 10, not 9. That is normal behaviour. Re-running 01 + 02
-- resets the counters.
