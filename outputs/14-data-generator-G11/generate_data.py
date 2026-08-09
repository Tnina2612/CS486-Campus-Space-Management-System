"""
generate_data.py
================
Large-scale data generator for the Campus Space Management System.

Seeds the migrated Phase 1 + Phase 2 schema (outputs/05-db-definition-G11.sql,
outputs/06-sample-data-G11.sql, outputs/10-schema-migration-G11.sql) with
100,000+ records so the analytical queries
(outputs/16-analytical-queries-G11.sql) and the index-tuning report
(outputs/15-index-tuning-report-G11.md) run against a realistic,
semester-sized workload.

Data characteristics
--------------------
* Users, spaces and the facility catalog are generated first (FK parents).
* Bookings are scheduled on a NON-OVERLAPPING time grid per space for the
  approved-like states (BR-01: a space cannot have two approved bookings that
  overlap). Pending / Rejected / Cancelled / No-show rows share the same
  disjoint grid, so the grid is valid for every status.
* OUT-OF-SERVICE maintenance (RC-01) blocks the space: booking slots that
  overlap an out-of-service maintenance window are excluded from the grid.
  ADVISORY maintenance does not block; bookings that overlap an advisory
  window are flagged with advisory_acknowledged = 1 and their
  advisory_acknowledgements rows are recorded (RC-03).
* Approvals are produced for every decided booking (Approved / Checked In /
  Completed / No-show get an approval; Rejected get an approval with a
  rejection reason). Pending / Cancelled bookings get none.
* Usage sessions are produced for Checked In / Completed bookings.
* Facility assets are inserted BEFORE space_facility so the
  TRG_ValidateFacilityQuantity trigger (trackable quantity <= asset count)
  is never violated.
* The facility catalog is seeded idempotently (a facility name already present
  is not inserted again), so re-runs do not duplicate catalog rows.

Usage
-----
    python generate_data.py [--seed N] [--users N] [--spaces N]
                            [--bookings N] [--maintenance N] [--reset]

Connections use the same environment variables as the concurrency tests:
MSSQL_SERVER / MSSQL_DATABASE / MSSQL_USER / MSSQL_PASSWORD / MSSQL_DRIVER /
MSSQL_WINDOWS_AUTH. Options not given on the command line are read from
config.json (when present), otherwise from the built-in defaults below.

Prerequisites: see requirements.txt / README.md.
"""

import argparse
import datetime as dt
import json
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
DRIVER = os.environ.get("MSSQL_DRIVER", "ODBC Driver 18 for SQL Server")
USE_WINDOWS_AUTH = os.environ.get("MSSQL_WINDOWS_AUTH", "0") == "1"
TRUST_CERT = os.environ.get("MSSQL_TRUST_CERT", "0") == "1"

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(BASE_DIR, "config.json")

SEMESTER_START = dt.datetime(2026, 1, 5, 8, 0, 0)    # matches Q1 window
SEMESTER_END = dt.datetime(2026, 4, 30, 18, 0, 0)
WORKING_HOURS = list(range(8, 18))                   # 08:00-17:00 starts
SLOT_DURATIONS_MIN = [45, 50, 55, 60]                # <=60 keeps hourly grid disjoint

ROLES = (
    "Student", "Lecturer", "Teaching Assistant", "Facility Staff",
    "Department Administrator", "Facility Manager",
)
ROLE_WEIGHTS = (0.70, 0.10, 0.08, 0.06, 0.04, 0.02)
STAFF_ROLES = ("Facility Staff", "Department Administrator", "Facility Manager")

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
MAINT_STATUSES = ("Completed", "Completed", "Completed", "Completed",
                  "Completed", "Completed", "Open", "In Progress")
IMPACT_LEVELS = ("advisory", "advisory", "out-of-service", "out-of-service")

FINAL_CONDITIONS = ("Clean and tidy", "Clean with minor wear",
                    "Needs cleaning", "Equipment reported", "In good order")
USAGE_NOTES = ("Lecture ran to schedule", "Equipment used without incident",
               "Microphone reported faulty", "Normal usage",
               "Poster session, removed all materials")


