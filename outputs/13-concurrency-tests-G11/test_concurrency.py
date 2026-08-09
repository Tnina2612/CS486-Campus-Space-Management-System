"""
test_concurrency.py
===================
Concurrency collision test for the Campus Space Management System.

Proves that two simultaneous operations -- an AUTO booking and a STAFF
approval -- targeting the same space with OVERLAPPING time periods cannot both
succeed (BR-01), thanks to the pessimistic locking implementation in
outputs/12-concurrency-implementation-G11.sql.

How it works
------------
1. Connects to the SQL Server database (Windows auth or SQL auth via env).
2. Setup: creates a test user, a test space (TEST-ROOM-A, AutoBookingEnabled=1,
   usage policy permitting 'Seminar'), and one PENDING booking (10:00-12:00)
   that tx2 will try to approve.
3. Spawns two threads that each open their OWN connection and execute one of
   the SQL files (`tx1_instant_booking.sql` / `tx2_staff_approval.sql`).
4. Captures per-thread outcome (COMMIT / rejected with error code).
5. Asserts the invariant: at most ONE approved booking exists on the space
   for the overlapping window, across many rounds.
6. Cleans up all test data.

Usage
-----
    python test_concurrency.py [rounds]

Prerequisites: see requirements.txt / README.md.
"""

import os
import sys
import threading
import pyodbc

# ----------------------------------------------------------------------------
# Configuration -- adjust to your environment or set the env vars.
# ----------------------------------------------------------------------------
SERVER = os.environ.get("MSSQL_SERVER", "localhost")
DATABASE = os.environ.get("MSSQL_DATABASE", "CampusSpaceManagement")
USERNAME = os.environ.get("MSSQL_USER", "sa")
PASSWORD = os.environ.get("MSSQL_PASSWORD", "YourStrong!Passw0rd")
DRIVER = os.environ.get("MSSQL_DRIVER", "ODBC Driver 18 for SQL Server")
USE_WINDOWS_AUTH = os.environ.get("MSSQL_WINDOWS_AUTH", "0") == "1"
TRUST_CERT = os.environ.get("MSSQL_TRUST_CERT", "0") == "1"

TEST_DATE = "2026-03-02"          # day the simulated race happens
ROUNDS = int(sys.argv[1]) if len(sys.argv) > 1 else 5

BASE_DIR = os.path.dirname(os.path.abspath(__file__))


def conn_str(database=DATABASE):
    extra = "TrustServerCertificate=yes;" if TRUST_CERT else ""
    if USE_WINDOWS_AUTH:
        return (
            f"DRIVER={{{DRIVER}}};SERVER={SERVER};DATABASE={database};"
            f"Trusted_Connection=yes;{extra}"
        )
    return (
        f"DRIVER={{{DRIVER}}};SERVER={SERVER};DATABASE={database};"
        f"UID={USERNAME};PWD={PASSWORD};{extra}"
    )


def connect():
    # autocommit=True so the runner does NOT wrap batches in an implicit outer
    # transaction. The stored procedures own their transactions via
    # BEGIN TRAN ... COMMIT/ROLLBACK; an outer implicit transaction would be
    # rolled back by the procedure's ROLLBACK and raise the misleading
    # "Transaction count after EXECUTE indicates a mismatch" (error 266).
    return pyodbc.connect(conn_str(), autocommit=True)


def fill(sql_text, **values):
    for key, val in values.items():
        sql_text = sql_text.replace("{{" + key + "}}", str(val))
    return sql_text


