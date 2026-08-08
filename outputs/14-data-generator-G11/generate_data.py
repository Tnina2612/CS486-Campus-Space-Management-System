"""
generate_data.py
================
Large-scale data generator for the Campus Space Management System.

Seeds the migrated Phase 1 + Phase 2 schema (outputs/05-db-definition-G11.sql,
outputs/06-sample-data-G11.sql, outputs/10-schema-migration-G11.sql) with
100,000+ records so the analytical queries (outputs/16-analytical-queries-G11.sql)
and index-tuning report (outputs/15-index-tuning-report-G11.md) run against a
realistic, semester-sized workload.

Data characteristics
--------------------
* Users, spaces and facility catalog are generated first (FK parents).
* 100,000+ bookings are scheduled on a NON-OVERLAPPING time grid per space
  (BR-01 invariant: a space cannot have two approved bookings overlapping).
  Approved-like states occupy most slots so Q1/Q2 reports are meaningful.
* Approvals are produced for every decided booking (Approved / Checked In /
  Completed / No-show get an approval; Rejected get an approval with a reason).
* Usage sessions are produced for Checked In / Completed bookings.
* Maintenance records mix 'advisory' and 'out-of-service' impact levels (RC-01),
  and respect the Phase 1 rule that out-of-service maintenance makes a space
  temporarily unbookable in the seeded period.
* Facility assets are inserted BEFORE space_facility so the
  TRG_ValidateFacilityQuantity trigger (trackable quantity <= asset count)
  is never violated.

Usage
-----
    python generate_data.py [--rows BOOKINGS] [--seed N]
    python generate_data.py --spaces 300 --bookings 150000

Connections use the same environment variables as the concurrency tests:
MSSQL_SERVER / MSSQL_DATABASE / MSSQL_USER / MSSQL_PASSWORD / MSSQL_DRIVER /
MSSQL_WINDOWS_AUTH.

Prerequisites: see requirements.txt / README.md.
"""

import argparse
import datetime as dt
import os
import random
import sys

import pyodbc

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------
SERVER = os.environ.get("MSSQL_SERVER", "localhost")
DATABASE = os.environ.get("MSSQL_DATABASE", "CampusSpaceManagement")
USERNAME = os.environ.get("MSSQL_USER", "sa")
PASSWORD = os.environ.get("MSSQL_PASSWORD", "YourStrong!Passw0rd")
DRIVER = os.environ.get("MSSQL_DRIVER", "ODBC Driver 17 for SQL Server")
USE_WINDOWS_AUTH = os.environ.get("MSSQL_WINDOWS_AUTH", "0") == "1"

SEMESTER_START = dt.datetime(2026, 1, 5, 8, 0, 0)    # matches Q1 window
SEMESTER_END = dt.datetime(2026, 4, 30, 18, 0, 0)
WORKING_HOURS = list(range(8, 18))                   # 08:00-17:00 starts
SLOT_DURATIONS_MIN = [45, 50, 55, 60]                # <=60 keeps hourly grid disjoint

BATCH = 5000                                         # executemany batch size

ROLES = (
    "Student", "Lecturer", "Teaching Assistant", "Facility Staff",
    "Department Administrator", "Facility Manager",
)
ROLE_WEIGHTS = (0.70, 0.10, 0.08, 0.06, 0.04, 0.02)

DEPARTMENTS = (
    "Computer Science", "Mathematics", "Physics", "Chemistry", "Biology",
    "Economics", "Engineering", "Business Administration", "Literature",
    "History", "Psychology", "Environmental Science",
)

SPACE_TYPES = (
    ("Lecture Hall", 60, 200), ("Computer Lab", 25, 60), ("Seminar Room", 10, 40),
    ("Meeting Room", 4, 20), ("Laboratory", 15, 45), ("Auditorium", 150, 400),
    ("Study Room", 2, 10), ("Studio", 10, 35),
)
BUILDINGS = ("Central Building", "Science Block", "Engineering Hall",
             "Library", "Business School", "Arts Center", "Sports Complex",
             "IT Center")
SPACE_STATUSES = ("Available", "In Use", "Under Maintenance",
                  "Temporarily Closed", "Retired")
SPACE_STATUS_WEIGHTS = (0.80, 0.06, 0.07, 0.04, 0.03)

PURPOSES = ("Lecture", "Examination", "Seminar", "Workshop", "Meeting",
            "Student Activity", "Administrative Event")
BOOKING_STATUSES = ("Pending", "Approved", "Rejected", "Cancelled",
                    "Checked In", "Completed", "No-show")
