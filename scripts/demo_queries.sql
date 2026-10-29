-- Short demo: the most important tables and reports, shown one after another.
USE event_management_db;

SHOW FULL TABLES;

SELECT event_id, event_name, event_date, venue, capacity, status FROM events;

SELECT participant_id, participant_name, email, phone, department FROM participants;

SELECT p.participant_name, e.event_name, r.registration_status
FROM registrations r
JOIN participants p ON p.participant_id = r.participant_id
JOIN events e       ON e.event_id       = r.event_id
WHERE r.event_id = 5;

SELECT event_id, event_name, capacity, seats_taken, available_seats, status
FROM vw_event_seat_summary
ORDER BY event_id;

SELECT registration_status, COUNT(*) AS total
FROM registrations
GROUP BY registration_status
ORDER BY registration_status;