# ----------------------------------------------------------------------------
# Setup / teardown
# ----------------------------------------------------------------------------
def setup(conn):
    cur = conn.cursor()

    # NOTE: SCOPE_IDENTITY() executed in a SEPARATE pyodbc batch can return a
    # stale value (identity of the previous insert), so every id below is
    # captured with the OUTPUT INSERTED clause in the same batch as its INSERT.
    # Test user (the "requester")
    user_id = cur.execute(
        "INSERT INTO dbo.users (full_name, email, phone_number, role, department, account_status) "
        "OUTPUT INSERTED.user_id "
        "VALUES (N'Concurrency Test User', N'concurrency_test@school.edu', N'0000', N'Student', N'Computer Science', N'Active');"
    ).fetchval()

    # Approving staff member
    staff_id = cur.execute(
        "INSERT INTO dbo.users (full_name, email, phone_number, role, department, account_status) "
        "OUTPUT INSERTED.user_id "
        "VALUES (N'Test Staff', N'concurrency_test_staff@school.edu', N'0000', N'Facility Staff', N'Computer Science', N'Active');"
    ).fetchval()

    # Test space "TEST-ROOM-A" (AutoBookingEnabled=1 so the auto path applies,
    # and the usage policy permits the 'Seminar' purpose used by tx1).
    space_id = cur.execute(
        "INSERT INTO dbo.spaces (space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy, AutoBookingEnabled) "
        "OUTPUT INSERTED.space_id "
        "VALUES (N'TEST-ROOM-A', N'Test Room A', N'Meeting Room', N'Test Building', 1, N'101', 20, N'Available', N'Seminar; Lecture; Meeting; Workshop', 1);"
    ).fetchval()

    # PENDING booking 10:00-12:00 that tx2 will try to approve (overlaps tx1).
    pending_id = cur.execute(
        "INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, expected_participants, status, advisory_acknowledged) "
        "OUTPUT INSERTED.booking_id "
        "VALUES (?, ?, ?, ?, N'Meeting', 10, N'Pending', 0);",
        user_id, space_id, f"{TEST_DATE} 10:00:00", f"{TEST_DATE} 12:00:00",
    ).fetchval()

    conn.commit()
    return {
        "user_id": user_id,
        "staff_id": staff_id,
        "space_id": space_id,
        "pending_id": pending_id,
    }


def teardown(conn, ids):
    cur = conn.cursor()
    sid = ids["space_id"]
    # FK order: children first.
    cur.execute(
        "DELETE FROM dbo.advisory_acknowledgements WHERE booking_id IN "
        "(SELECT booking_id FROM dbo.bookings WHERE space_id = ?);", sid)
    cur.execute(
        "DELETE FROM dbo.approvals WHERE booking_id IN "
        "(SELECT booking_id FROM dbo.bookings WHERE space_id = ?);", sid)
    cur.execute(
        "DELETE FROM dbo.usage_sessions WHERE booking_id IN "
        "(SELECT booking_id FROM dbo.bookings WHERE space_id = ?);", sid)
    cur.execute("DELETE FROM dbo.bookings WHERE space_id = ?;", sid)
    cur.execute("DELETE FROM dbo.space_facility WHERE space_id = ?;", sid)
    cur.execute("DELETE FROM dbo.facility_assets WHERE space_id = ?;", sid)
    cur.execute("DELETE FROM dbo.maintenance_records WHERE space_id = ?;", sid)
    cur.execute("DELETE FROM dbo.spaces WHERE space_id = ?;", sid)
    for uid in (ids["user_id"], ids["staff_id"]):
        cur.execute("DELETE FROM dbo.users WHERE user_id = ?;", uid)
    conn.commit()


# ----------------------------------------------------------------------------
# One concurrent operation
# ----------------------------------------------------------------------------
def run_file(conn, file_path, replacements, results, tag, success_status):
    """Execute one SQL file on its own connection and record the outcome.

    The SQL file ends with `SELECT <status> AS result_status;`. The runner
    classifies the transaction as COMMIT when the returned status equals the
    expected success status; otherwise REJECTED. Any ODBC error also counts as
    REJECTED.
    """
    try:
        with open(file_path, encoding="utf-8") as f:
            sql_text = fill(f.read(), **replacements)
        # pyodbc executes a single batch; strip sqlcmd 'GO' batch separators.
        sql_text = "\n".join(
            line for line in sql_text.splitlines()
            if line.strip().upper() != "GO"
        )
        row = conn.execute(sql_text).fetchval()
        if row == success_status:
            results[tag] = ("COMMIT", None)
        else:
            results[tag] = ("REJECTED", f"status={row}")
    except pyodbc.Error as exc:
        conn.rollback()
        results[tag] = ("REJECTED", str(exc))
    finally:
        try:
            conn.close()
        except Exception:
            pass