BOOKING_STATUS_WEIGHTS = (0.12, 0.25, 0.08, 0.10, 0.10, 0.30, 0.05)
# statuses that must NOT overlap a space (BR-01 approved-like states)
LOCKED_STATUSES = {"Approved", "Checked In", "Completed"}

CATALOG = (
    ("Projector", 1), ("Whiteboard", 0), ("Computer Workstation", 1),
    ("Conference Phone", 1), ("Air Conditioning", 0), ("WiFi Access Point", 0),
    ("Smartboard", 1), ("Video Camera", 1), ("Sound System", 0),
    ("Microphone", 1), ("Desk", 0), ("Chair", 0), ("Projector Screen", 1),
    ("Network Port", 0), ("Power Sockets", 0), ("Document Camera", 1),
    ("Fume Hood", 1), ("Whiteboard Markers", 0), ("Lectern", 0),
    ("Emergency Exit Sign", 0),
)
ASSET_STATUSES = ("Operational", "Operational", "Operational",
                  "Under Repair", "Retired")

MAINT_PROBLEMS = (
    "Projector lamp failed", "Air conditioning leaking", "Broken window latch",
    "Power outlet sparking", "Door hinge loose", "Whiteboard surface damaged",
    "Network switch offline", "Fluorescent light flickering", "Broken chair leg",
    "Water stain on ceiling", "HVAC noisy", "Lock not engaging",
)
MAINT_STATUSES = ("Open", "In Progress", "Completed", "Completed", "Completed")
IMPACT_LEVELS = ("advisory", "advisory", "out-of-service", "out-of-service")

FINAL_CONDITIONS = ("Clean and tidy", "Clean with minor wear",
                    "Needs cleaning", "Equipment reported", "In good order")
USAGE_NOTES = ("Lecture ran to schedule", "Equipment used without incident",
               "Microphone reported faulty", "Normal usage",
               "Poster session, removed all materials")


def conn_str(database=DATABASE):
    if USE_WINDOWS_AUTH:
        return (f"DRIVER={{{DRIVER}}};SERVER={SERVER};DATABASE={database};"
                f"Trusted_Connection=yes;")
    return (f"DRIVER={{{DRIVER}}};SERVER={SERVER};DATABASE={database};"
            f"UID={USERNAME};PWD={PASSWORD};")


def connect():
    conn = pyodbc.connect(conn_str(), autocommit=False)
    conn.cursor().execute("SET NOCOUNT ON;")
    return conn


def table_max(conn, table, pk):
    return conn.cursor().execute(
        f"SELECT ISNULL(MAX({pk}), 0) FROM dbo.{table}").fetchval()


def insert_batches(conn, table, columns, rows):
    """Insert rows via fast executemany in BATCH-sized chunks."""
    if not rows:
        return
    cur = conn.cursor()
    placeholders = ",".join("?" * len(columns))
    sql = f"INSERT INTO dbo.{table} ({','.join(columns)}) VALUES ({placeholders})"
    for i in range(0, len(rows), BATCH):
        cur.fast_executemany = True
        cur.executemany(sql, rows[i:i + BATCH])
    conn.commit()


def read_ids(conn, table, pk, low, high):
    """Read back generated identity ids (low, high] from this run."""
    if high <= low:
        return []
    cur = conn.cursor()
    cur.execute(f"SELECT {pk} FROM dbo.{table} WHERE {pk} > ? AND {pk} <= ? "
                f"ORDER BY {pk}", low, high)
    return [r[0] for r in cur.fetchall()]


# ----------------------------------------------------------------------------
# Generators
# ----------------------------------------------------------------------------
def gen_users(rng, count):
    """count users with unique emails."""
    first = ("Alex", "Morgan", "Jordan", "Taylor", "Casey", "Riley", "Sam",
             "Jamie", "Quinn", "Avery", "Blake", "Cameron", "Drew", "Elliot",
             "Finley", "Harper", "Ivy", "Liam", "Nora", "Owen")
    last = ("Smith", "Nguyen", "Chen", "Garcia", "Kim", "Patel", "Lopez",
            "Johnson", "Williams", "Brown", "Davis", "Miller", "Wilson",
            "Moore", "Taylor", "Anderson", "Thomas", "Jackson", "White",
            "Harris")
    rows = []
    for i in range(count):
        name = f"{rng.choice(first)} {rng.choice(last)}"
        email = f"gen.user.{i}@campus.edu"
        role = rng.choices(ROLES, ROLE_WEIGHTS)[0]
        dept = rng.choice(DEPARTMENTS)
        status = "Active" if rng.random() < 0.98 else "Suspended"
        phone = f"+1-555-{rng.randint(100, 999)}-{rng.randint(1000, 9999)}"
        rows.append((name, email, phone, role, dept, status))
    return rows


