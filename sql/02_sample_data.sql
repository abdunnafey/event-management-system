-- =====================================================================
-- EVENT MANAGEMENT SYSTEM
-- File 2 of 5 : 02_sample_data.sql
-- Purpose     : Insert realistic sample data
-- Run after   : 01_schema.sql
--
-- Dates are written relative to today (CURDATE() + INTERVAL n DAY), so the
-- project always has some past events and some upcoming events, no matter
-- which day you demonstrate it.
--
-- Result after this file: 8 events, 12 participants, 29 registrations
-- =====================================================================

USE event_management_db;

-- MySQL Workbench has "safe update mode" ON by default, which blocks some
-- UPDATE statements. We switch it off only for this script.
SET SQL_SAFE_UPDATES = 0;


-- ---------------------------------------------------------------------
-- EVENTS  (event_id is generated automatically: 1, 2, 3 ... 8)
-- ---------------------------------------------------------------------
INSERT INTO events (event_name, description, event_date, venue, capacity, status) VALUES
('Python for Data Science Workshop',
 'Hands-on workshop on NumPy, Pandas and Matplotlib for beginners.',
 CURDATE() - INTERVAL 70 DAY, 'Seminar Hall A', 60, 'Upcoming'),          -- 1 (past)

('CodeSprint 24-Hour Hackathon',
 'Team hackathon on building AI-powered solutions for campus problems.',
 CURDATE() - INTERVAL 45 DAY, 'Main Auditorium', 100, 'Upcoming'),        -- 2 (past)

('Cybersecurity Awareness Talk',
 'Guest lecture on phishing, password safety and ethical hacking careers.',
 CURDATE() + INTERVAL 10 DAY, 'Seminar Hall A', 120, 'Cancelled'),        -- 3

('AI in Healthcare Seminar',
 'Industry experts discuss medical imaging, diagnosis models and ethics.',
 CURDATE() + INTERVAL 20 DAY, 'Seminar Hall B', 80, 'Upcoming'),          -- 4

('Competitive Coding Contest',
 'Individual 3-hour contest on data structures and algorithms.',
 CURDATE() + INTERVAL 30 DAY, 'Computer Lab 3', 4, 'Upcoming'),           -- 5 (only 4 seats)

('Cloud Computing with AWS Workshop',
 'Deploying web apps and ML models on AWS EC2, S3 and Lambda.',
 CURDATE() + INTERVAL 45 DAY, 'Computer Lab 1', 40, 'Upcoming'),          -- 6

('Robotics and IoT Expo',
 'Exhibition of student robotics and Internet-of-Things projects.',
 CURDATE() + INTERVAL 60 DAY, 'Main Auditorium', 150, 'Upcoming'),        -- 7

('TechFest Cultural Night',
 'Music, dance and drama performances on the final night of TechFest.',
 CURDATE() + INTERVAL 90 DAY, 'Open Air Theatre', 500, 'Upcoming');       -- 8


-- ---------------------------------------------------------------------
-- PARTICIPANTS  (participant_id 1 ... 12)
-- ---------------------------------------------------------------------
INSERT INTO participants (participant_name, email, phone, college, department) VALUES
('Aarav Sharma',    'aarav.sharma@example.com',    '9876543210', 'City Institute of Technology',  'AI & ML'),          -- 1
('Priya Nair',      'priya.nair@example.com',      '9845012345', 'City Institute of Technology',  'Computer Science'), -- 2
('Rohan Verma',     'rohan.verma@example.com',     '9123456789', 'City Institute of Technology',  'AI & ML'),          -- 3
('Ananya Iyer',     'ananya.iyer@example.com',     '9988776655', 'Greenfield Engineering College','Information Science'),-- 4
('Karthik Reddy',   'karthik.reddy@example.com',   '9001122334', 'City Institute of Technology',  'Electronics'),      -- 5
('Sneha Patil',     'sneha.patil@example.com',     '9765432109', 'Greenfield Engineering College','Computer Science'), -- 6
('Vikram Singh',    'vikram.singh@example.com',    '9812345670', 'City Institute of Technology',  'Mechanical'),       -- 7
('Meera Joshi',     'meera.joshi@example.com',     '9090909090', 'City Institute of Technology',  'AI & ML'),          -- 8
('Arjun Menon',     'arjun.menon@example.com',     '9345678901', 'Greenfield Engineering College','AI & ML'),          -- 9
('Divya Kulkarni',  'divya.kulkarni@example.com',  '9567890123', 'City Institute of Technology',  'Data Science'),     -- 10
('Rahul Gupta',     'rahul.gupta@example.com',     '9678901234', 'Greenfield Engineering College','Electronics'),      -- 11
('Fatima Khan',     'fatima.khan@example.com',     '9234567890', 'City Institute of Technology',  'Computer Science'); -- 12