def default_options():
    if os.path.exists(CONFIG_PATH):
        with open(CONFIG_PATH, encoding="utf-8") as f:
            cfg = json.load(f)
        return {
            "seed": int(cfg.get("seed", 11)),
            "users": int(cfg.get("users", 3000)),
            "spaces": int(cfg.get("spaces", 400)),
            "bookings": int(cfg.get("bookings", 100_000)),
            "maintenance": int(cfg.get("maintenance", 8000)),
            "batch_size": int(cfg.get("batch_size", 5000)),
        }
    return {"seed": 11, "users": 3000, "spaces": 400,
            "bookings": 100_000, "maintenance": 8000, "batch_size": 5000}


def conn_str(database=DATABASE):
    trust = ";TrustServerCertificate=yes" if TRUST_CERT else ""
    if USE_WINDOWS_AUTH:
        return (f"DRIVER={{{DRIVER}}};SERVER={SERVER};DATABASE={database};"
                f"Trusted_Connection=yes{trust};")
    return (f"DRIVER={{{DRIVER}}};SERVER={SERVER};DATABASE={database};"
            f"UID={USERNAME};PWD={PASSWORD}{trust};")


def connect():
    conn = pyodbc.connect(conn_str(), autocommit=False)
    conn.cursor().execute("SET NOCOUNT ON;")
    return conn


def table_max(conn, table, pk):
    return conn.cursor().execute(
        f"SELECT ISNULL(MAX({pk}), 0) FROM dbo.{table}").fetchval()


def insert_batches(conn, table, columns, rows, batch_size):
    """Insert rows via fast executemany in batch_size-sized chunks."""
    if not rows:
        return
    cur = conn.cursor()
    placeholders = ",".join("?" * len(columns))
    sql = f"INSERT INTO dbo.{table} ({','.join(columns)}) VALUES ({placeholders})"
    for i in range(0, len(rows), batch_size):
        cur.fast_executemany = True
        cur.executemany(sql, rows[i:i + batch_size])
    conn.commit()


def read_ids(conn, table, pk, low, where):
    """Read back generated identity ids above a baseline that match a marker.

    Do NOT assume IDENTITY values are contiguous: after a --reset the identity
    counter keeps advancing, so `id > base AND id <= base+count` is unsafe.
    Rows are instead identified by a stable marker predicate (e.g. the
    gen.user.* email / GEN-* code prefixes). `low` is the pre-run baseline so
    ids from an earlier run are never mixed in.
    """
    if not where:
        return []
    cur = conn.cursor()
    cur.execute(f"SELECT {pk} FROM dbo.{table} WHERE {pk} > ? AND {where} "
                f"ORDER BY {pk}", low)
    return [r[0] for r in cur.fetchall()]


def reset_generated(conn):
    """Delete rows created by a previous generator run (reverse FK order).

    Only rows that carry generator markers are removed:
      * users with email gen.user.*@campus.edu
      * spaces with space_code LIKE 'GEN-%'
      * children of those spaces (bookings, maintenance, assets, facility)
      * facility_catalog rows that are generator-only (not referenced by any
        remaining space_facility / facility_assets row)
    Phase 1 sample data is preserved.
    """
    cur = conn.cursor()
    gen_space_ids = (
        f"(SELECT space_id FROM dbo.spaces WHERE space_code LIKE 'GEN-%')")
    print("Resetting previously generated rows ...")
    cur.execute(f"""
        DELETE FROM dbo.advisory_acknowledgements
        WHERE booking_id IN (SELECT booking_id FROM dbo.bookings
                             WHERE space_id IN {gen_space_ids})
           OR maintenance_id IN (SELECT maintenance_id FROM dbo.maintenance_records
                                 WHERE space_id IN {gen_space_ids})
    """)
    cur.execute(f"""
        DELETE FROM dbo.approvals
        WHERE booking_id IN (SELECT booking_id FROM dbo.bookings
                             WHERE space_id IN {gen_space_ids})
    """)
    cur.execute(f"""
        DELETE FROM dbo.usage_sessions
        WHERE booking_id IN (SELECT booking_id FROM dbo.bookings
                             WHERE space_id IN {gen_space_ids})
    """)
    cur.execute(f"DELETE FROM dbo.bookings WHERE space_id IN {gen_space_ids}")
    cur.execute(f"""
        DELETE FROM dbo.maintenance_records WHERE space_id IN {gen_space_ids}
    """)
    cur.execute(f"DELETE FROM dbo.space_facility WHERE space_id IN {gen_space_ids}")
    cur.execute(f"DELETE FROM dbo.facility_assets WHERE space_id IN {gen_space_ids}")
    cur.execute(f"DELETE FROM dbo.spaces WHERE space_code LIKE 'GEN-%'")
    cur.execute(f"DELETE FROM dbo.users WHERE email LIKE 'gen.user.%@campus.edu'")
    # Any facility_catalog row no longer referenced by space_facility /
    # facility_assets is generator residue. Phase 1 sample catalog rows are all
    # referenced by the sample space_facility mappings, so they are preserved.
    cur.execute("""
        DELETE FROM dbo.facility_catalog
        WHERE NOT EXISTS (SELECT 1 FROM dbo.space_facility sf
                          WHERE sf.catalog_id = dbo.facility_catalog.catalog_id)
          AND NOT EXISTS (SELECT 1 FROM dbo.facility_assets fa
                          WHERE fa.catalog_id = dbo.facility_catalog.catalog_id)
    """)
    conn.commit()


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
    """count spaces with unique space_code and the RC-05 AutoBookingEnabled flag."""
    rows = []
    for i in range(count):
        stype, lo_cap, hi_cap = rng.choice(SPACE_TYPES)
        building = rng.choice(BUILDINGS)
        floor = rng.randint(1, 6)
        room = rng.randint(1, 99)
        code = f"GEN-{i:05d}"
        status = rng.choices(SPACE_STATUSES, SPACE_STATUS_WEIGHTS)[0]
        auto = 1 if (status == "Available" and rng.random() < 0.30) else 0
        rows.append((
            code, f"{stype} {building} {floor}-{room}", stype, building,
            floor, f"{room}", rng.randint(lo_cap, hi_cap), status,
            None, auto,
        ))
    return rows