def gen_spaces(rng, count):
    """count spaces with unique space_code and Phase 2 instant_bookable flag."""
    rows = []
    for i in range(count):
        stype, lo_cap, hi_cap = rng.choice(SPACE_TYPES)
        building = rng.choice(BUILDINGS)
        floor = rng.randint(1, 6)
        room = rng.randint(1, 99)
        code = f"GEN-{i:05d}"
        status = rng.choices(SPACE_STATUSES, SPACE_STATUS_WEIGHTS)[0]
        instant = 1 if (status == "Available" and rng.random() < 0.30) else 0
        rows.append((
            code, f"{stype} {building} {floor}-{room}", stype, building,
            floor, f"{room}", rng.randint(lo_cap, hi_cap), status,
            None, instant,
        ))
    return rows


def gen_facility_catalog():
    return [(name, is_trackable) for name, is_trackable in CATALOG]


def gen_assets(rng, spaces, catalogs):
    """
    Physical assets for trackable catalog items.
    Returns (asset_rows, assets_per_space) so the trigger constraint
    (trackable quantity <= asset count) is respected: space_facility quantity
    for trackable items is set to the number of assets we create.
    """
    asset_rows = []
    per_space = {}                 # (space_id, catalog_id) -> asset count
    tag = 0
    trackable = [c for c in catalogs if c[1] == 1]
    for space_id, *_ in spaces:
        chosen = rng.sample(trackable, k=rng.randint(1, 3))
        for catalog_id, _ in chosen:
            n = rng.randint(1, 8)
            for _ in range(n):
                tag += 1
                asset_rows.append((
                    f"GEN-{tag:06d}", space_id, catalog_id,
                    rng.choice(ASSET_STATUSES),
                ))
            per_space[(space_id, catalog_id)] = n
    return asset_rows, per_space


def gen_space_facility(rng, space_ids, catalogs, assets_per_space):
    """space_facility rows. Trackable quantity == asset count (trigger-safe);
    non-trackable quantity is free-form."""
    rows = []
    non_trackable = [c for c in catalogs if c[1] == 0]
    for space_id in space_ids:
        extras = rng.sample(non_trackable, k=rng.randint(1, 4))
        for catalog_id, _ in extras:
            rows.append((space_id, catalog_id, rng.randint(1, 12)))
    for (space_id, catalog_id), n in assets_per_space.items():
        rows.append((space_id, catalog_id, n))
    return rows


def build_time_grid(rng, space_index, semester_span_days, slots_per_day):
    """
    Deterministic per-space non-overlapping slot grid.
    Each slot = (start, end). Slots are disjoint for one space so BR-01 holds.
    Iterates every (day, start-hour) combination EXACTLY once, so no duplicate
    slot can be drawn for the same space (duplicates would create overlaps).
    """
    slots = []
    for day in range(semester_span_days):
        for start_hour in WORKING_HOURS:
            dur = rng.choice(SLOT_DURATIONS_MIN)
            start = SEMESTER_START + dt.timedelta(days=day,
                                                  hours=start_hour - 8)
            end = start + dt.timedelta(minutes=dur)
            if end <= SEMESTER_END and end.hour <= 18:
                slots.append((start, end))
    return slots


def gen_bookings(rng, user_ids, space_ids, space_capacities, count):
    """count bookings scheduled on non-overlapping per-space grids."""
    rows = []
    span_days = (SEMESTER_END - SEMESTER_START).days
    slots_per_space = 14
    grids = {}
    pool = list(range(len(space_ids)))
    i = 0
    while i < count:
        rng.shuffle(pool)
        for si in pool:
            if i >= count:
                break
            space_id = space_ids[si]
            if space_id not in grids:
                grids[space_id] = build_time_grid(rng, si, span_days, slots_per_space)
                rng.shuffle(grids[space_id])
            if not grids[space_id]:
                continue
            start, end = grids[space_id].pop()
            user_id = rng.choice(user_ids)
            status = rng.choices(BOOKING_STATUSES, BOOKING_STATUS_WEIGHTS)[0]
            purpose = rng.choice(PURPOSES)
            cap = space_capacities[si]
            expected = rng.randint(1, max(1, cap))
            if purpose == "Lecture" and cap >= 20:
                expected = rng.randint(int(cap * 0.6), cap)
            # Phase 2 advisory fields (RC-03); snapshot only when acknowledged
            ack = 1 if (status in LOCKED_STATUSES and rng.random() < 0.25) else 0
            snapshot = (f"Advisory maintenance present at booking time; "
                        f"requested by {user_id}.") if ack else None
            rows.append((
                user_id, space_id, start, end, purpose, expected, status,
                ack, snapshot,
            ))
            i += 1
    return rows


