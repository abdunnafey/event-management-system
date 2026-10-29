-- =====================================================================
-- EVENT MANAGEMENT SYSTEM
-- File 3 of 5 : 03_reports_queries.sql
-- Purpose     : Reports using JOIN, GROUP BY, HAVING, ORDER BY,
--               aggregate functions, subqueries and the view
-- Run after   : 01_schema.sql and 02_sample_data.sql (fresh data)
--
-- TIP: In Workbench, put the cursor inside ONE query and press Ctrl+Enter
--      to run only that query. Each result opens in its own Result tab.
--
-- The expected outputs below are for a fresh load of the sample data.
-- Dates shown were produced on 29-Oct-2026; your dates will be different
-- because the sample data is relative to today, but every count, name
-- and "days_left" value will be identical.
-- =====================================================================

USE event_management_db;


-- ---------------------------------------------------------------------
-- Q1. All upcoming events (future date and not cancelled/completed)
-- Concepts: WHERE with AND, CURDATE(), DATEDIFF(), ORDER BY
-- ---------------------------------------------------------------------
SELECT event_id,
       event_name,
       event_date,
       venue,
       capacity,
       DATEDIFF(event_date, CURDATE()) AS days_left
FROM   events
WHERE  status = 'Upcoming'
  AND  event_date >= CURDATE()
ORDER  BY event_date;
-- +----------+-----------------------------------+------------+------------------+----------+-----------+
-- | event_id | event_name                        | event_date | venue            | capacity | days_left |
-- +----------+-----------------------------------+------------+------------------+----------+-----------+
-- |        4 | AI in Healthcare Seminar          | 2026-11-18 | Seminar Hall B   |       80 |        20 |
-- |        5 | Competitive Coding Contest        | 2026-11-28 | Computer Lab 3   |        4 |        30 |
-- |        6 | Cloud Computing with AWS Workshop | 2026-12-13 | Computer Lab 1   |       40 |        45 |
-- |        7 | Robotics and IoT Expo             | 2026-12-28 | Main Auditorium  |      150 |        60 |
-- |        8 | TechFest Cultural Night           | 2027-01-27 | Open Air Theatre |      500 |        90 |
-- +----------+-----------------------------------+------------+------------------+----------+-----------+
-- (Event 3 is not shown because it is Cancelled.)


-- ---------------------------------------------------------------------
-- Q2. Participants registered for a selected event (event 4)
-- Concepts: INNER JOIN across all three tables, user variable
-- Change @event_id to see any other event.
-- ---------------------------------------------------------------------
SET @event_id = 4;

SELECT e.event_name,
       p.participant_id,
       p.participant_name,
       p.email,
       r.registration_status,
       DATE(r.registration_date) AS registered_on
FROM   registrations r
JOIN   participants  p ON p.participant_id = r.participant_id
JOIN   events        e ON e.event_id       = r.event_id
WHERE  r.event_id = @event_id
ORDER  BY r.registration_date;
-- +--------------------------+----------------+------------------+-------------------------+---------------------+
-- | event_name               | participant_id | participant_name | email                   | registration_status |
-- +--------------------------+----------------+------------------+-------------------------+---------------------+
-- | AI in Healthcare Seminar |              2 | Priya Nair       | priya.nair@example.com  | Confirmed           |
-- | AI in Healthcare Seminar |              4 | Ananya Iyer      | ananya.iyer@example.com | Confirmed           |
-- | AI in Healthcare Seminar |              8 | Meera Joshi      | meera.joshi@example.com | Confirmed           |
-- | AI in Healthcare Seminar |             12 | Fatima Khan      | fatima.khan@example.com | Confirmed           |
-- | AI in Healthcare Seminar |              3 | Rohan Verma      | rohan.verma@example.com | Cancelled           |
-- +--------------------------+----------------+------------------+-------------------------+---------------------+
-- (registered_on column omitted here for width)


-- ---------------------------------------------------------------------
-- Q3. All events registered by a particular participant (participant 1)
-- ---------------------------------------------------------------------
SET @participant_id = 1;

SELECT p.participant_name,
       e.event_name,
       e.event_date,
       e.venue,
       r.registration_status
