-- =====================================================================
-- EVENT MANAGEMENT SYSTEM
-- File 1 of 5 : 01_schema.sql
-- Purpose     : Create the database, tables, constraints, triggers, view
-- Requires    : MySQL 8.0.16 or later (CHECK constraints are enforced
--               from 8.0.16 onwards). Tested syntax target: MySQL 8.0.x
-- Run in      : MySQL Workbench -> File > Open SQL Script -> click the
--               lightning-bolt icon (Execute all)  or  Ctrl+Shift+Enter
--
-- WARNING / RESET: This file starts with DROP DATABASE. Running it again
-- deletes ALL data and rebuilds an empty database. That is exactly how you
-- reset the project for testing: run 01_schema.sql, then 02_sample_data.sql.
-- =====================================================================


-- ---------------------------------------------------------------------
-- STEP 1 : Create the database and select it
-- ---------------------------------------------------------------------
DROP DATABASE IF EXISTS event_management_db;

CREATE DATABASE event_management_db
    CHARACTER SET utf8mb4             -- supports every language and emoji
    COLLATE utf8mb4_0900_ai_ci;       -- case-insensitive comparisons

USE event_management_db;


-- ---------------------------------------------------------------------
-- STEP 2 : EVENTS table  (one row = one event)
-- ---------------------------------------------------------------------
CREATE TABLE events (
    event_id     INT           NOT NULL AUTO_INCREMENT,
    event_name   VARCHAR(100)  NOT NULL,
    description  TEXT,
    event_date   DATE          NOT NULL,
    venue        VARCHAR(100)  NOT NULL,
    capacity     INT           NOT NULL,
    status       VARCHAR(20)   NOT NULL DEFAULT 'Upcoming',
    created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (event_id),

    -- The same event cannot be created twice on the same day
    CONSTRAINT uq_events_name_date UNIQUE (event_name, event_date),

    -- An event must have at least one seat
    CONSTRAINT chk_events_capacity CHECK (capacity > 0),

    -- Only these four status values are allowed
    CONSTRAINT chk_events_status
        CHECK (status IN ('Upcoming', 'Ongoing', 'Completed', 'Cancelled')),

    -- Speeds up "search events by date" queries
    INDEX idx_events_date (event_date)
) ENGINE = InnoDB;


-- ---------------------------------------------------------------------
-- STEP 3 : PARTICIPANTS table  (one row = one person)
-- ---------------------------------------------------------------------
CREATE TABLE participants (
    participant_id    INT           NOT NULL AUTO_INCREMENT,
    participant_name  VARCHAR(100)  NOT NULL,
    email             VARCHAR(100)  NOT NULL,
    phone             VARCHAR(15)   NOT NULL,
    college           VARCHAR(150)  NOT NULL,
    department        VARCHAR(100),
    created_at        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (participant_id),

    -- No two participants may share an email address.
    -- Because the collation is case-insensitive, 'A@x.com' = 'a@x.com'.
    CONSTRAINT uq_participants_email UNIQUE (email),

    -- Very simple email shape check: something@something.something
    CONSTRAINT chk_participants_email CHECK (email LIKE '%_@_%._%'),

    -- Phone must be exactly 10 digits (Indian mobile format)
    CONSTRAINT chk_participants_phone CHECK (phone REGEXP '^[0-9]{10}$')
) ENGINE = InnoDB;