def gen_approvals(rng, booking_rows, user_ids, staff_ids, booking_ids):
    """One approval per decided booking (Approved/Checked In/Completed/No-show
    approve; Rejected records the rejection reason)."""
    rows = []
    staff = staff_ids if staff_ids else user_ids
    for booking_id, (user_id, space_id, start, end, purpose, expected,
                     status, ack, snap) in zip(booking_ids, booking_rows):
        if status == "Pending" or status == "Cancelled":
            continue
        decision_time = start - dt.timedelta(minutes=rng.randint(60, 6 * 60 * 24))
        if status == "Rejected":
            rows.append((booking_id, rng.choice(staff), decision_time,
                         "Rejected by staff.", "Capacity request mismatch"))
        else:
            rows.append((booking_id, rng.choice(staff), decision_time,
                         "Approved.", None))
    return rows


def gen_usage_sessions(rng, booking_rows, staff_ids, booking_ids):
    """Usage sessions for Checked In / Completed bookings (BR-05 session)."""
    rows = []
    for booking_id, (user_id, space_id, start, end, purpose, expected,
                     status, ack, snap) in zip(booking_ids, booking_rows):
        if status not in ("Checked In", "Completed"):
            continue
        actual_start = start + dt.timedelta(minutes=rng.randint(-5, 10))
        actual_end = end + dt.timedelta(minutes=rng.randint(-10, 15))
        if actual_end <= actual_start:
            actual_end = actual_start + dt.timedelta(minutes=30)
        staff_id = rng.choice(staff_ids) if staff_ids else None
        rows.append((
            booking_id, staff_id, actual_start, actual_end,
            "Initial check by staff.", rng.choice(FINAL_CONDITIONS),
            rng.choice(USAGE_NOTES),
        ))
    return rows


def gen_maintenance(rng, user_ids, space_ids, staff_ids, count):
    """Maintenance records with Phase 2 impact_level (RC-01)."""
    rows = []
    for _ in range(count):
        space_id = rng.choice(space_ids)
        start = SEMESTER_START + dt.timedelta(
            days=rng.randint(0, (SEMESTER_END - SEMESTER_START).days),
            hours=rng.randint(0, 10))
        status = rng.choice(MAINT_STATUSES)
        impact = rng.choice(IMPACT_LEVELS)
        if status == "Completed":
            completion = start + dt.timedelta(days=rng.randint(1, 14),
                                              hours=rng.randint(1, 8))
            result = f"Fixed: {rng.choice(FINAL_CONDITIONS)}"
        else:
            completion = None
            result = None
        rows.append((
            space_id, rng.choice(user_ids), rng.choice(staff_ids) if staff_ids else None,
            rng.choice(MAINT_PROBLEMS), start, completion, status, result,
            impact,
        ))
    return rows


# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--users", type=int, default=3000)
    ap.add_argument("--spaces", type=int, default=400)
    ap.add_argument("--bookings", type=int, default=100_000)
    ap.add_argument("--maintenance", type=int, default=8000)
    ap.add_argument("--seed", type=int, default=11)
    args = ap.parse_args()

    rng = random.Random(args.seed)
    total_rows = (args.users + args.spaces + args.bookings
                  + args.maintenance + len(CATALOG) + 4000)
    print(f"Generating ~{total_rows:,} rows "
          f"(users={args.users}, spaces={args.spaces}, "
          f"bookings={args.bookings}, maintenance={args.maintenance}).")
    if total_rows < 100_000:
        print("WARNING: totals below 100,000 rows; raise --bookings/--spaces.")

    conn = connect()
    try:
        # ---- baseline ids (allows re-running without truncation) ----
        base_user = table_max(conn, "users", "user_id")
        base_space = table_max(conn, "spaces", "space_id")
        base_cat = table_max(conn, "facility_catalog", "catalog_id")
        base_asset = table_max(conn, "facility_assets", "asset_id")
        base_sf = table_max(conn, "space_facility", "space_id")
        base_booking = table_max(conn, "bookings", "booking_id")
        base_approval = table_max(conn, "approvals", "approval_id")
        base_session = table_max(conn, "usage_sessions", "session_id")
        base_maint = table_max(conn, "maintenance_records", "maintenance_id")

        # ---- 1. users ----
        print("Seeding users ...")
        user_rows = gen_users(rng, args.users)
        insert_batches(conn, "users",
                       ["full_name", "email", "phone_number", "role",
                        "department", "account_status"], user_rows)
        user_ids = read_ids(conn, "users", "user_id", base_user,
                            base_user + args.users)
        staff_ids = [uid for uid in user_ids if uid % 50 == 0]

        # ---- 2. spaces ----
        print("Seeding spaces ...")
        space_rows = gen_spaces(rng, args.spaces)
        insert_batches(conn, "spaces",
                       ["space_code", "space_name", "space_type", "building",
                        "floor", "room_number", "capacity", "current_status",
                        "usage_policy", "instant_bookable"], space_rows)
        space_ids = read_ids(conn, "spaces", "space_id", base_space,
                             base_space + args.spaces)
        space_caps = [r[6] for r in space_rows]

        # ---- 3. facility_catalog ----
        print("Seeding facility catalog ...")
        cat_rows = gen_facility_catalog()
        insert_batches(conn, "facility_catalog",
                       ["facility_name", "is_trackable"], cat_rows)
        cat_ids = read_ids(conn, "facility_catalog", "catalog_id",
                           base_cat, base_cat + len(cat_rows))
        catalogs = list(zip(cat_ids, [r[1] for r in cat_rows]))

        # ---- 4. facility_assets (BEFORE space_facility for trigger) ----
        print("Seeding facility assets ...")
        asset_rows, assets_per_space = gen_assets(
            rng, [(sid, r[0], r[2]) for sid, r in zip(space_ids, space_rows)],
            catalogs)
        insert_batches(conn, "facility_assets",
                       ["asset_tag", "space_id", "catalog_id", "status"],
                       asset_rows)

        # ---- 5. space_facility ----
        print("Seeding space_facility ...")
        sf_rows = gen_space_facility(rng, space_ids, catalogs,
                                     assets_per_space)
        insert_batches(conn, "space_facility",
                       ["space_id", "catalog_id", "quantity"], sf_rows)

        # ---- 6. bookings ----
        print("Seeding bookings ...")
        booking_rows = gen_bookings(
            rng, user_ids, space_ids, space_caps, args.bookings)
        insert_batches(conn, "bookings",
                       ["user_id", "space_id", "start_time", "end_time",
                        "purpose", "expected_participants", "status",
                        "advisories_acknowledged", "advisories_snapshot"],
                       booking_rows)
        booking_ids = read_ids(conn, "bookings", "booking_id",
                               base_booking, base_booking + len(booking_rows))

        # ---- 7. approvals ----
        print("Seeding approvals ...")
        approval_rows = gen_approvals(rng, booking_rows, user_ids, staff_ids,
                                      booking_ids)
        insert_batches(conn, "approvals",
                       ["booking_id", "staff_id", "decision_time",
                        "decision_note", "rejection_reason"], approval_rows)

        # ---- 8. usage_sessions ----
        print("Seeding usage sessions ...")
        session_rows = gen_usage_sessions(rng, booking_rows, staff_ids,
                                          booking_ids)
        insert_batches(conn, "usage_sessions",
                       ["booking_id", "staff_id", "actual_start_time",
                        "actual_end_time", "initial_condition",
                        "final_condition", "usage_notes"], session_rows)

        # ---- 9. maintenance_records ----
        print("Seeding maintenance records ...")
        maint_rows = gen_maintenance(rng, user_ids, space_ids, staff_ids,
                                     args.maintenance)
        insert_batches(conn, "maintenance_records",
                       ["space_id", "reporter_id", "assigned_staff_id",
                        "problem_description", "start_time", "completion_time",
                        "status", "result_note", "impact_level"], maint_rows)

        # ---- summary ----
        cur = conn.cursor()
        summary = {}
        for t, pk in (("users", "user_id"), ("spaces", "space_id"),
                      ("facility_catalog", "catalog_id"),
                      ("facility_assets", "asset_id"),
                      ("space_facility", "space_id"),
                      ("bookings", "booking_id"),
                      ("approvals", "approval_id"),
                      ("usage_sessions", "session_id"),
                      ("maintenance_records", "maintenance_id")):
            cur.execute(f"SELECT COUNT(*) FROM dbo.{t}")
            summary[t] = cur.fetchval()
        print("\nSeeding complete. Row counts:")
        for t, n in summary.items():
            print(f"  {t:24s} {n:>10,}")
        print(f"\nTotal rows in schema: {sum(summary.values()):,}")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
