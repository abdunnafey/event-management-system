"""Event Management System - Flask web interface.

Run from the web folder:
    python app.py
then open http://127.0.0.1:5000 in a browser.
"""
import os
import re
from datetime import date

import mysql.connector
from flask import Flask, flash, redirect, render_template, request, url_for

from db import execute, query_all, query_one

app = Flask(__name__)
app.secret_key = os.getenv("FLASK_SECRET_KEY", "dev-only-change-me")

EVENT_STATUSES = ["Upcoming", "Ongoing", "Completed", "Cancelled"]
REGISTRATION_STATUSES = ["Confirmed", "Cancelled", "Attended"]

# MySQL error numbers we turn into friendly messages
ER_DUP_ENTRY = 1062            # UNIQUE constraint violated
ER_ROW_IS_REFERENCED = 1451    # delete blocked by a foreign key
ER_NO_REFERENCED_ROW = 1452    # foreign key points to a missing row
ER_SIGNAL_EXCEPTION = 1644     # our triggers (capacity, cancelled event)
ER_CHECK_CONSTRAINT = 3819     # CHECK constraint violated

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
PHONE_RE = re.compile(r"^[0-9]{10}$")


def db_error_message(err):
    """Translate a MySQL error into a sentence a user understands."""
    if err.errno == ER_SIGNAL_EXCEPTION:
        return err.msg                        # message written in the trigger
    if err.errno == ER_DUP_ENTRY:
        if "uq_participants_email" in err.msg:
            return "A participant with this email already exists."
        if "uq_registrations_participant_event" in err.msg:
            return "This participant is already registered for this event."
        if "uq_events_name_date" in err.msg:
            return "An event with this name already exists on this date."
        return "Duplicate value: " + err.msg
    if err.errno == ER_ROW_IS_REFERENCED:
        return "This record has registrations linked to it, so it cannot be deleted."
    if err.errno == ER_NO_REFERENCED_ROW:
        return "The selected participant or event does not exist."
    if err.errno == ER_CHECK_CONSTRAINT:
        return "Invalid value: " + err.msg
    return "Database error: " + err.msg


# ---------------------------------------------------------------------
# Form validation
# ---------------------------------------------------------------------
def validate_event(form):
    errors = []
    data = {
        "event_name": form.get("event_name", "").strip(),
        "description": form.get("description", "").strip(),
        "event_date": form.get("event_date", "").strip(),
        "venue": form.get("venue", "").strip(),
        "capacity": form.get("capacity", "").strip(),
        "status": form.get("status", "Upcoming"),
    }
    if not data["event_name"]:
        errors.append("Event name is required.")
    elif len(data["event_name"]) > 100:
        errors.append("Event name must be at most 100 characters.")
    try:
        date.fromisoformat(data["event_date"])
    except ValueError:
        errors.append("Please enter a valid event date.")
    if not data["venue"]:
        errors.append("Venue is required.")
    if not data["capacity"].isdigit() or int(data["capacity"]) < 1:
        errors.append("Capacity must be a whole number greater than 0.")
    if data["status"] not in EVENT_STATUSES:
        errors.append("Please choose a valid status.")
    return data, errors


def validate_participant(form):
    errors = []
    data = {
        "participant_name": form.get("participant_name", "").strip(),
        "email": form.get("email", "").strip().lower(),
        "phone": form.get("phone", "").strip(),
        "college": form.get("college", "").strip(),
        "department": form.get("department", "").strip(),
    }
    if not data["participant_name"]:
        errors.append("Name is required.")
    if not EMAIL_RE.match(data["email"]):
        errors.append("Please enter a valid email address.")
    if not PHONE_RE.match(data["phone"]):
        errors.append("Phone number must be exactly 10 digits.")
    if not data["college"]:
        errors.append("College is required.")
    return data, errors