-- ---------------------------------------------------------------------
-- REGISTRATIONS  (registration_id 1 ... 29)
-- Each row links ONE participant to ONE event.
-- The insert trigger checks capacity for every row.
-- ---------------------------------------------------------------------
INSERT INTO registrations (participant_id, event_id, registration_date, registration_status) VALUES
-- Event 1: Python for Data Science Workshop (past)
(1, 1, NOW() - INTERVAL 90 DAY, 'Confirmed'),
(2, 1, NOW() - INTERVAL 88 DAY, 'Confirmed'),
(3, 1, NOW() - INTERVAL 87 DAY, 'Confirmed'),
(5, 1, NOW() - INTERVAL 85 DAY, 'Confirmed'),
(8, 1, NOW() - INTERVAL 84 DAY, 'Cancelled'),
-- Event 2: CodeSprint 24-Hour Hackathon (past)
(1, 2, NOW() - INTERVAL 60 DAY, 'Confirmed'),
(4, 2, NOW() - INTERVAL 58 DAY, 'Confirmed'),
(6, 2, NOW() - INTERVAL 57 DAY, 'Confirmed'),
(7, 2, NOW() - INTERVAL 55 DAY, 'Confirmed'),
(9, 2, NOW() - INTERVAL 52 DAY, 'Confirmed'),
-- Event 4: AI in Healthcare Seminar
(2,  4, NOW() - INTERVAL 10 DAY, 'Confirmed'),
(4,  4, NOW() - INTERVAL 9 DAY,  'Confirmed'),
(8,  4, NOW() - INTERVAL 8 DAY,  'Confirmed'),
(12, 4, NOW() - INTERVAL 6 DAY,  'Confirmed'),
(3,  4, NOW() - INTERVAL 5 DAY,  'Cancelled'),
-- Event 5: Competitive Coding Contest (capacity 4 -> becomes FULL)
(1, 5, NOW() - INTERVAL 7 DAY, 'Confirmed'),
(3, 5, NOW() - INTERVAL 6 DAY, 'Confirmed'),
(7, 5, NOW() - INTERVAL 4 DAY, 'Confirmed'),
(9, 5, NOW() - INTERVAL 3 DAY, 'Confirmed'),
-- Event 6: Cloud Computing with AWS Workshop
(2,  6, NOW() - INTERVAL 3 DAY, 'Confirmed'),
(5,  6, NOW() - INTERVAL 2 DAY, 'Confirmed'),
(11, 6, NOW() - INTERVAL 1 DAY, 'Confirmed'),
-- Event 8: TechFest Cultural Night
(1,  8, NOW() - INTERVAL 5 DAY, 'Confirmed'),
(2,  8, NOW() - INTERVAL 4 DAY, 'Confirmed'),
(3,  8, NOW() - INTERVAL 4 DAY, 'Confirmed'),
(4,  8, NOW() - INTERVAL 3 DAY, 'Confirmed'),
(6,  8, NOW() - INTERVAL 2 DAY, 'Confirmed'),
(8,  8, NOW() - INTERVAL 2 DAY, 'Confirmed'),
(10, 8, NOW() - INTERVAL 1 DAY, 'Confirmed');
-- Events 3 (cancelled) and 7 intentionally have NO registrations.


-- ---------------------------------------------------------------------
-- The two past events have now happened: mark them Completed and mark
-- their confirmed participants as Attended.
-- ---------------------------------------------------------------------
UPDATE events
   SET status = 'Completed'
 WHERE event_id IN (1, 2);                         -- 2 rows affected

UPDATE registrations
   SET registration_status = 'Attended'
 WHERE event_id IN (1, 2)
   AND registration_status = 'Confirmed';          -- 9 rows affected

SET SQL_SAFE_UPDATES = 1;


-- ---------------------------------------------------------------------
-- Verify the row counts
-- ---------------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM events)        AS total_events,
    (SELECT COUNT(*) FROM participants)  AS total_participants,
    (SELECT COUNT(*) FROM registrations) AS total_registrations;
-- Expected:
-- +--------------+--------------------+---------------------+
-- | total_events | total_participants | total_registrations |
-- +--------------+--------------------+---------------------+
-- |            8 |                 12 |                  29 |
-- +--------------+--------------------+---------------------+

SELECT * FROM events;
SELECT * FROM participants;
SELECT * FROM registrations;