-- ---------------------------------------------------------------------
-- STEP 4 : REGISTRATIONS table  (one row = one participant in one event)
-- This is the "junction" (bridge) table that turns the many-to-many
-- relationship between participants and events into two one-to-many
-- relationships.
-- ---------------------------------------------------------------------
CREATE TABLE registrations (
    registration_id      INT          NOT NULL AUTO_INCREMENT,
    participant_id       INT          NOT NULL,
    event_id             INT          NOT NULL,
    registration_date    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    registration_status  VARCHAR(20)  NOT NULL DEFAULT 'Confirmed',

    PRIMARY KEY (registration_id),

    -- A participant can register for a given event only ONCE
    CONSTRAINT uq_registrations_participant_event
        UNIQUE (participant_id, event_id),

    CONSTRAINT chk_registrations_status
        CHECK (registration_status IN ('Confirmed', 'Cancelled', 'Attended')),

    -- Referential integrity: participant_id must exist in participants.
    -- RESTRICT = you cannot delete a participant who still has registrations.
    CONSTRAINT fk_registrations_participant
        FOREIGN KEY (participant_id)
        REFERENCES participants (participant_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    -- Referential integrity: event_id must exist in events.
    -- RESTRICT = you cannot delete an event that still has registrations.
    CONSTRAINT fk_registrations_event
        FOREIGN KEY (event_id)
        REFERENCES events (event_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE = InnoDB;


-- ---------------------------------------------------------------------
-- STEP 5 : TRIGGERS for business rules that CHECK constraints cannot do
--
-- A CHECK constraint can only look at the row being inserted. To stop an
-- event from being over-booked we must COUNT rows in another table, so we
-- use triggers. "Seats taken" = registrations with status Confirmed or
-- Attended. Cancelled registrations free their seat.
--
-- DELIMITER $$ tells Workbench that the trigger body (which contains ;)
-- ends at $$ instead of at the first semicolon.
-- ---------------------------------------------------------------------
DELIMITER $$

-- Rule 1: before a NEW registration is saved, make sure the event exists,
--         is open, and still has a free seat.
CREATE TRIGGER trg_registrations_before_insert
BEFORE INSERT ON registrations
FOR EACH ROW
BEGIN
    DECLARE v_capacity INT DEFAULT NULL;
    DECLARE v_status   VARCHAR(20);
    DECLARE v_taken    INT;

    IF NEW.registration_status <> 'Cancelled' THEN

        -- FOR UPDATE locks this event's row until the transaction ends.
        -- If two people register for the same event at the same moment,
        -- the second one waits here until the first is saved, so both
        -- cannot grab the last seat.
        SELECT capacity, status
          INTO v_capacity, v_status
          FROM events
         WHERE event_id = NEW.event_id
           FOR UPDATE;

        IF v_capacity IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Registration failed: the event does not exist.';
        END IF;

        IF v_status IN ('Cancelled', 'Completed') THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Registration failed: the event is cancelled or already completed.';
        END IF;

        SELECT COUNT(*)
          INTO v_taken
          FROM registrations
         WHERE event_id = NEW.event_id
           AND registration_status IN ('Confirmed', 'Attended');

        IF v_taken >= v_capacity THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Registration failed: the event is full (no seats available).';
        END IF;
    END IF;
END$$


-- Rule 2: re-activating a CANCELLED registration (or moving it to another
--         event) needs a free seat too.
CREATE TRIGGER trg_registrations_before_update
BEFORE UPDATE ON registrations
FOR EACH ROW
BEGIN
    DECLARE v_capacity INT DEFAULT NULL;
    DECLARE v_status   VARCHAR(20);
    DECLARE v_taken    INT;

    IF NEW.registration_status <> 'Cancelled'
       AND (OLD.registration_status = 'Cancelled' OR NEW.event_id <> OLD.event_id) THEN

        SELECT capacity, status
          INTO v_capacity, v_status
          FROM events
         WHERE event_id = NEW.event_id
           FOR UPDATE;

        IF v_status IN ('Cancelled', 'Completed') THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Update failed: the event is cancelled or already completed.';
        END IF;

        SELECT COUNT(*)
          INTO v_taken
          FROM registrations
         WHERE event_id = NEW.event_id
           AND registration_status IN ('Confirmed', 'Attended')
           AND registration_id <> NEW.registration_id;

        IF v_taken >= v_capacity THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Update failed: the event is full (no seats available).';
        END IF;
    END IF;
END$$


-- Rule 3: an event's capacity cannot be reduced below the seats already taken.
CREATE TRIGGER trg_events_before_update
BEFORE UPDATE ON events
FOR EACH ROW
BEGIN
    DECLARE v_taken INT;

    IF NEW.capacity < OLD.capacity THEN
        SELECT COUNT(*)
          INTO v_taken
          FROM registrations
         WHERE event_id = NEW.event_id
           AND registration_status IN ('Confirmed', 'Attended');

        IF NEW.capacity < v_taken THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Update failed: capacity cannot be less than the seats already booked.';
        END IF;
    END IF;
END$$

DELIMITER ;


-- ---------------------------------------------------------------------
-- STEP 6 : VIEW = a saved SELECT query that behaves like a read-only table.
-- It shows seats taken and seats available for every event, so reports
-- and the web app do not have to repeat this JOIN.
-- LEFT JOIN keeps events that have zero registrations.
-- ---------------------------------------------------------------------
CREATE VIEW vw_event_seat_summary AS
SELECT
    e.event_id,
    e.event_name,
    e.event_date,
    e.venue,
    e.capacity,
    e.status,
    COUNT(r.registration_id)              AS seats_taken,
    e.capacity - COUNT(r.registration_id) AS available_seats
FROM events e
LEFT JOIN registrations r
       ON r.event_id = e.event_id
      AND r.registration_status IN ('Confirmed', 'Attended')
GROUP BY e.event_id, e.event_name, e.event_date, e.venue, e.capacity, e.status;


-- ---------------------------------------------------------------------
-- STEP 7 : Verify that everything was created
-- Expected: 3 tables + 1 view, and 3 triggers
-- ---------------------------------------------------------------------
SHOW FULL TABLES;
-- +--------------------------------+------------+
-- | Tables_in_event_management_db  | Table_type |
-- +--------------------------------+------------+
-- | events                         | BASE TABLE |
-- | participants                   | BASE TABLE |
-- | registrations                  | BASE TABLE |
-- | vw_event_seat_summary          | VIEW       |
-- +--------------------------------+------------+

SHOW TRIGGERS;
-- 3 rows: trg_events_before_update, trg_registrations_before_insert,
--         trg_registrations_before_update

DESCRIBE events;
DESCRIBE participants;
DESCRIBE registrations;
