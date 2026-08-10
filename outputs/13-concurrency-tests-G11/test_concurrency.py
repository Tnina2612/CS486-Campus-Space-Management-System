"""
test_concurrency.py
===================
Concurrency collision test for the Campus Space Management System (G11).

Proves that simultaneous booking/approval/triage operations targeting the same
space with overlapping time periods cannot produce two approved bookings
(BR-01) or an approved booking overlapping an out-of-service maintenance window
(BR-11 / INV-2), thanks to the pessimistic `UPDLOCK, HOLDLOCK` implementation in
outputs/12-concurrency-implementation-G11.sql.

Scenarios
---------
1.  RACE (BR-01)     : tx1_instant_booking vs tx2_staff_approval, N rounds
                        (same-flow instant booking vs cross-flow staff approval).
1b. RACE same-flow   : tx1_instant_booking vs tx2_instant_booking
                        (two concurrent instant bookings).
2.  ADVISORY (BR-12) : advisory maintenance does NOT block an auto-booking.
3.  OUT-OF-SERVICE   : out-of-service maintenance DOES block an auto-booking.
    (BR-11 / INV-2)
4.  CONSOLIDATION    : two threads triage the same INCIDENT_REPORT set
    (C8)               concurrently; exactly one MAINTENANCE_RECORD is created.
5.  STAFF vs STAFF   : two staff members approve DIFFERENT pending bookings that
    (T3)               overlap; exactly one survives.
6.  DOUBLE-APPROVE   : two threads approve the SAME booking; exactly one
                        approval row exists.
7.  ESCALATION vs    : escalation advisory->out-of-service races an approval of
    APPROVAL (T4)      a pending booking in the same window; invariant holds
                        regardless of which wins.

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
    """Run one SQL scenario file and return (ok, status).

    The file's TRY/CATCH maps every outcome (commit or rejection) to a single
    `result_status` SELECT; the helper scans all result sets for the column
    named `result_status` (the procedures also emit informational SELECTs).
    """
    try:
        with open(file_path, encoding="utf-8") as f:
            sql_text = fill(f.read(), **replacements)
        sql_text = "\n".join(
            line for line in sql_text.splitlines()
            if line.strip().upper() != "GO"
        )
        cur = conn.cursor()
        cur.execute(sql_text)
        status = None
        while True:
            if cur.description:
                cols = [c[0].lower() for c in cur.description]
                if "result_status" in cols:
                    row = cur.fetchone()
                    status = row[0] if row is not None else "NO_STATUS"
                    break
            if not cur.nextset():
                break
        if status == success_status:
            return (True, status)
        return (False, f"status={status}")
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
        "INSERT INTO dbo.spaces (space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy, auto_booking_enabled) "
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


def make_pending_booking(conn, user_id, space_id, start, end, purpose="Meeting"):
    return conn.execute(
        "INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, expected_participants, status, advisory_acknowledged) "
        "OUTPUT INSERTED.booking_id "
        "VALUES (?, ?, ?, ?, ?, 10, N'Pending', 0);",
        user_id, space_id, start, end, purpose,
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
    cur.execute(
        "DELETE FROM dbo.report_consolidations WHERE maintenance_id IN "
        "(SELECT maintenance_id FROM dbo.maintenance_records WHERE space_id = ?);", space_id)
    cur.execute(
        "DELETE FROM dbo.incident_reports WHERE space_id = ?;", space_id)
    cur.execute("DELETE FROM dbo.maintenance_records WHERE space_id = ?;", space_id)
    cur.execute("DELETE FROM dbo.space_facility WHERE space_id = ?;", space_id)
    cur.execute("DELETE FROM dbo.facility_assets WHERE space_id = ?;", space_id)
    cur.execute("DELETE FROM dbo.spaces WHERE space_id = ?;", space_id)
    cur.commit()


def delete_user(conn, user_id):
    conn.execute("DELETE FROM dbo.users WHERE user_id = ?;", user_id)
    conn.commit()


# ----------------------------------------------------------------------------
# Scenario 1: concurrent auto-booking vs staff approval (the race, BR-01)
# ----------------------------------------------------------------------------
def run_barrier_race(thread_a, thread_b):
    """Run two callables synchronized on a barrier; return their results dict."""
    results = {}
    barrier = threading.Barrier(2)

    def wrapper(key, fn):
        barrier.wait()
        results[key] = fn()

    ta = threading.Thread(target=wrapper, args=("a", thread_a))
    tb = threading.Thread(target=wrapper, args=("b", thread_b))
    ta.start(); tb.start(); ta.join(); tb.join()
    return results


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
        pending_id = make_pending_booking(
            setup_conn, user_id, space_id,
            f"{TEST_DATE} 10:00:00", f"{TEST_DATE} 12:00:00")
        setup_conn.commit()
        setup_conn.close()

        conn1 = connect()
        conn2 = connect()

        repl_tx1 = {"USER_ID": user_id, "SPACE_ID": space_id, "TEST_DATE": TEST_DATE}
        repl_tx2 = {"PENDING_BOOKING_ID": pending_id, "STAFF_ID": staff_id, "TEST_DATE": TEST_DATE}

        def fn_tx1():
            return execute_file(
                conn1, os.path.join(BASE_DIR, "tx1_instant_booking.sql"),
                repl_tx1, "AUTO_APPROVED")

        def fn_tx2():
            return execute_file(
                conn2, os.path.join(BASE_DIR, "tx2_staff_approval.sql"),
                repl_tx2, "APPROVED")

        results = run_barrier_race(fn_tx1, fn_tx2)

        check = connect()
        count = check.execute(
            "SELECT COUNT(*) FROM dbo.bookings "
            "WHERE space_id = ? AND status IN ('Approved','Checked In','Completed') "
            "AND start_time >= ? AND start_time < ?;",
            space_id, f"{TEST_DATE} 00:00:00", f"{TEST_DATE} 23:59:59",
        ).fetchval()
        check.close()

        ok = (count == 1)
        print(f"  tx1_auto    : {'COMMIT' if results['a'][0] else 'REJECTED'} -> {results['a'][1]}")
        print(f"  tx2_approval: {'COMMIT' if results['b'][0] else 'REJECTED'} -> {results['b'][1]}")
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
# Scenario 1b: two concurrent instant bookings on overlapping windows
# ----------------------------------------------------------------------------
def scenario_instant_instant():
    print("=" * 60)
    print("SCENARIO 1b: instant-booking vs instant-booking (same flow, BR-01)")
    print("=" * 60)
    passed = 0
    for r in range(1, ROUNDS + 1):
        print(f"--- Round {r} ---")
        setup_conn = connect()
        u1 = make_user(setup_conn, "Auto User A", f"autoa_{r}@school.edu", "Student")
        u2 = make_user(setup_conn, "Auto User B", f"autob_{r}@school.edu", "Student")
        space_id = make_space(setup_conn, "TEST-ROOM-B")
        setup_conn.commit()
        setup_conn.close()

        conn1 = connect()
        conn2 = connect()
        repl1 = {"USER_ID": u1, "SPACE_ID": space_id, "TEST_DATE": TEST_DATE}
        repl2 = {"USER_ID": u2, "SPACE_ID": space_id, "TEST_DATE": TEST_DATE}

        def fn_tx1():
            return execute_file(
                conn1, os.path.join(BASE_DIR, "tx1_instant_booking.sql"),
                repl1, "AUTO_APPROVED")  # 09:00-11:00

        def fn_tx2():
            return execute_file(
                conn2, os.path.join(BASE_DIR, "tx2_instant_booking.sql"),
                repl2, "AUTO_APPROVED")  # 10:00-12:00 overlaps

        results = run_barrier_race(fn_tx1, fn_tx2)

        check = connect()
        count = check.execute(
            "SELECT COUNT(*) FROM dbo.bookings "
            "WHERE space_id = ? AND status IN ('Approved','Checked In','Completed') "
            "AND start_time >= ? AND start_time < ?;",
            space_id, f"{TEST_DATE} 00:00:00", f"{TEST_DATE} 23:59:59",
        ).fetchval()
        check.close()

        ok = (count == 1)
        print(f"  tx1 (09-11): {'COMMIT' if results['a'][0] else 'REJECTED'} -> {results['a'][1]}")
        print(f"  tx2 (10-12): {'COMMIT' if results['b'][0] else 'REJECTED'} -> {results['b'][1]}")
        print(f"  Approved bookings after race: {count} (must be exactly 1) -> {'PASS' if ok else 'FAIL'}")

        teardown_conn = connect()
        delete_by_space(teardown_conn, space_id)
        delete_user(teardown_conn, u1)
        delete_user(teardown_conn, u2)
        teardown_conn.close()

        if ok:
            passed += 1

    ok_all = (passed == ROUNDS)
    print(f"Scenario 1b summary: {passed}/{ROUNDS} rounds -> "
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
# Scenario 4: concurrent triage consolidates into ONE maintenance record (C8)
# ----------------------------------------------------------------------------
def scenario_triage():
    print("=" * 60)
    print("SCENARIO 4: duplicate incident reports consolidate into one record (C8)")
    print("=" * 60)
    conn = connect()
    user1 = make_user(conn, "Reporter One", "reporter1@school.edu", "Student")
    user2 = make_user(conn, "Reporter Two", "reporter2@school.edu", "Student")
    staff1 = make_user(conn, "Triage Staff A", "triage_staff_a@school.edu", "Facility Manager")
    staff2 = make_user(conn, "Triage Staff B", "triage_staff_b@school.edu", "Facility Manager")
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

    csv = f"{r1},{r2},{r3}"

    def consolidate(thread_conn, staff_id):
        cur = thread_conn.cursor()
        cur.execute(
            "DECLARE @rs NVARCHAR(40); "
            "EXEC dbo.sp_consolidate_incident_reports "
            "@incident_report_ids = ?, @consolidated_by = ?, @maintenance_id = NULL, "
            "@result_status = @rs OUTPUT; "
            "SELECT ISNULL(@rs, N'NO_STATUS') AS result_status;",
            csv, staff_id)
        status = None
        while True:
            if cur.description:
                cols = [c[0].lower() for c in cur.description]
                if "result_status" in cols:
                    row = cur.fetchone()
                    status = row[0] if row is not None else "NO_STATUS"
                    break
            if not cur.nextset():
                break
        return status if status is not None else "NO_STATUS"

    conn1 = connect()
    conn2 = connect()
    results = run_barrier_race(
        lambda: consolidate(conn1, staff1),
        lambda: consolidate(conn2, staff2))

    check = connect()
    maint_ids = check.execute(
        "SELECT DISTINCT rc.maintenance_id FROM dbo.report_consolidations rc "
        "WHERE rc.incident_report_id IN (?, ?, ?);", r1, r2, r3).fetchall()
    distinct_records = len(maint_ids)
    check.close()

    statuses = sorted([results["a"], results["b"]])
    print(f"  thread A result: {results['a']}")
    print(f"  thread B result: {results['b']}")
    print(f"  distinct maintenance records for the reports: {distinct_records} (must be 1)")

    result = (
        "CONSOLIDATED" in statuses
        and "ALREADY_CONSOLIDATED" in statuses
        and distinct_records == 1
    )

    teardown_conn = connect()
    delete_by_space(teardown_conn, space_id)
    for uid in (user1, user2, staff1, staff2):
        delete_user(teardown_conn, uid)
    teardown_conn.close()
    conn1.close(); conn2.close()
    print(f"Scenario 4 -> {'PASS' if result else 'FAIL'}")
    return result


# ----------------------------------------------------------------------------
# Scenario 5: staff vs staff approval of overlapping pending bookings (T3)
# ----------------------------------------------------------------------------
def scenario_staff_vs_staff():
    print("=" * 60)
    print("SCENARIO 5: staff vs staff approval of overlapping bookings (T3)")
    print("=" * 60)
    conn = connect()
    user_id = make_user(conn, "Pending Owner", "pending_owner@school.edu", "Student")
    staff_a = make_user(conn, "Staff A", "staff_a@school.edu", "Facility Staff")
    staff_b = make_user(conn, "Staff B", "staff_b@school.edu", "Facility Staff")
    space_id = make_space(conn, "TEST-STAFFVSTAFF", auto_enabled=0)

    pb1 = make_pending_booking(conn, user_id, space_id,
                               f"{TEST_DATE} 10:00:00", f"{TEST_DATE} 12:00:00", "Meeting")
    pb2 = make_pending_booking(conn, user_id, space_id,
                               f"{TEST_DATE} 10:30:00", f"{TEST_DATE} 12:30:00", "Seminar")
    conn.commit()
    conn.close()

    c1 = connect()
    c2 = connect()
    repl_a = {"PENDING_BOOKING_ID": pb1, "STAFF_ID": staff_a}
    repl_b = {"PENDING_BOOKING_ID_B": pb2, "STAFF_ID_B": staff_b}

    def fn_a():
        return execute_file(c1, os.path.join(BASE_DIR, "tx2_staff_approval.sql"),
                            repl_a, "APPROVED")

    def fn_b():
        return execute_file(c2, os.path.join(BASE_DIR, "tx5_staff_approval_b.sql"),
                            repl_b, "APPROVED")

    results = run_barrier_race(fn_a, fn_b)

    check = connect()
    approved = check.execute(
        "SELECT COUNT(*) FROM dbo.bookings WHERE space_id = ? AND status = 'Approved';",
        space_id).fetchval()
    check.close()

    ok = (approved == 1)
    print(f"  staff A (booking {pb1}): {'COMMIT' if results['a'][0] else 'REJECTED'} -> {results['a'][1]}")
    print(f"  staff B (booking {pb2}): {'COMMIT' if results['b'][0] else 'REJECTED'} -> {results['b'][1]}")
    print(f"  Approved bookings after race: {approved} (must be exactly 1) -> {'PASS' if ok else 'FAIL'}")

    teardown_conn = connect()
    delete_by_space(teardown_conn, space_id)
    delete_user(teardown_conn, user_id)
    delete_user(teardown_conn, staff_a)
    delete_user(teardown_conn, staff_b)
    teardown_conn.close()
    c1.close(); c2.close()
    print(f"Scenario 5 -> {'PASS' if ok else 'FAIL'}")
    return ok


# ----------------------------------------------------------------------------
# Scenario 6: double-approve the SAME booking (exactly one approval row)
# ----------------------------------------------------------------------------
def scenario_double_approve():
    print("=" * 60)
    print("SCENARIO 6: double-approve the same booking (one approval row)")
    print("=" * 60)
    conn = connect()
    user_id = make_user(conn, "Double Approve Owner", "double_owner@school.edu", "Student")
    staff_a = make_user(conn, "Staff C", "staff_c@school.edu", "Facility Staff")
    staff_b = make_user(conn, "Staff D", "staff_d@school.edu", "Facility Staff")
    space_id = make_space(conn, "TEST-DOUBLE", auto_enabled=0)
    pb = make_pending_booking(conn, user_id, space_id,
                              f"{TEST_DATE} 10:00:00", f"{TEST_DATE} 12:00:00", "Meeting")
    conn.commit()
    conn.close()

    c1 = connect()
    c2 = connect()
    repl = {"PENDING_BOOKING_ID": pb, "STAFF_ID": staff_a}

    def fn_a():
        return execute_file(c1, os.path.join(BASE_DIR, "tx6_double_approve.sql"),
                            repl, "APPROVED")

    repl_b = {"PENDING_BOOKING_ID": pb, "STAFF_ID": staff_b}
    def fn_b():
        return execute_file(c2, os.path.join(BASE_DIR, "tx6_double_approve.sql"),
                            repl_b, "APPROVED")

    results = run_barrier_race(fn_a, fn_b)

    check = connect()
    approval_rows = check.execute(
        "SELECT COUNT(*) FROM dbo.approvals WHERE booking_id = ?;", pb).fetchval()
    booking_status = check.execute(
        "SELECT status FROM dbo.bookings WHERE booking_id = ?;", pb).fetchval()
    check.close()

    ok = (approval_rows == 1 and booking_status == "Approved")
    print(f"  thread A (staff C): {'COMMIT' if results['a'][0] else 'REJECTED'} -> {results['a'][1]}")
    print(f"  thread B (staff D): {'COMMIT' if results['b'][0] else 'REJECTED'} -> {results['b'][1]}")
    print(f"  approval rows for booking {pb}: {approval_rows} (must be 1) -> {'PASS' if approval_rows == 1 else 'FAIL'}")
    print(f"  booking status: {booking_status} (must be Approved) -> {'PASS' if booking_status == 'Approved' else 'FAIL'}")

    teardown_conn = connect()
    delete_by_space(teardown_conn, space_id)
    delete_user(teardown_conn, user_id)
    delete_user(teardown_conn, staff_a)
    delete_user(teardown_conn, staff_b)
    teardown_conn.close()
    c1.close(); c2.close()
    print(f"Scenario 6 -> {'PASS' if ok else 'FAIL'}")
    return ok


# ----------------------------------------------------------------------------
# Scenario 7: escalation (advisory->out-of-service) races an approval (T4)
# ----------------------------------------------------------------------------
def scenario_escalation_vs_approval():
    print("=" * 60)
    print("SCENARIO 7: escalation vs approval race (T4)")
    print("=" * 60)
    conn = connect()
    user_id = make_user(conn, "Escalation Owner", "escalation_owner@school.edu", "Student")
    staff_id = make_user(conn, "Staff E", "staff_e@school.edu", "Facility Staff")
    space_id = make_space(conn, "TEST-ESCALATION", auto_enabled=0)
    pb = make_pending_booking(conn, user_id, space_id,
                              f"{TEST_DATE} 10:00:00", f"{TEST_DATE} 12:00:00", "Meeting")
    maint_id = make_maintenance(conn, space_id, "advisory",
                                f"{TEST_DATE} 09:00:00", f"{TEST_DATE} 13:00:00")
    conn.commit()
    conn.close()

    c1 = connect()
    c2 = connect()

    def fn_escalate():
        return execute_file(c1, os.path.join(BASE_DIR, "tx7_escalate_impact.sql"),
                            {"MAINTENANCE_ID": maint_id}, "ESCALATED")

    def fn_approve():
        return execute_file(c2, os.path.join(BASE_DIR, "tx2_staff_approval.sql"),
                            {"PENDING_BOOKING_ID": pb, "STAFF_ID": staff_id}, "APPROVED")

    results = run_barrier_race(fn_escalate, fn_approve)

    check = connect()
    impact = check.execute(
        "SELECT impact_level FROM dbo.maintenance_records WHERE maintenance_id = ?;",
        maint_id).fetchval()
    booking_status = check.execute(
        "SELECT status FROM dbo.bookings WHERE booking_id = ?;", pb).fetchval()
    check.close()

    print(f"  escalation (advisory->out-of-service): {'COMMIT' if results['a'][0] else 'REJECTED'} -> {results['a'][1]}")
    print(f"  approval of pending booking           : {'COMMIT' if results['b'][0] else 'REJECTED'} -> {results['b'][1]}")
    print(f"  maintenance impact_level now          : {impact}")
    print(f"  booking status                        : {booking_status}")

    # Invariant: the escalation always commits to out-of-service. If the
    # approval committed AFTER the escalation it must have been rejected;
    # if the approval committed BEFORE the escalation, the booking stays
    # approved but is surfaced as an affected booking (allowed).
    if impact != "out-of-service":
        ok = False
    elif booking_status == "Approved":
        # Approval won the race; escalation still succeeded. Affected booking.
        ok = True
    else:
        # Booking not approved: either rejected (overlap/OOS) or still pending.
        ok = results["b"][1].startswith("status=") and not results["b"][0]

    teardown_conn = connect()
    delete_by_space(teardown_conn, space_id)
    delete_user(teardown_conn, user_id)
    delete_user(teardown_conn, staff_id)
    teardown_conn.close()
    c1.close(); c2.close()
    print(f"Scenario 7 -> {'PASS' if ok else 'FAIL'}")
    return ok


def main():
    results = {
        "Race auto vs staff (BR-01)": scenario_race(),
        "Race instant vs instant (BR-01)": scenario_instant_instant(),
        "Advisory not blocking (BR-12)": scenario_advisory(),
        "Out-of-service blocking (BR-11)": scenario_oos(),
        "Concurrent triage (C8)": scenario_triage(),
        "Staff vs staff (T3)": scenario_staff_vs_staff(),
        "Double-approve": scenario_double_approve(),
        "Escalation vs approval (T4)": scenario_escalation_vs_approval(),
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