def seed_catalog(conn, batch_size):
    """Idempotently seed the facility catalog; return [(catalog_id, is_trackable)]."""
    cur = conn.cursor()
    existing = set()
    for row in cur.execute("SELECT facility_name FROM dbo.facility_catalog"):
        existing.add(row[0])
    to_add = [(name, track) for name, track in CATALOG if name not in existing]
    if to_add:
        sql = ("INSERT INTO dbo.facility_catalog (facility_name, is_trackable) "
               "VALUES (?, ?)")
        for i in range(0, len(to_add), batch_size):
            chunk = to_add[i:i + batch_size]
            cur.fast_executemany = True
            cur.executemany(sql, chunk)
        conn.commit()
    cur.execute("SELECT catalog_id, is_trackable FROM dbo.facility_catalog")
    return [(r[0], r[1]) for r in cur.fetchall()]


def gen_assets(rng, spaces, catalogs, batch_size, conn):
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
        chosen = rng.sample(trackable, k=min(rng.randint(1, 3), len(trackable)))
        for catalog_id, _ in chosen:
            n = rng.randint(1, 8)
            for _ in range(n):
                tag += 1
                asset_rows.append((
                    f"GEN-{tag:06d}", space_id, catalog_id,
                    rng.choice(ASSET_STATUSES),
                ))
            per_space[(space_id, catalog_id)] = n
        if len(asset_rows) >= batch_size:
            insert_batches(conn, "facility_assets",
                           ["asset_tag", "space_id", "catalog_id", "status"],
                           asset_rows, batch_size)
            asset_rows = []
    insert_batches(conn, "facility_assets",
                   ["asset_tag", "space_id", "catalog_id", "status"],
                   asset_rows, batch_size)
    return per_space


def gen_space_facility(rng, space_ids, catalogs, assets_per_space):
    """space_facility rows. Trackable quantity == asset count (trigger-safe);
    non-trackable quantity is free-form."""
    rows = []
    non_trackable = [c for c in catalogs if c[1] == 0]
    for space_id in space_ids:
        extras = rng.sample(non_trackable, k=min(rng.randint(1, 4), len(non_trackable)))
        for catalog_id, _ in extras:
            rows.append((space_id, catalog_id, rng.randint(1, 12)))
    for (space_id, catalog_id), n in assets_per_space.items():
        rows.append((space_id, catalog_id, n))
    return rows


