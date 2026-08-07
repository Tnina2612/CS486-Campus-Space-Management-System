"""
Concurrency test for the Campus Space Management System (Phase 2).

Simulates two concurrent booking operations against the same space with
overlapping time windows, using the concurrency-safe stored procedure
usp_CreateBooking (outputs/12-concurrency-implementation-G11.sql).

Expected: exactly one of the two overlapping bookings succeeds; the other is
rejected by the space-row lock + overlap check (BR-01).

Dependencies: pyodbc + ODBC Driver for SQL Server.
Run:  python test_concurrency.py
"""
import os
import threading
import pyodbc

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
CONN_STR = os.environ.get(
    "CS486_CONN",
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=localhost;"
    "DATABASE=CampusSpaceManagement;"
    "Trusted_Connection=yes;",
)

SPACE_ID = os.environ.get("CS486_SPACE_ID", "1")   # a space allowing instant booking
USER_A   = os.environ.get("CS486_USER_A", "1")     # requester 1
USER_B   = os.environ.get("CS486_USER_B", "2")     # requester 2 (overlapping)

RESULTS = {}
RESULTS_LOCK = threading.Lock()


def run_user(label, user_id, start_time, end_time):
    """Invoke usp_CreateBooking for the given user and time window."""
    try:
        conn = pyodbc.connect(CONN_STR, autocommit=False)
        cur = conn.cursor()
        new_id = None
        try:
            cur.execute(
                "{CALL dbo.usp_CreateBooking (?,?,?,?,?,?,?)}",
                (user_id, SPACE_ID, start_time, end_time,
                 "Seminar", 20, new_id),
            )
            conn.commit()
            with RESULTS_LOCK:
                RESULTS[label] = "SUCCESS"
        except Exception as exc:  # noqa: BLE001 - capture any db error
            conn.rollback()
            with RESULTS_LOCK:
                RESULTS[label] = f"REJECTED: {exc}"
        finally:
            cur.close()
            conn.close()
    except Exception as exc:  # noqa: BLE001
        with RESULTS_LOCK:
            RESULTS[label] = f"ERROR connecting: {exc}"


def main():
    jobs = [
        ("tx1_instant_booking", USER_A, "2026-09-01 09:00", "2026-09-01 11:00"),
        ("tx2_staff_approval",  USER_B, "2026-09-01 10:00", "2026-09-01 12:00"),
    ]
    threads = [
        threading.Thread(target=run_user, args=(label, uid, start, end))
        for label, uid, start, end in jobs
    ]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    print("Results:")
    for key in sorted(RESULTS):
        print(f"  {key}: {RESULTS[key]}")

    successes = sum(1 for v in RESULTS.values() if v == "SUCCESS")
    print(f"Successful bookings: {successes}")
    assert successes == 1, (
        "FAIL: expected exactly one successful overlapping booking, got %d"
        % successes
    )
    print("PASS: concurrency control rejected the overlap.")


if __name__ == "__main__":
    main()