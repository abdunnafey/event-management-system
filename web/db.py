"""Database helper functions.

Every function opens a connection, runs ONE parameterized query and closes
the connection. Values are always passed separately from the SQL text
(the %s placeholders), so user input can never change the SQL itself.
That is what prevents SQL injection.
"""
import os

import mysql.connector
from dotenv import load_dotenv

# Read DB_HOST, DB_USER, DB_PASSWORD ... from the .env file (if it exists)
load_dotenv()


def get_connection():
    return mysql.connector.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD", ""),
        database=os.getenv("DB_NAME", "event_management_db"),
    )


def query_all(sql, params=()):
    """Run a SELECT and return a list of dictionaries (one per row)."""
    conn = get_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        cursor.execute(sql, params)
        return cursor.fetchall()
    finally:
        conn.close()


def query_one(sql, params=()):
    """Run a SELECT and return the first row as a dictionary, or None."""
    rows = query_all(sql, params)
    return rows[0] if rows else None


def execute(sql, params=()):
    """Run INSERT / UPDATE / DELETE, commit, and return the new row id."""
    conn = get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(sql, params)
        conn.commit()
        return cursor.lastrowid
    except mysql.connector.Error:
        conn.rollback()
        raise
    finally:
        conn.close()