def gen_maintenance(rng, user_ids, space_ids, staff_ids, count):
    """Maintenance records with Phase 2 impact_level (RC-01)."""
    rows = []
    span_days = (SEMESTER_END - SEMESTER_START).days
    for _ in range(count):
        space_id = rng.choice(space_ids)
        start = SEMESTER_START + dt.timedelta(
            days=rng.randint(0, span_days),
            hours=rng.randint(0, 10))
        status = rng.choice(MAINT_STATUSES)
        impact = rng.choice(IMPACT_LEVELS)
        if status == "Completed":
            completion = start + dt.timedelta(days=rng.randint(1, 7),
                                              hours=rng.randint(1, 8))
            result = f"Fixed: {rng.choice(FINAL_CONDITIONS)}"
        else:
            completion = None
            result = None
        rows.append((
            space_id, rng.choice(user_ids),
            rng.choice(staff_ids) if staff_ids else None,
            rng.choice(MAINT_PROBLEMS), start, completion, status, result,
            impact,
        ))
    return rows


def out_of_service_windows(maint_rows):
    """
    Build per-space blocking windows from out-of-service maintenance.
    A record still active if its completion_time is NULL (open) or after the
    semester window start. Returns {space_id: [(start, end), ...]} where end
    is the completion_time or the semester end.
    """
    windows = {}
    for (space_id, reporter, staff, problem, start, completion, status,
         result, impact) in maint_rows:
        if impact != "out-of-service":
            continue
        end = completion if completion is not None else SEMESTER_END
        if end <= start:
            end = start + dt.timedelta(hours=2)
        windows.setdefault(space_id, []).append((start, end))
    return windows


def advisory_windows(maint_ids, maint_rows):
    """Per-space advisory maintenance windows (start, end, problem, maint_id)."""
    windows = {}
    for maint_id, (space_id, reporter, staff, problem, start, completion,
                   status, result, impact) in zip(maint_ids, maint_rows):
        if impact != "advisory":
            continue
        end = completion if completion is not None else SEMESTER_END
        if end <= start:
            end = start + dt.timedelta(hours=2)
        windows.setdefault(space_id, []).append((start, end, problem, maint_id))
    return windows


def overlaps(win_start, win_end, start, end):
    return win_start < end and win_end > start


def build_time_grid(rng, oos_windows, space_id):
    """
    Deterministic per-space non-overlapping slot grid that avoids every
    out-of-service maintenance window (RC-01). Each slot = (start, end).
    Slots are disjoint for one space so BR-01 holds. Iterates every
    (day, start-hour) combination EXACTLY once.
    """
    slots = []
    span_days = (SEMESTER_END - SEMESTER_START).days
    blocked = oos_windows.get(space_id, [])
    for day in range(span_days):
        for start_hour in WORKING_HOURS:
            dur = rng.choice(SLOT_DURATIONS_MIN)
            start = SEMESTER_START + dt.timedelta(days=day,
                                                  hours=start_hour - 8)
            end = start + dt.timedelta(minutes=dur)
            if end > SEMESTER_END or end.hour > 18:
                continue
            if any(overlaps(start, end, bs, be) for bs, be in blocked):
                continue
            slots.append((start, end))
    return slots


def gen_bookings(rng, user_ids, space_ids, space_capacities, oos_windows,
                 adv_windows, count):
    """count bookings scheduled on non-overlapping per-space grids."""
    rows = []
    grids = {}
    pool = list(range(len(space_ids)))
    i = 0
    while i < count and pool:
        rng.shuffle(pool)
        progressed = False
        for si in pool:
            if i >= count:
                break
            space_id = space_ids[si]
            if space_id not in grids:
                grids[space_id] = build_time_grid(rng, oos_windows, space_id)
                rng.shuffle(grids[space_id])
            if not grids[space_id]:
                continue
            progressed = True
            start, end = grids[space_id].pop()
            user_id = rng.choice(user_ids)
            status = rng.choices(BOOKING_STATUSES, BOOKING_STATUS_WEIGHTS)[0]
            purpose = rng.choice(PURPOSES)
            cap = space_capacities[si]
            expected = rng.randint(1, max(1, cap))
            if purpose == "Lecture" and cap >= 20:
                expected = rng.randint(int(cap * 0.6), cap)
            # RC-03: acknowledge when an advisory maintenance overlaps the window
            advisories = adv_windows.get(space_id, [])
            overlapping = [w for w in advisories if overlaps(start, end, w[0], w[1])]
            ack = 0
            snapshot = None
            if overlapping and status in LOCKED_STATUSES and rng.random() < 0.60:
                ack = 1
                snapshot = "; ".join(w[2] for w in overlapping[:5])
            rows.append((
                user_id, space_id, start, end, purpose, expected, status,
                ack, snapshot,
            ))
            i += 1
        if not progressed:
            break
    return rows