# ---------------------------------------------------------------------
# Dashboard
# ---------------------------------------------------------------------
@app.route("/")
def dashboard():
    totals = query_one(
        """SELECT (SELECT COUNT(*) FROM events)        AS events,
                  (SELECT COUNT(*) FROM participants)  AS participants,
                  (SELECT COUNT(*) FROM registrations
                    WHERE registration_status IN ('Confirmed','Attended')) AS registrations,
                  (SELECT COUNT(*) FROM events
                    WHERE status = 'Upcoming' AND event_date >= CURDATE()) AS upcoming"""
    )
    upcoming = query_all(
        """SELECT * FROM vw_event_seat_summary
            WHERE status = 'Upcoming' AND event_date >= CURDATE()
            ORDER BY event_date LIMIT 5"""
    )
    recent = query_all(
        """SELECT r.registration_date, p.participant_name, e.event_name, r.registration_status
             FROM registrations r
             JOIN participants p ON p.participant_id = r.participant_id
             JOIN events e       ON e.event_id = r.event_id
            ORDER BY r.registration_date DESC LIMIT 5"""
    )
    return render_template("dashboard.html", totals=totals, upcoming=upcoming, recent=recent)


# ---------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------
@app.route("/events")
def events_list():
    q = request.args.get("q", "").strip()
    on_date = request.args.get("date", "").strip()
    sql = "SELECT * FROM vw_event_seat_summary WHERE 1 = 1"
    params = []
    if q:
        sql += " AND (event_name LIKE %s OR venue LIKE %s)"
        params += [f"%{q}%", f"%{q}%"]
    if on_date:
        try:
            date.fromisoformat(on_date)
            sql += " AND event_date = %s"
            params.append(on_date)
        except ValueError:
            flash("Ignored the date filter because it is not a valid date.", "error")
            on_date = ""
    sql += " ORDER BY event_date"
    events = query_all(sql, params)
    return render_template("events.html", events=events, q=q, on_date=on_date)


@app.route("/events/new", methods=["GET", "POST"])
def event_new():
    data = {"status": "Upcoming"}
    if request.method == "POST":
        data, errors = validate_event(request.form)
        if not errors:
            try:
                new_id = execute(
                    """INSERT INTO events (event_name, description, event_date, venue, capacity, status)
                       VALUES (%s, %s, %s, %s, %s, %s)""",
                    (data["event_name"], data["description"] or None, data["event_date"],
                     data["venue"], int(data["capacity"]), data["status"]),
                )
                flash("Event created successfully.", "success")
                return redirect(url_for("event_detail", event_id=new_id))
            except mysql.connector.Error as err:
                errors.append(db_error_message(err))
        for e in errors:
            flash(e, "error")
    return render_template("event_form.html", event=data, statuses=EVENT_STATUSES, editing=False)


@app.route("/events/<int:event_id>")
def event_detail(event_id):
    event = query_one(
        """SELECT e.*, v.seats_taken, v.available_seats
             FROM events e
             JOIN vw_event_seat_summary v ON v.event_id = e.event_id
            WHERE e.event_id = %s""",
        (event_id,),
    )
    if event is None:
        flash("Event not found.", "error")
        return redirect(url_for("events_list"))
    registrations = query_all(
        """SELECT r.registration_id, r.registration_date, r.registration_status,
                  p.participant_id, p.participant_name, p.email, p.phone
             FROM registrations r
             JOIN participants p ON p.participant_id = r.participant_id
            WHERE r.event_id = %s
            ORDER BY r.registration_date""",
        (event_id,),
    )
    return render_template("event_detail.html", event=event, registrations=registrations,
                           reg_statuses=REGISTRATION_STATUSES)


@app.route("/events/<int:event_id>/edit", methods=["GET", "POST"])
def event_edit(event_id):
    event = query_one("SELECT * FROM events WHERE event_id = %s", (event_id,))
    if event is None:
        flash("Event not found.", "error")
        return redirect(url_for("events_list"))
    if request.method == "POST":
        data, errors = validate_event(request.form)
        if not errors:
            try:
                execute(
                    """UPDATE events
                          SET event_name = %s, description = %s, event_date = %s,
                              venue = %s, capacity = %s, status = %s
                        WHERE event_id = %s""",
                    (data["event_name"], data["description"] or None, data["event_date"],
                     data["venue"], int(data["capacity"]), data["status"], event_id),
                )
                flash("Event updated successfully.", "success")
                return redirect(url_for("event_detail", event_id=event_id))
            except mysql.connector.Error as err:
                errors.append(db_error_message(err))
        for e in errors:
            flash(e, "error")
        data["event_id"] = event_id
        event = data
    return render_template("event_form.html", event=event, statuses=EVENT_STATUSES, editing=True)


