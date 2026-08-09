"""
test_concurrency.py
===================
Concurrency collision test for the Campus Space Management System.

Proves that two simultaneous operations -- an AUTO booking and a STAFF
approval -- targeting the same space with OVERLAPPING time periods cannot both
succeed (BR-01), thanks to the pessimistic locking implementation in
outputs/12-concurrency-implementation-G11.sql.

Also proves the Phase 2 concurrency-related rules:
  1. Advisory maintenance does NOT block a booking (BR-12); the booking is
     auto-approved and an acknowledgement row is recorded.
  2. Out-of-service maintenance DOES block an overlapping booking (BR-11);
     the request returns status 'OUT_OF_SERVICE' and no booking is written.
  3. Duplicate INCIDENT_REPORT submissions can be consolidated into ONE
     MAINTENANCE_RECORD; a concurrent/second triage of the same report is
     rejected (ALREADY_CONSOLIDATED).
  4. Auto-approval records APPROVAL.staff_id = NULL (system actor, C7).

How it works
------------
1. Connects to the SQL Server database (Windows auth or SQL auth via env).
2. Runs independent scenarios, each creating its own test rows:
   - RACE   : tx1 (instant) vs tx2 (staff approval) on overlapping windows.
   - ADVISORY  : tx3 books a space that has an advisory maintenance overlap.
   - OOS     : tx4 books a space that has an out-of-service maintenance overlap.
   - TRIAGE  : consolidates duplicate incident reports via
               sp_consolidate_incident_reports and verifies one record.
3. Captures per-operation outcome and asserts each invariant.
4. Cleans up all test data.

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


def execute_file(conn, file_path, replacements, success_status):
    """Run one SQL scenario file on the given connection and return its status.

    Returns (ok, status_or_error). The SQL file ends with
    `SELECT ISNULL(@rs, N'NO_STATUS') AS result_status;`.
    """
    try:
        with open(file_path, encoding="utf-8") as f:
            sql_text = fill(f.read(), **replacements)
        sql_text = "\n".join(
            line for line in sql_text.splitlines()
            if line.strip().upper() != "GO"
        )
        row = conn.execute(sql_text).fetchval()
        if row == success_status:
            return (True, row)
        return (False, f"status={row}")
    except pyodbc.Error as exc:
        try:
            conn.rollback()
        except Exception:
            pass
        return (False, str(exc))


# ----------------------------------------------------------------------------
# Setup helpers
# ----------------------------------------------------------------------------
def make_user(conn, full_name, email, role):
    return conn.execute(
        "INSERT INTO dbo.users (full_name, email, phone_number, role, department, account_status) "
        "OUTPUT INSERTED.user_id "
        "VALUES (?, ?, N'0000', ?, N'Computer Science', N'Active');",
        full_name, email, role,
    ).fetchval()


def make_space(conn, code, auto_enabled=1):
    return conn.execute(
        "INSERT INTO dbo.spaces (space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy, AutoBookingEnabled) "
        "OUTPUT INSERTED.space_id "
        "VALUES (?, N'Test ' + ?, N'Meeting Room', N'Test Building', 1, N'101', 20, N'Available', N'Seminar; Lecture; Meeting; Workshop', ?);",
        code, code, 1 if auto_enabled else 0,
    ).fetchval()


def make_maintenance(conn, space_id, impact, start, end):
    return conn.execute(
        "INSERT INTO dbo.maintenance_records "
        "(space_id, reporter_id, assigned_staff_id, problem_description, start_time, completion_time, status, result_note, impact_level) "
        "OUTPUT INSERTED.maintenance_id "
        "VALUES (?, ?, NULL, N'Test ' + ?, ?, ?, N'Open', NULL, ?);",
        space_id, 1, impact, start, end, impact,
    ).fetchval()


# ----------------------------------------------------------------------------
# Teardown helpers
# ----------------------------------------------------------------------------
def delete_by_space(conn, space_id):
    cur = conn.cursor()
    cur.execute(
        "DELETE FROM dbo.advisory_acknowledgements WHERE booking_id IN "
        "(SELECT booking_id FROM dbo.bookings WHERE space_id = ?);", space_id)
    cur.execute(
        "DELETE FROM dbo.approvals WHERE booking_id IN "
        "(SELECT booking_id FROM dbo.bookings WHERE space_id = ?);", space_id)
    cur.execute(
        "DELETE FROM dbo.usage_sessions WHERE booking_id IN "
        "(SELECT booking_id FROM dbo.bookings WHERE space_id = ?);", space_id)
    cur.execute("DELETE FROM dbo.bookings WHERE space_id = ?;", space_id)
    cur.execute("DELETE FROM dbo.space_facility WHERE space_id = ?;", space_id)
    cur.execute("DELETE FROM dbo.facility_assets WHERE space_id = ?;", space_id)
    cur.execute(
        "DELETE FROM dbo.report_consolidations WHERE maintenance_id IN "
        "(SELECT maintenance_id FROM dbo.maintenance_records WHERE space_id = ?);", space_id)
    cur.execute(
        "DELETE FROM dbo.incident_reports WHERE space_id = ?;", space_id)
    cur.execute("DELETE FROM dbo.maintenance_records WHERE space_id = ?;", space_id)
    cur.execute("DELETE FROM dbo.spaces WHERE space_id = ?;", space_id)
    cur.commit()


def delete_user(conn, user_id):
    conn.execute("DELETE FROM dbo.users WHERE user_id = ?;", user_id)
    conn.commit()


# ----------------------------------------------------------------------------
# Scenario 1: concurrent auto-booking vs staff approval (the race)
# ----------------------------------------------------------------------------
def scenario_race():
    print("=" * 60)
    print("SCENARIO 1: concurrent instant-booking vs staff approval (BR-01)")
    print("=" * 60)
    passed = 0
    for r in range(1, ROUNDS + 1):
        print(f"--- Round {r} ---")
        setup_conn = connect()
        user_id = make_user(setup_conn, "Concurrency Test User", f"concurrency_test_{r}@school.edu", "Student")
        staff_id = make_user(setup_conn, "Test Staff", f"concurrency_test_staff_{r}@school.edu", "Facility Staff")
        space_id = make_space(setup_conn, "TEST-ROOM-A")
        pending_id = setup_conn.execute(
            "INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, expected_participants, status, advisory_acknowledged) "
            "OUTPUT INSERTED.booking_id "
            "VALUES (?, ?, ?, ?, N'Meeting', 10, N'Pending', 0);",
            user_id, space_id, f"{TEST_DATE} 10:00:00", f"{TEST_DATE} 12:00:00",
        ).fetchval()
        setup_conn.commit()
        setup_conn.close()

        conn1 = connect()
        conn2 = connect()

        repl_tx1 = {"USER_ID": user_id, "SPACE_ID": space_id, "TEST_DATE": TEST_DATE}
        repl_tx2 = {"PENDING_BOOKING_ID": pending_id, "STAFF_ID": staff_id, "TEST_DATE": TEST_DATE}

        results = {}
        barrier = threading.Barrier(2)

        def run_tx1():
            barrier.wait()
            results["tx1"] = execute_file(
                conn1, os.path.join(BASE_DIR, "tx1_instant_booking.sql"),
                repl_tx1, "AUTO_APPROVED")

        def run_tx2():
            barrier.wait()
            results["tx2"] = execute_file(
                conn2, os.path.join(BASE_DIR, "tx2_staff_approval.sql"),
                repl_tx2, "APPROVED")

        t1 = threading.Thread(target=run_tx1)
        t2 = threading.Thread(target=run_tx2)
        t1.start(); t2.start(); t1.join(); t2.join()

        check = connect()
        count = check.execute(
            "SELECT COUNT(*) FROM dbo.bookings "
            "WHERE space_id = ? AND status IN ('Approved','Checked In','Completed') "
            "AND start_time >= ? AND start_time < ?;",
            space_id, f"{TEST_DATE} 00:00:00", f"{TEST_DATE} 23:59:59",
        ).fetchval()
        check.close()

        ok = (count == 1)
        print(f"  tx1_auto    : {'COMMIT' if results['tx1'][0] else 'REJECTED'} -> {results['tx1'][1]}")
        print(f"  tx2_approval: {'COMMIT' if results['tx2'][0] else 'REJECTED'} -> {results['tx2'][1]}")
        print(f"  Approved bookings after race: {count} (must be exactly 1) -> {'PASS' if ok else 'FAIL'}")

        teardown_conn = connect()
        delete_by_space(teardown_conn, space_id)
        delete_user(teardown_conn, user_id)
        delete_user(teardown_conn, staff_id)
        teardown_conn.close()

        if ok:
            passed += 1

    ok_all = (passed == ROUNDS)
    print(f"Scenario 1 summary: {passed}/{ROUNDS} rounds preserved the invariant -> "
          + ("PASS" if ok_all else "FAIL"))
    return ok_all


# ----------------------------------------------------------------------------
# Scenario 2: advisory maintenance does NOT block
# ----------------------------------------------------------------------------
def scenario_advisory():
    print("=" * 60)
    print("SCENARIO 2: advisory maintenance does not block booking (BR-12)")
    print("=" * 60)
    conn = connect()
    user_id = make_user(conn, "Advisory Test User", "advisory_test@school.edu", "Student")
    space_id = make_space(conn, "TEST-ADVISORY")
    make_maintenance(conn, space_id, "advisory", f"{TEST_DATE} 08:00:00", f"{TEST_DATE} 12:00:00")
    conn.commit()

    ok, status = execute_file(
        conn, os.path.join(BASE_DIR, "tx3_advisory_booking.sql"),
        {"USER_ID": user_id, "SPACE_ID": space_id, "TEST_DATE": TEST_DATE}, "AUTO_APPROVED")

    booking_id = conn.execute(
        "SELECT TOP 1 booking_id FROM dbo.bookings WHERE space_id = ? ORDER BY booking_id DESC;",
        space_id).fetchval()
    ack_count = conn.execute(
        "SELECT COUNT(*) FROM dbo.advisory_acknowledgements WHERE booking_id = ?;",
        booking_id).fetchval() if booking_id else 0
    staff_null = conn.execute(
        "SELECT COUNT(*) FROM dbo.approvals a JOIN dbo.bookings b ON b.booking_id = a.booking_id "
        "WHERE b.space_id = ? AND a.staff_id IS NULL;", space_id).fetchval()

    print(f"  tx3 booking   : {'AUTO_APPROVED' if ok else 'REJECTED'} -> {status}")
    print(f"  acknowledgement rows recorded: {ack_count} (must be >= 1) -> {'PASS' if ack_count >= 1 else 'FAIL'}")
    print(f"  approvals with staff_id NULL (auto actor): {staff_null} (must be 1) -> {'PASS' if staff_null == 1 else 'FAIL'}")

    result = ok and ack_count >= 1 and staff_null == 1
    delete_by_space(conn, space_id)
    delete_user(conn, user_id)
    conn.close()
    print(f"Scenario 2 -> {'PASS' if result else 'FAIL'}")
    return result


# ----------------------------------------------------------------------------
# Scenario 3: out-of-service maintenance DOES block
# ----------------------------------------------------------------------------
def scenario_oos():
    print("=" * 60)
    print("SCENARIO 3: out-of-service maintenance blocks booking (BR-11)")
    print("=" * 60)
    conn = connect()
    user_id = make_user(conn, "OOS Test User", "oos_test@school.edu", "Student")
    space_id = make_space(conn, "TEST-OOS")
    make_maintenance(conn, space_id, "out-of-service", f"{TEST_DATE} 08:00:00", f"{TEST_DATE} 12:00:00")
    conn.commit()

    ok, status = execute_file(
        conn, os.path.join(BASE_DIR, "tx4_oos_booking.sql"),
        {"USER_ID": user_id, "SPACE_ID": space_id, "TEST_DATE": TEST_DATE}, "AUTO_APPROVED")

    # The expected outcome is a clean rejection with OUT_OF_SERVICE.
    expected_blocked = (not ok) and status == "status=OUT_OF_SERVICE"
    booking_count = conn.execute(
        "SELECT COUNT(*) FROM dbo.bookings WHERE space_id = ?;", space_id).fetchval()

    print(f"  tx4 booking   : {'BLOCKED' if expected_blocked else ('COMMITTED!' if ok else 'REJECTED')} -> {status}")
    print(f"  bookings written on blocked space: {booking_count} (must be 0) -> {'PASS' if booking_count == 0 else 'FAIL'}")

    result = expected_blocked and booking_count == 0
    delete_by_space(conn, space_id)
    delete_user(conn, user_id)
    conn.close()
    print(f"Scenario 3 -> {'PASS' if result else 'FAIL'}")
    return result


# ----------------------------------------------------------------------------
# Scenario 4: duplicate incident reports consolidated into ONE maintenance record
# ----------------------------------------------------------------------------
def scenario_triage():
    print("=" * 60)
    print("SCENARIO 4: duplicate incident reports consolidate into one record (C8)")
    print("=" * 60)
    conn = connect()
    user1 = make_user(conn, "Reporter One", "reporter1@school.edu", "Student")
    user2 = make_user(conn, "Reporter Two", "reporter2@school.edu", "Student")
    staff = make_user(conn, "Triage Staff", "triage_staff@school.edu", "Facility Manager")
    space_id = make_space(conn, "TEST-INCIDENT")

    r1 = conn.execute(
        "INSERT INTO dbo.incident_reports (user_id, space_id, description) OUTPUT INSERTED.report_id "
        "VALUES (?, ?, N'Broken projector');", user1, space_id).fetchval()
    r2 = conn.execute(
        "INSERT INTO dbo.incident_reports (user_id, space_id, description) OUTPUT INSERTED.report_id "
        "VALUES (?, ?, N'Same broken projector (duplicate)');", user2, space_id).fetchval()
    r3 = conn.execute(
        "INSERT INTO dbo.incident_reports (user_id, space_id, description) OUTPUT INSERTED.report_id "
        "VALUES (?, ?, N'Third duplicate report');", user1, space_id).fetchval()
    conn.commit()

    def consolidate(report_ids_csv):
        cur = conn.cursor()
        cur.execute(
            "DECLARE @m INT; DECLARE @rs NVARCHAR(40); "
            "EXEC dbo.sp_consolidate_incident_reports @staff_id=?, @space_id=?, "
            "@problem_description=N'Projector replacement', @impact_level='out-of-service', "
            "@report_ids=?, @maintenance_id=@m OUTPUT, @result_status=@rs OUTPUT; "
            "SELECT @rs;", staff, space_id, report_ids_csv)
        # The procedure returns an intermediate result set (the locked report
        # ids); advance past it to the trailing `SELECT @rs;` status result.
        row = None
        while True:
            try:
                row = cur.fetchone()
            except pyodbc.Error:
                row = None
            if cur.nextset():
                continue
            break
        return row[0] if row is not None else None

    first = consolidate(f"{r1},{r2},{r3}")
    second = consolidate(f"{r2}")   # r2 already consolidated -> must be rejected

    maint_ids = conn.execute(
        "SELECT DISTINCT rc.maintenance_id FROM dbo.report_consolidations rc "
        "WHERE rc.incident_report_id IN (?, ?, ?);", r1, r2, r3).fetchall()
    distinct_records = len(maint_ids)

    print(f"  first consolidation : {first}")
    print(f"  duplicate attempt   : {second}")
    print(f"  distinct maintenance records for the reports: {distinct_records} (must be 1)")

    result = (first == "CONSOLIDATED" and second == "ALREADY_CONSOLIDATED"
              and distinct_records == 1)
    delete_by_space(conn, space_id)
    for uid in (user1, user2, staff):
        delete_user(conn, uid)
    conn.close()
    print(f"Scenario 4 -> {'PASS' if result else 'FAIL'}")
    return result


def main():
    results = {
        "Race (BR-01)": scenario_race(),
        "Advisory not blocking (BR-12)": scenario_advisory(),
        "Out-of-service blocking (BR-11)": scenario_oos(),
        "Incident consolidation (C8)": scenario_triage(),
    }
    print("=" * 60)
    for name, ok in results.items():
        print(f"{name:45s}: {'PASS' if ok else 'FAIL'}")
    if all(results.values()):
        print("SUCCESS: all concurrency invariants hold.")
    else:
        print("FAILED: one or more concurrency invariants were violated.")
        sys.exit(1)


if __name__ == "__main__":
    main()