def approved_bookings_count(conn, space_id):
    """Count approved/checked-in/completed bookings on the space that day."""
    cur = conn.cursor()
    return cur.execute(
        "SELECT COUNT(*) FROM dbo.bookings "
        "WHERE space_id = ? AND status IN ('Approved','Checked In','Completed') "
        "AND start_time >= ? AND start_time < ?;",
        space_id, f"{TEST_DATE} 00:00:00", f"{TEST_DATE} 23:59:59",
    ).fetchval()


def run_one_round(round_no):
    print(f"--- Round {round_no} ---")
    setup_conn = connect()
    try:
        ids = setup(setup_conn)
        setup_conn.close()
    except Exception as exc:
        print(f"  Setup failed: {exc}")
        setup_conn.rollback()
        setup_conn.close()
        return None

    conn1 = connect()
    conn2 = connect()

    repl_tx1 = {
        "USER_ID": ids["user_id"],
        "SPACE_ID": ids["space_id"],
        "TEST_DATE": TEST_DATE,
    }
    repl_tx2 = {
        "PENDING_BOOKING_ID": ids["pending_id"],
        "STAFF_ID": ids["staff_id"],
        "TEST_DATE": TEST_DATE,
    }

    results = {}
    t1 = threading.Thread(
        target=run_file,
        args=(conn1, os.path.join(BASE_DIR, "tx1_instant_booking.sql"), repl_tx1, results, "tx1_auto", "AUTO_APPROVED"),
    )
    t2 = threading.Thread(
        target=run_file,
        args=(conn2, os.path.join(BASE_DIR, "tx2_staff_approval.sql"), repl_tx2, results, "tx2_approval", "APPROVED"),
    )

    barrier = threading.Barrier(2)
    orig_run = threading.Thread.run

    def synced_run(self):
        barrier.wait()
        orig_run(self)

    threading.Thread.run = synced_run
    t1.start()
    t2.start()
    t1.join()
    t2.join()
    threading.Thread.run = orig_run

    # Verify invariant on a fresh connection.
    check = connect()
    try:
        count = approved_bookings_count(check, ids["space_id"])
        extra = check.execute(
            "SELECT booking_id, start_time, end_time, status FROM dbo.bookings "
            "WHERE space_id = ? ORDER BY booking_id;", ids["space_id"]).fetchall()
    finally:
        check.close()

    ok = (count == 1)
    print(f"  tx1_auto    : {results['tx1_auto'][0]}"
          + (f"  -> {results['tx1_auto'][1][:120]}" if results['tx1_auto'][1] else ""))
    print(f"  tx2_approval: {results['tx2_approval'][0]}"
          + (f"  -> {results['tx2_approval'][1][:120]}" if results['tx2_approval'][1] else ""))
    print(f"  Approved bookings on space after race: {count}  (must be exactly 1) -> "
          + ("PASS" if ok else "FAIL"))
    for row in extra:
        print(f"    [row] booking_id={row.booking_id} {row.start_time} {row.end_time} {row.status}")

    teardown_conn = connect()
    try:
        teardown(teardown_conn, ids)
    finally:
        teardown_conn.close()
    return ok


def main():
    print(f"Running {ROUNDS} round(s) of concurrent booking vs approval.")
    passed = 0
    for r in range(1, ROUNDS + 1):
        try:
            if run_one_round(r):
                passed += 1
        except Exception as exc:
            print(f"  Round {r} raised: {exc}")
    print("=" * 60)
    print(f"Summary: {passed}/{ROUNDS} rounds preserved the no-overlap invariant.")
    if passed != ROUNDS:
        print("FAILED: a double booking was detected.")
        sys.exit(1)
    print("SUCCESS: concurrency control prevents overlapping approved bookings.")


if __name__ == "__main__":
    main()