@app.route("/events/<int:event_id>/delete", methods=["POST"])
def event_delete(event_id):
    try:
        execute("DELETE FROM events WHERE event_id = %s", (event_id,))
        flash("Event deleted.", "success")
        return redirect(url_for("events_list"))
    except mysql.connector.Error as err:
        flash(db_error_message(err) + " Change its status to Cancelled instead.", "error")
        return redirect(url_for("event_detail", event_id=event_id))


# ---------------------------------------------------------------------
# Participants
# ---------------------------------------------------------------------
@app.route("/participants")
def participants_list():
    q = request.args.get("q", "").strip()
    sql = """SELECT p.*,
                    (SELECT COUNT(*) FROM registrations r
                      WHERE r.participant_id = p.participant_id
                        AND r.registration_status IN ('Confirmed','Attended')) AS event_count
               FROM participants p"""
    params = []
    if q:
        sql += " WHERE p.participant_name LIKE %s OR p.email LIKE %s"
        params = [f"%{q}%", f"%{q}%"]
    sql += " ORDER BY p.participant_name"
    participants = query_all(sql, params)
    return render_template("participants.html", participants=participants, q=q)


@app.route("/participants/new", methods=["GET", "POST"])
def participant_new():
    data = {}
    if request.method == "POST":
        data, errors = validate_participant(request.form)
        if not errors:
            try:
                new_id = execute(
                    """INSERT INTO participants (participant_name, email, phone, college, department)
                       VALUES (%s, %s, %s, %s, %s)""",
                    (data["participant_name"], data["email"], data["phone"],
                     data["college"], data["department"] or None),
                )
                flash("Participant added successfully.", "success")
                return redirect(url_for("participant_detail", participant_id=new_id))
            except mysql.connector.Error as err:
                errors.append(db_error_message(err))
        for e in errors:
            flash(e, "error")
    return render_template("participant_form.html", participant=data, editing=False)


@app.route("/participants/<int:participant_id>")
def participant_detail(participant_id):
    participant = query_one("SELECT * FROM participants WHERE participant_id = %s", (participant_id,))
    if participant is None:
        flash("Participant not found.", "error")
        return redirect(url_for("participants_list"))
    registrations = query_all(
        """SELECT r.registration_id, r.registration_status, r.registration_date,
                  e.event_id, e.event_name, e.event_date, e.venue
             FROM registrations r
             JOIN events e ON e.event_id = r.event_id
            WHERE r.participant_id = %s
            ORDER BY e.event_date""",
        (participant_id,),
    )
    return render_template("participant_detail.html", participant=participant,
                           registrations=registrations)


@app.route("/participants/<int:participant_id>/edit", methods=["GET", "POST"])
def participant_edit(participant_id):
    participant = query_one("SELECT * FROM participants WHERE participant_id = %s", (participant_id,))
    if participant is None:
        flash("Participant not found.", "error")
        return redirect(url_for("participants_list"))
    if request.method == "POST":
        data, errors = validate_participant(request.form)
        if not errors:
            try:
                execute(
                    """UPDATE participants
                          SET participant_name = %s, email = %s, phone = %s,
                              college = %s, department = %s
                        WHERE participant_id = %s""",
                    (data["participant_name"], data["email"], data["phone"],
                     data["college"], data["department"] or None, participant_id),
                )
                flash("Participant updated successfully.", "success")
                return redirect(url_for("participant_detail", participant_id=participant_id))
            except mysql.connector.Error as err:
                errors.append(db_error_message(err))
        for e in errors:
            flash(e, "error")
        data["participant_id"] = participant_id
        participant = data
    return render_template("participant_form.html", participant=participant, editing=True)