FROM   registrations r
JOIN   events        e ON e.event_id       = r.event_id
JOIN   participants  p ON p.participant_id = r.participant_id
WHERE  r.participant_id = @participant_id
ORDER  BY e.event_date;
-- +------------------+------------------------------+------------+------------------+---------------------+
-- | participant_name | event_name                   | event_date | venue            | registration_status |
-- +------------------+------------------------------+------------+------------------+---------------------+
-- | Aarav Sharma     | Python for Data Science ...  | 2026-08-20 | Seminar Hall A   | Attended            |
-- | Aarav Sharma     | CodeSprint 24-Hour Hackathon | 2026-09-14 | Main Auditorium  | Attended            |
-- | Aarav Sharma     | Competitive Coding Contest   | 2026-11-28 | Computer Lab 3   | Confirmed           |
-- | Aarav Sharma     | TechFest Cultural Night      | 2027-01-27 | Open Air Theatre | Confirmed           |
-- +------------------+------------------------------+------------+------------------+---------------------+


-- ---------------------------------------------------------------------
-- Q4. Count participants registered for EACH event
-- Concepts: LEFT JOIN (keeps events with 0 registrations), COUNT, GROUP BY
-- Cancelled registrations are not counted (condition is inside ON).
-- ---------------------------------------------------------------------
SELECT e.event_id,
       e.event_name,
       COUNT(r.registration_id) AS participant_count
FROM   events e
LEFT JOIN registrations r
       ON r.event_id = e.event_id
      AND r.registration_status IN ('Confirmed', 'Attended')
GROUP  BY e.event_id, e.event_name
ORDER  BY participant_count DESC, e.event_id;
-- +----------+-----------------------------------+-------------------+
-- | event_id | event_name                        | participant_count |
-- +----------+-----------------------------------+-------------------+
-- |        8 | TechFest Cultural Night           |                 7 |
-- |        2 | CodeSprint 24-Hour Hackathon      |                 5 |
-- |        1 | Python for Data Science Workshop  |                 4 |
-- |        4 | AI in Healthcare Seminar          |                 4 |
-- |        5 | Competitive Coding Contest        |                 4 |
-- |        6 | Cloud Computing with AWS Workshop |                 3 |
-- |        3 | Cybersecurity Awareness Talk      |                 0 |
-- |        7 | Robotics and IoT Expo             |                 0 |
-- +----------+-----------------------------------+-------------------+


-- ---------------------------------------------------------------------
-- Q5. Events with NO registrations at all
-- Two equivalent ways: LEFT JOIN ... IS NULL, and NOT EXISTS subquery
-- ---------------------------------------------------------------------
SELECT e.event_id, e.event_name, e.status
FROM   events e
LEFT JOIN registrations r ON r.event_id = e.event_id
WHERE  r.registration_id IS NULL;

SELECT e.event_id, e.event_name, e.status
FROM   events e
WHERE  NOT EXISTS (SELECT 1
                   FROM   registrations r
                   WHERE  r.event_id = e.event_id);
-- Both return:
-- +----------+------------------------------+-----------+
-- | event_id | event_name                   | status    |
-- +----------+------------------------------+-----------+
-- |        3 | Cybersecurity Awareness Talk | Cancelled |
-- |        7 | Robotics and IoT Expo        | Upcoming  |
-- +----------+------------------------------+-----------+


-- ---------------------------------------------------------------------
-- Q6. The most popular event (highest number of active registrations)
-- Concepts: subquery in HAVING. Unlike "ORDER BY ... LIMIT 1", this
-- version correctly returns ALL events if there is a tie.
-- ---------------------------------------------------------------------
SELECT e.event_id,
       e.event_name,
       COUNT(*) AS participant_count
FROM   events e
JOIN   registrations r ON r.event_id = e.event_id
WHERE  r.registration_status IN ('Confirmed', 'Attended')
GROUP  BY e.event_id, e.event_name
HAVING COUNT(*) = (
         SELECT MAX(cnt)
         FROM  (SELECT COUNT(*) AS cnt
                FROM   registrations
                WHERE  registration_status IN ('Confirmed', 'Attended')
                GROUP  BY event_id) AS per_event
       );
-- +----------+-------------------------+-------------------+
-- | event_id | event_name              | participant_count |
-- +----------+-------------------------+-------------------+
-- |        8 | TechFest Cultural Night |                 7 |
-- +----------+-------------------------+-------------------+


-- ---------------------------------------------------------------------
-- Q7. Participants registered for MORE THAN ONE event
-- Concepts: WHERE filters rows BEFORE grouping, HAVING filters groups AFTER
-- ---------------------------------------------------------------------
SELECT p.participant_id,
       p.participant_name,
       COUNT(r.event_id) AS events_registered