def gen_acknowledgements(booking_ids, booking_rows, adv_windows):
    """
    RC-03: for every booking with advisory_acknowledged = 1, record one
    advisory_acknowledgements row per overlapping advisory maintenance record.
    acknowledged_by is the booking's requester; acknowledged_at is the booking
    start time.
    """
    rows = []
    for booking_id, (user_id, space_id, start, end, purpose, expected,
                     status, ack, snap) in zip(booking_ids, booking_rows):
        if ack != 1:
            continue
        for w in adv_windows.get(space_id, []):
            if overlaps(start, end, w[0], w[1]):
                rows.append((booking_id, w[3], user_id, start))
    return rows

def gen_approvals(rng, booking_rows, user_ids, staff_ids, booking_ids):
    """One approval per decided booking (Approved/Checked In/Completed/No-show
    approve; Rejected records the rejection reason)."""
    rows = []
    staff = staff_ids if staff_ids else user_ids
    for booking_id, (user_id, space_id, start, end, purpose, expected,
                     status, ack, snap) in zip(booking_ids, booking_rows):
        if status in ("Pending", "Cancelled"):
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


# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
def main():
    opts = default_options()
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--users", type=int, default=None)
    ap.add_argument("--spaces", type=int, default=None)
    ap.add_argument("--bookings", type=int, default=None)
    ap.add_argument("--maintenance", type=int, default=None)
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--batch-size", type=int, default=None)
    ap.add_argument("--reset", action="store_true",
                    help="delete previously generated rows first")
    args = ap.parse_args()

    seed = args.seed if args.seed is not None else opts["seed"]
    n_users = args.users if args.users is not None else opts["users"]
    n_spaces = args.spaces if args.spaces is not None else opts["spaces"]
    n_bookings = args.bookings if args.bookings is not None else opts["bookings"]
    n_maint = args.maintenance if args.maintenance is not None else opts["maintenance"]
    batch_size = args.batch_size if args.batch_size is not None else opts["batch_size"]

    rng = random.Random(seed)
    total_rows = (n_users + n_spaces + n_bookings + n_maint + len(CATALOG) + 4000)
    print(f"Generating ~{total_rows:,} rows "
          f"(users={n_users}, spaces={n_spaces}, "
          f"bookings={n_bookings}, maintenance={n_maint}, seed={seed}).")
    if total_rows < 100_000:
        print("WARNING: totals below 100,000 rows; raise --bookings/--spaces.")

    conn = connect()
    try:
        if args.reset:
            reset_generated(conn)

        # ---- baseline ids (allows re-running without truncation) ----
        base_user = table_max(conn, "users", "user_id")
        base_space = table_max(conn, "spaces", "space_id")
        base_asset = table_max(conn, "facility_assets", "asset_id")
        base_sf = table_max(conn, "space_facility", "space_id")
        base_booking = table_max(conn, "bookings", "booking_id")
        base_approval = table_max(conn, "approvals", "approval_id")
        base_session = table_max(conn, "usage_sessions", "session_id")
        base_maint = table_max(conn, "maintenance_records", "maintenance_id")
        base_ack = table_max(conn, "advisory_acknowledgements",
                             "acknowledgement_id")

        # ---- 1. users ----
        print("Seeding users ...")
        user_rows = gen_users(rng, n_users)
        insert_batches(conn, "users",
                       ["full_name", "email", "phone_number", "role",
                        "department", "account_status"], user_rows, batch_size)
        user_ids = read_ids(conn, "users", "user_id", base_user,
                            "email LIKE 'gen.user.%@campus.edu'")
        cur = conn.cursor()
        role_cur = cur.execute(
            f"SELECT user_id FROM dbo.users WHERE user_id > ? AND role IN (?,?,?) "
            f"ORDER BY user_id", base_user, *STAFF_ROLES)
        staff_ids = [r[0] for r in role_cur.fetchall()]
        if not staff_ids:
            staff_ids = user_ids[::100]
        print(f"  staff ids available: {len(staff_ids)}")

        # ---- 2. spaces ----
        print("Seeding spaces ...")
        space_rows = gen_spaces(rng, n_spaces)
        insert_batches(conn, "spaces",
                       ["space_code", "space_name", "space_type", "building",
                        "floor", "room_number", "capacity", "current_status",
                        "usage_policy", "AutoBookingEnabled"], space_rows,
                       batch_size)
        space_ids = read_ids(conn, "spaces", "space_id", base_space,
                             "space_code LIKE 'GEN-%'")
        space_caps = [r[6] for r in space_rows]

        # ---- 3. facility_catalog (idempotent) ----
        print("Seeding facility catalog ...")
        catalogs = seed_catalog(conn, batch_size)

        # ---- 4. facility_assets (BEFORE space_facility for trigger) ----
        print("Seeding facility assets ...")
        assets_per_space = gen_assets(
            rng, [(sid, r[0], r[2]) for sid, r in zip(space_ids, space_rows)],
            catalogs, batch_size, conn)

        # ---- 5. space_facility ----
        print("Seeding space_facility ...")
        sf_rows = gen_space_facility(rng, space_ids, catalogs, assets_per_space)
        insert_batches(conn, "space_facility",
                       ["space_id", "catalog_id", "quantity"], sf_rows,
                       batch_size)

        # ---- 6. maintenance_records (BEFORE bookings so OOS blocks grid) ----
        print("Seeding maintenance records ...")
        maint_rows = gen_maintenance(rng, user_ids, space_ids, staff_ids,
                                     n_maint)
        insert_batches(conn, "maintenance_records",
                       ["space_id", "reporter_id", "assigned_staff_id",
                        "problem_description", "start_time", "completion_time",
                        "status", "result_note", "impact_level"], maint_rows,
                       batch_size)
        maint_ids = read_ids(conn, "maintenance_records", "maintenance_id",
                             base_maint,
                             "space_id IN (SELECT space_id FROM dbo.spaces "
                             "WHERE space_code LIKE 'GEN-%')")

        # ---- 7. bookings (non-overlapping grid, avoids OOS maintenance) ----
        print("Seeding bookings ...")
        oos_windows = out_of_service_windows(maint_rows)
        adv_windows = advisory_windows(maint_ids, maint_rows)
        booking_rows = gen_bookings(
            rng, user_ids, space_ids, space_caps, oos_windows, adv_windows,
            n_bookings)
        insert_batches(conn, "bookings",
                       ["user_id", "space_id", "start_time", "end_time",
                        "purpose", "expected_participants", "status",
                        "advisory_acknowledged", "advisory_snapshot"],
                       booking_rows, batch_size)
        booking_ids = read_ids(conn, "bookings", "booking_id",
                               base_booking,
                               "space_id IN (SELECT space_id FROM dbo.spaces "
                               "WHERE space_code LIKE 'GEN-%')")

        # ---- 8. advisory_acknowledgements (RC-03) ----
        print("Seeding advisory acknowledgements ...")
        ack_rows = gen_acknowledgements(booking_ids, booking_rows, adv_windows)
        insert_batches(conn, "advisory_acknowledgements",
                       ["booking_id", "maintenance_id", "acknowledged_by",
                        "acknowledged_at"], ack_rows, batch_size)

        # ---- 9. approvals ----
        print("Seeding approvals ...")
        approval_rows = gen_approvals(rng, booking_rows, user_ids, staff_ids,
                                      booking_ids)
        insert_batches(conn, "approvals",
                       ["booking_id", "staff_id", "decision_time",
                        "decision_note", "rejection_reason"], approval_rows,
                       batch_size)

        # ---- 10. usage_sessions ----
        print("Seeding usage sessions ...")
        session_rows = gen_usage_sessions(rng, booking_rows, staff_ids,
                                          booking_ids)
        insert_batches(conn, "usage_sessions",
                       ["booking_id", "staff_id", "actual_start_time",
                        "actual_end_time", "initial_condition",
                        "final_condition", "usage_notes"], session_rows,
                       batch_size)

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
                      ("maintenance_records", "maintenance_id"),
                      ("advisory_acknowledgements", "acknowledgement_id")):
            cur.execute(f"SELECT COUNT(*) FROM dbo.{t}")
            summary[t] = cur.fetchval()
        print("\nSeeding complete. Row counts:")
        for t, n in summary.items():
            print(f"  {t:30s} {n:>10,}")
        print(f"\nTotal rows in schema: {sum(summary.values()):,}")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