# ---------------------------------------------------------------------
# Registrations
# ---------------------------------------------------------------------
@app.route("/register", methods=["GET", "POST"])
def register():
    selected = {
        "participant_id": request.values.get("participant_id", ""),
        "event_id": request.values.get("event_id", ""),
    }
    if request.method == "POST":
        if not selected["participant_id"].isdigit() or not selected["event_id"].isdigit():
            flash("Please choose both a participant and an event.", "error")
        else:
            try:
                # One INSERT = one transaction. The trigger locks the event row,
                # so two simultaneous registrations cannot take the same last seat.
                execute(
                    "INSERT INTO registrations (participant_id, event_id) VALUES (%s, %s)",
                    (int(selected["participant_id"]), int(selected["event_id"])),
                )
                flash("Registration successful.", "success")
                return redirect(url_for("event_detail", event_id=int(selected["event_id"])))
            except mysql.connector.Error as err:
                flash(db_error_message(err), "error")

    participants = query_all(
        "SELECT participant_id, participant_name, email FROM participants ORDER BY participant_name"
    )
    events = query_all(
        """SELECT event_id, event_name, event_date, available_seats
             FROM vw_event_seat_summary
            WHERE status = 'Upcoming' AND event_date >= CURDATE()
            ORDER BY event_date"""
    )
    return render_template("register.html", participants=participants, events=events,
                           selected=selected)


@app.route("/registrations/<int:registration_id>/status", methods=["POST"])
def registration_status(registration_id):
    new_status = request.form.get("status", "")
    event_id = request.form.get("event_id", type=int)
    if new_status not in REGISTRATION_STATUSES:
        flash("Invalid registration status.", "error")
    else:
        try:
            execute(
                "UPDATE registrations SET registration_status = %s WHERE registration_id = %s",
                (new_status, registration_id),
            )
            flash(f"Registration marked as {new_status}.", "success")
        except mysql.connector.Error as err:
            flash(db_error_message(err), "error")
    if event_id:
        return redirect(url_for("event_detail", event_id=event_id))
    return redirect(url_for("summary"))


# ---------------------------------------------------------------------
# Reports
# ---------------------------------------------------------------------
@app.route("/summary")
def summary():
    per_event = query_all(
        """SELECT e.event_id, e.event_name, e.event_date, e.status, e.capacity,
                  SUM(CASE WHEN r.registration_status = 'Confirmed' THEN 1 ELSE 0 END) AS confirmed,
                  SUM(CASE WHEN r.registration_status = 'Attended'  THEN 1 ELSE 0 END) AS attended,
                  SUM(CASE WHEN r.registration_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled,
                  COUNT(r.registration_id) AS total
             FROM events e
             LEFT JOIN registrations r ON r.event_id = e.event_id
            GROUP BY e.event_id, e.event_name, e.event_date, e.status, e.capacity
            ORDER BY e.event_date"""
    )
    by_status = query_all(
        """SELECT registration_status, COUNT(*) AS total
             FROM registrations GROUP BY registration_status ORDER BY registration_status"""
    )
    popular = query_all(
        """SELECT event_id, event_name, seats_taken FROM vw_event_seat_summary
            WHERE seats_taken = (SELECT MAX(seats_taken) FROM vw_event_seat_summary)
              AND seats_taken > 0"""
    )
    multi = query_all(
        """SELECT p.participant_id, p.participant_name, COUNT(*) AS events_registered
             FROM participants p
             JOIN registrations r ON r.participant_id = p.participant_id
            WHERE r.registration_status IN ('Confirmed','Attended')
            GROUP BY p.participant_id, p.participant_name
           HAVING COUNT(*) > 1
            ORDER BY events_registered DESC, p.participant_name"""
    )
    empty = query_all(
        """SELECT e.event_id, e.event_name, e.status FROM events e
            WHERE NOT EXISTS (SELECT 1 FROM registrations r WHERE r.event_id = e.event_id)"""
    )
    return render_template("summary.html", per_event=per_event, by_status=by_status,
                           popular=popular, multi=multi, empty=empty)


@app.errorhandler(mysql.connector.Error)
def handle_db_down(err):
    """Shown when MySQL is not running or the .env credentials are wrong."""
    return render_template("db_error.html", message=str(err)), 500


if __name__ == "__main__":
    app.run(debug=True)