FROM   participants p
JOIN   registrations r ON r.participant_id = p.participant_id
WHERE  r.registration_status IN ('Confirmed', 'Attended')
GROUP  BY p.participant_id, p.participant_name
HAVING COUNT(r.event_id) > 1
ORDER  BY events_registered DESC, p.participant_name;
-- +----------------+------------------+-------------------+
-- | participant_id | participant_name | events_registered |
-- +----------------+------------------+-------------------+
-- |              1 | Aarav Sharma     |                 4 |
-- |              2 | Priya Nair       |                 4 |
-- |              4 | Ananya Iyer      |                 3 |
-- |              3 | Rohan Verma      |                 3 |
-- |              9 | Arjun Menon      |                 2 |
-- |              5 | Karthik Reddy    |                 2 |
-- |              8 | Meera Joshi      |                 2 |
-- |              6 | Sneha Patil      |                 2 |
-- |              7 | Vikram Singh     |                 2 |
-- +----------------+------------------+-------------------+
-- (Divya, Rahul and Fatima have only one event each, so they are excluded.)


-- ---------------------------------------------------------------------
-- Q8. Available seats for each event
-- (a) written out with LEFT JOIN, (b) the same result from the view
-- ---------------------------------------------------------------------
SELECT e.event_id,
       e.event_name,
       e.capacity,
       COUNT(r.registration_id)              AS seats_taken,
       e.capacity - COUNT(r.registration_id) AS available_seats
FROM   events e
LEFT JOIN registrations r
       ON r.event_id = e.event_id
      AND r.registration_status IN ('Confirmed', 'Attended')
GROUP  BY e.event_id, e.event_name, e.capacity
ORDER  BY e.event_id;

SELECT event_id, event_name, capacity, seats_taken, available_seats, status
FROM   vw_event_seat_summary
ORDER  BY event_id;
-- +----------+-----------------------------------+----------+-------------+-----------------+-----------+
-- | event_id | event_name                        | capacity | seats_taken | available_seats | status    |
-- +----------+-----------------------------------+----------+-------------+-----------------+-----------+
-- |        1 | Python for Data Science Workshop  |       60 |           4 |              56 | Completed |
-- |        2 | CodeSprint 24-Hour Hackathon      |      100 |           5 |              95 | Completed |
-- |        3 | Cybersecurity Awareness Talk      |      120 |           0 |             120 | Cancelled |
-- |        4 | AI in Healthcare Seminar          |       80 |           4 |              76 | Upcoming  |
-- |        5 | Competitive Coding Contest        |        4 |           4 |               0 | Upcoming  |
-- |        6 | Cloud Computing with AWS Workshop |       40 |           3 |              37 | Upcoming  |
-- |        7 | Robotics and IoT Expo             |      150 |           0 |             150 | Upcoming  |
-- |        8 | TechFest Cultural Night           |      500 |           7 |             493 | Upcoming  |
-- +----------+-----------------------------------+----------+-------------+-----------------+-----------+

-- Events that are completely full
SELECT event_id, event_name, capacity
FROM   vw_event_seat_summary
WHERE  available_seats = 0;
-- | 5 | Competitive Coding Contest | 4 |


-- ---------------------------------------------------------------------
-- Q9. Search events by DATE and by VENUE
-- Concepts: BETWEEN, LIKE with % wildcard
-- ---------------------------------------------------------------------
-- (a) Events in the next 30 days
SELECT event_id, event_name, event_date, venue, status
FROM   events
WHERE  event_date BETWEEN CURDATE() AND CURDATE() + INTERVAL 30 DAY
ORDER  BY event_date;
-- | 3 | Cybersecurity Awareness Talk | (today+10) | Seminar Hall A | Cancelled |
-- | 4 | AI in Healthcare Seminar     | (today+20) | Seminar Hall B | Upcoming  |
-- | 5 | Competitive Coding Contest   | (today+30) | Computer Lab 3 | Upcoming  |

-- (b) Events on one exact date  (replace with any date in 'YYYY-MM-DD' format)
SELECT event_id, event_name, event_date, venue
FROM   events
WHERE  event_date = CURDATE() + INTERVAL 20 DAY;
-- | 4 | AI in Healthcare Seminar | (today+20) | Seminar Hall B |

-- (c) Events at any venue whose name contains "Seminar"
SELECT event_id, event_name, event_date, venue
FROM   events
WHERE  venue LIKE '%Seminar%'
ORDER  BY event_date;
-- | 1 | Python for Data Science Workshop | Seminar Hall A |
-- | 3 | Cybersecurity Awareness Talk     | Seminar Hall A |
-- | 4 | AI in Healthcare Seminar         | Seminar Hall B |


-- ---------------------------------------------------------------------
-- Q10. Registration summary
-- (a) totals by status   (b) per-event breakdown using SUM(CASE ...)
-- ---------------------------------------------------------------------
SELECT registration_status,
       COUNT(*) AS total
FROM   registrations
GROUP  BY registration_status
ORDER  BY registration_status;
-- +---------------------+-------+
-- | registration_status | total |
-- +---------------------+-------+
-- | Attended            |     9 |
-- | Cancelled           |     2 |
-- | Confirmed           |    18 |
-- +---------------------+-------+

SELECT e.event_id,
       e.event_name,
       e.status AS event_status,
       SUM(CASE WHEN r.registration_status = 'Confirmed' THEN 1 ELSE 0 END) AS confirmed,
       SUM(CASE WHEN r.registration_status = 'Attended'  THEN 1 ELSE 0 END) AS attended,
       SUM(CASE WHEN r.registration_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled,
       COUNT(r.registration_id) AS total_registrations
FROM   events e
LEFT JOIN registrations r ON r.event_id = e.event_id
GROUP  BY e.event_id, e.event_name, e.status
ORDER  BY e.event_id;
-- +----------+-----------------------------------+--------------+-----------+----------+-----------+---------------------+
-- | event_id | event_name                        | event_status | confirmed | attended | cancelled | total_registrations |
-- +----------+-----------------------------------+--------------+-----------+----------+-----------+---------------------+
-- |        1 | Python for Data Science Workshop  | Completed    |         0 |        4 |         1 |                   5 |
-- |        2 | CodeSprint 24-Hour Hackathon      | Completed    |         0 |        5 |         0 |                   5 |
-- |        3 | Cybersecurity Awareness Talk      | Cancelled    |         0 |        0 |         0 |                   0 |
-- |        4 | AI in Healthcare Seminar          | Upcoming     |         4 |        0 |         1 |                   5 |
-- |        5 | Competitive Coding Contest        | Upcoming     |         4 |        0 |         0 |                   4 |
-- |        6 | Cloud Computing with AWS Workshop | Upcoming     |         3 |        0 |         0 |                   3 |
-- |        7 | Robotics and IoT Expo             | Upcoming     |         0 |        0 |         0 |                   0 |
-- |        8 | TechFest Cultural Night           | Upcoming     |         7 |        0 |         0 |                   7 |
-- +----------+-----------------------------------+--------------+-----------+----------+-----------+---------------------+


-- ---------------------------------------------------------------------
-- Q11. Events with more registrations than the average event
-- Concepts: derived table (subquery in FROM), AVG
-- Average = 27 active registrations / 8 events = 3.375
-- ---------------------------------------------------------------------
SELECT event_id, event_name, seats_taken
FROM   vw_event_seat_summary
WHERE  seats_taken > (SELECT AVG(seats_taken) FROM vw_event_seat_summary)
ORDER  BY seats_taken DESC, event_id;
-- | 8 | TechFest Cultural Night          | 7 |
-- | 2 | CodeSprint 24-Hour Hackathon     | 5 |
-- | 1 | Python for Data Science Workshop | 4 |
-- | 4 | AI in Healthcare Seminar         | 4 |
-- | 5 | Competitive Coding Contest       | 4 |


-- ---------------------------------------------------------------------
-- Q12. Department-wise participation (active registrations)
-- ---------------------------------------------------------------------
SELECT p.department,
       COUNT(DISTINCT p.participant_id) AS students,
       COUNT(r.registration_id)         AS registrations
FROM   participants p
JOIN   registrations r ON r.participant_id = p.participant_id
WHERE  r.registration_status IN ('Confirmed', 'Attended')
GROUP  BY p.department
ORDER  BY registrations DESC, p.department;
-- +---------------------+----------+---------------+
-- | department          | students | registrations |
-- +---------------------+----------+---------------+
-- | AI & ML             |        4 |            11 |
-- | Computer Science    |        3 |             7 |
-- | Electronics         |        2 |             3 |
-- | Information Science |        1 |             3 |
-- | Mechanical          |        1 |             2 |
-- | Data Science        |        1 |             1 |
-- +---------------------+----------+---------------+
