"""
generate-data.py
================
Large-scale, reproducible Phase 2 data generator for the Campus Space
Management System (G11).

Generates synthetic users, spaces, facilities, assets, bookings, approvals,
usage sessions, maintenance records, incident reports, report consolidations
and advisory acknowledgements that obey every schema constraint and the Phase 2
business rules (BR-01 no-overlap, BR-02 booking blocking, BR-11 advisory
acknowledgement, BR-12 impact-level triage).

Preserves existing Phase 1 data:
  * The generator NEVER deletes pre-existing rows.
  * Generated rows are tagged so a re-run is idempotent:
      - users     : email ends with '@gen.school.edu'
      - spaces    : space_code starts with 'GEN-'
      - children  : reference the generated parents only
  * All IDs are explicit (computed from MAX(id)+1 per table) and inserted with
    SET IDENTITY_INSERT so FKs never point at non-existent parents.

Design choices
--------------
  * Fixed random seed (config.json) -> reproducible output.
  * Committed bookings (Approved / Checked In / Completed / No-show) are placed
    on disjoint time slots per space, so BR-01 holds by construction.
  * Committed bookings never overlap an out-of-service maintenance window
    (slots overlapping such a window are skipped) -> BR-11/INV-2 holds.
  * Committed bookings that DO overlap an advisory maintenance window get
    advisory_acknowledged = 1, a snapshot, and an ADVISORY_ACKNOWLEDGEMENTS row
    per overlapping advisory -> BR-11 holds.
  * Trackable facility quantity == number of assets for that instance, so the
    TRG_ValidateFacilityQuantity trigger is satisfied.

Usage
-----
    python generate-data.py [--reset] [--config config.json]

    --reset : delete previously generated rows (reverse FK order) first.
              Safe: only touches GEN-*/@gen.school.edu rows.

Prerequisites: see README.md.
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
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

SERVER = os.environ.get("MSSQL_SERVER", "localhost")
DATABASE = os.environ.get("MSSQL_DATABASE", "CampusSpaceManagement")
USERNAME = os.environ.get("MSSQL_USER", "sa")
PASSWORD = os.environ.get("MSSQL_PASSWORD", "YourStrong!Passw0rd")
DRIVER = os.environ.get("MSSQL_DRIVER", "ODBC Driver 18 for SQL Server")
USE_WINDOWS_AUTH = os.environ.get("MSSQL_WINDOWS_AUTH", "0") == "1"
TRUST_CERT = os.environ.get("MSSQL_TRUST_CERT", "0") == "1"


def conn_str():
    extra = "TrustServerCertificate=yes;" if TRUST_CERT else ""
    if USE_WINDOWS_AUTH:
        return (
            f"DRIVER={{{DRIVER}}};SERVER={SERVER};DATABASE={DATABASE};"
            f"Trusted_Connection=yes;{extra}"
        )
    return (
        f"DRIVER={{{DRIVER}}};SERVER={SERVER};DATABASE={DATABASE};"
        f"UID={USERNAME};PWD={PASSWORD};{extra}"
    )


# ----------------------------------------------------------------------------
# Constant reference data
# ----------------------------------------------------------------------------
ROLE_COUNTS = {}   # filled from config
DEPARTMENTS = [
    "Computer Science", "Data Science", "Software Eng",
    "Artificial Intelligence", "Facilities", "School Office",
]

SPACE_TYPES = [
    "Auditorium", "Classroom", "Computer Laboratory",
    "Project Laboratory", "Meeting Room", "Student Workspace",
]
BUILDINGS = [
    "Ada Lovelace Bldg", "Knuth Bldg", "Hopper Bldg", "Turing Bldg",
    "Babbage Bldg",
]
SPACE_TYPE_CAPACITY = {
    "Auditorium": (100, 300),
    "Classroom": (30, 80),
    "Computer Laboratory": (20, 40),
    "Project Laboratory": (10, 25),
    "Meeting Room": (4, 16),
    "Student Workspace": (15, 60),
}
SPACE_TYPE_POLICY = {
    "Auditorium": "Lectures, seminars, examinations and public events",
    "Classroom": "Lectures and tutorials only",
    "Computer Laboratory": "Programming labs and workshops",
    "Project Laboratory": "Student projects and research activities",
    "Meeting Room": "Meetings and administrative events",
    "Student Workspace": "Open student use, clubs and study groups",
}
AUTO_BOOKING_TYPES = {"Classroom", "Meeting Room", "Student Workspace", "Computer Laboratory"}

PURPOSES = [
    "Lecture", "Examination", "Seminar", "Workshop",
    "Meeting", "Student Activity", "Administrative Event",
]

# Fixed facility catalog entries used by the generator. Rows already present in
# the database are reused; any missing ones are inserted explicitly.
FACILITY_CATALOG = [
    ("Projector", 1),
    ("Whiteboard", 0),
    ("Microphone System", 1),
    ("Computer Workstation", 1),
    ("Livestreaming Kit", 1),
    ("Air Conditioner Unit", 0),
    ("Conference Phone", 1),
    ("Smart Board", 1),
    ("Document Camera", 1),
    ("Speaker System", 1),
    ("Video Conference Unit", 1),
    ("Network Equipment", 0),
]

MAINTENANCE_STATUSES = ["Reported", "Assigned", "In Progress", "Open", "Completed"]
ASSET_STATUSES = ["Good", "Good", "Good", "Good", "Needs Repair", "Out of Service"]
BOOKING_PURPOSES = {
    "Auditorium": ["Lecture", "Seminar", "Examination", "Workshop", "Administrative Event"],
    "Classroom": ["Lecture", "Seminar", "Examination", "Workshop"],
    "Computer Laboratory": ["Lecture", "Workshop", "Examination"],
    "Project Laboratory": ["Workshop", "Student Activity"],
    "Meeting Room": ["Meeting", "Administrative Event", "Seminar"],
    "Student Workspace": ["Student Activity", "Workshop", "Meeting"],
}

# Disjoint daily time blocks -> committed bookings never overlap (BR-01).
TIME_BLOCKS = [
    (8, 10), (10, 12), (13, 15), (15, 17), (17, 19),
]

INCIDENT_DESCRIPTIONS = [
    "Broken projector, image flickering",
    "Air conditioning not cooling",
    "Damaged whiteboard surface",
    "Network outlet dead near window",
    "Workstation will not boot",
    "Microphone feedback on left channel",
    "Chair damaged in row C",
    "Conference phone not connecting",
    "Lights flickering",
    "Smart board calibration off",
    "Speaker system buzzing",
    "Door lock faulty",
]

USAGE_NOTES = [
    "Finished on time", "Cleaning requested", "Projector bulb flickering",
    "No issues", "Markers left uncapped", "Minor cleanup needed",
    "Event went smoothly", "Hardware issue reported",
]


# ----------------------------------------------------------------------------
# DB helpers
# ----------------------------------------------------------------------------
class DB:
    def __init__(self):
        self.conn = pyodbc.connect(conn_str())
        self.conn.autocommit = False
        self.cur = self.conn.cursor()
        self.cur.fast_executemany = True

    def close(self):
        try:
            self.conn.close()
        except Exception:
            pass

    def commit(self):
        self.conn.commit()

    def rollback(self):
        self.conn.rollback()

    def max_id(self, table, id_col):
        row = self.cur.execute(
            f"SELECT ISNULL(MAX({id_col}), 0) FROM dbo.{table}").fetchone()
        return int(row[0])

    def insert(self, table, id_col, columns, rows):
        """Bulk insert with explicit identity IDs."""
        if not rows:
            return
        col_list = ", ".join(columns)
        placeholders = ", ".join(["?"] * len(columns))
        sql = f"INSERT INTO dbo.{table} ({col_list}) VALUES ({placeholders})"
        self.cur.execute(f"SET IDENTITY_INSERT dbo.{table} ON;")
        self.cur.executemany(sql, rows)
        self.cur.execute(f"SET IDENTITY_INSERT dbo.{table} OFF;")


def reset_generated(db, cursor):
    """Delete previously generated rows in reverse FK order. Only touches
    GEN-* / @gen.school.edu rows (Phase 1 data is preserved)."""
    print("Reset: removing previously generated rows (GEN-* / @gen.school.edu)...")
    stmts = [
        "DELETE a FROM dbo.advisory_acknowledgements a "
        "WHERE a.booking_id IN (SELECT booking_id FROM dbo.bookings WHERE space_id IN "
        "(SELECT space_id FROM dbo.spaces WHERE space_code LIKE 'GEN-%'));",
        "DELETE a FROM dbo.advisory_acknowledgements a "
        "WHERE a.maintenance_id IN (SELECT maintenance_id FROM dbo.maintenance_records WHERE space_id IN "
        "(SELECT space_id FROM dbo.spaces WHERE space_code LIKE 'GEN-%'));",
        "DELETE rc FROM dbo.report_consolidations rc "
        "WHERE rc.incident_report_id IN (SELECT report_id FROM dbo.incident_reports WHERE space_id IN "
        "(SELECT space_id FROM dbo.spaces WHERE space_code LIKE 'GEN-%'));",
        "DELETE rc FROM dbo.report_consolidations rc "
        "WHERE rc.maintenance_id IN (SELECT maintenance_id FROM dbo.maintenance_records WHERE space_id IN "
        "(SELECT space_id FROM dbo.spaces WHERE space_code LIKE 'GEN-%'));",
        "DELETE FROM dbo.incident_reports WHERE space_id IN "
        "(SELECT space_id FROM dbo.spaces WHERE space_code LIKE 'GEN-%');",
        "DELETE u FROM dbo.usage_sessions u WHERE u.booking_id IN "
        "(SELECT booking_id FROM dbo.bookings WHERE space_id IN "
        "(SELECT space_id FROM dbo.spaces WHERE space_code LIKE 'GEN-%'));",
        "DELETE ap FROM dbo.approvals ap WHERE ap.booking_id IN "
        "(SELECT booking_id FROM dbo.bookings WHERE space_id IN "
        "(SELECT space_id FROM dbo.spaces WHERE space_code LIKE 'GEN-%'));",
        "DELETE FROM dbo.bookings WHERE space_id IN "
        "(SELECT space_id FROM dbo.spaces WHERE space_code LIKE 'GEN-%');",
        "DELETE FROM dbo.maintenance_records WHERE space_id IN "
        "(SELECT space_id FROM dbo.spaces WHERE space_code LIKE 'GEN-%');",
        "DELETE fa FROM dbo.facility_assets fa WHERE fa.space_id IN "
        "(SELECT space_id FROM dbo.spaces WHERE space_code LIKE 'GEN-%');",
        "DELETE sf FROM dbo.space_facility sf WHERE sf.space_id IN "
        "(SELECT space_id FROM dbo.spaces WHERE space_code LIKE 'GEN-%');",
        "DELETE FROM dbo.spaces WHERE space_code LIKE 'GEN-%';",
        "DELETE FROM dbo.users WHERE email LIKE '%@gen.school.edu';",
    ]
    for s in stmts:
        cursor.execute(s)
    db.commit()


# ----------------------------------------------------------------------------
# Data builders
# ----------------------------------------------------------------------------
def build_catalog(db, rng):
    """Reuse existing facility_catalog rows; add missing required entries."""
    existing = db.cur.execute(
        "SELECT catalog_id, facility_name, is_trackable FROM dbo.facility_catalog "
        "ORDER BY catalog_id").fetchall()
    cat_id_by_name = {r[1]: r[0] for r in existing}
    is_trackable = {r[1]: r[2] for r in existing}
    next_id = (max(cat_id_by_name.values()) + 1) if cat_id_by_name else 1
    new_rows = []
    for name, trackable in FACILITY_CATALOG:
        if name not in cat_id_by_name:
            cat_id_by_name[name] = next_id
            is_trackable[name] = trackable
            new_rows.append((next_id, name, trackable))
            next_id += 1
    if new_rows:
        db.insert("facility_catalog", "catalog_id",
                  ["catalog_id", "facility_name", "is_trackable"], new_rows)
    print(f"  facility_catalog: reused {len(cat_id_by_name) - len(new_rows)}, added {len(new_rows)}")
    return cat_id_by_name, is_trackable


def build_users(db, cfg, rng):
    ucfg = cfg["users"]
    roles = [
        ("Student", ucfg["students"]),
        ("Lecturer", ucfg["lecturers"]),
        ("Teaching Assistant", ucfg["teaching_assistants"]),
        ("Facility Staff", ucfg["facility_staff"]),
        ("Department Administrator", ucfg["department_administrators"]),
        ("Facility Manager", ucfg["facility_managers"]),
    ]
    rows = []
    next_id = db.max_id("users", "user_id") + 1
    seq = 0
    first_names = ["Alex", "Jordan", "Taylor", "Morgan", "Casey", "Riley", "Sam", "Quinn"]
    last_names = ["Smith", "Chen", "Nguyen", "Patel", "Kim", "Garcia", "Brown", "Okafor"]
    for role, count in roles:
        dept = rng.choice(DEPARTMENTS) if role not in ("Facility Staff", "Facility Manager") else "Facilities"
        for _ in range(count):
            seq += 1
            full_name = f"{rng.choice(first_names)} {rng.choice(last_names)} {seq}"
            email = f"genuser{seq}@gen.school.edu"
            phone = f"555-{1000 + rng.randint(0, 8999)}"
            dept_now = dept if role not in ("Student", "Lecturer", "Teaching Assistant") else rng.choice(DEPARTMENTS)
            status = "Active" if rng.random() > 0.03 else "Suspended"
            rows.append((next_id, full_name, email, phone, role, dept_now, status))
            next_id += 1
    db.insert("users", "user_id",
              ["user_id", "full_name", "email", "phone_number", "role", "department", "account_status"],
              rows)
    print(f"  users: {len(rows)} generated (ids {rows[0][0]}..{rows[-1][0]})")
    return next_id - 1


def build_spaces(db, cfg, rng):
    rows = []
    next_id = db.max_id("spaces", "space_id") + 1
    n = cfg["spaces"]
    for i in range(n):
        stype = rng.choice(SPACE_TYPES)
        lo, hi = SPACE_TYPE_CAPACITY[stype]
        capacity = rng.randint(lo, hi)
        roll = rng.random()
        if roll < 0.86:
            status = "Available"
        elif roll < 0.94:
            status = "In Use"
        elif roll < 0.98:
            status = "Temporarily Closed"
        else:
            status = "Retired"
        building = rng.choice(BUILDINGS)
        floor = rng.randint(0, 5)
        room = f"{floor}0{rng.randint(1, 9)}"
        auto = 1 if (status == "Available" and stype in AUTO_BOOKING_TYPES and rng.random() < 0.7) else 0
        code = f"GEN-{stype.split()[0][:3].upper()}-{i+1:04d}"
        name = f"Gen {stype} {i+1:04d}"
        rows.append((next_id, code, name, stype, building, floor, room,
                     capacity, status, SPACE_TYPE_POLICY[stype], auto))
        next_id += 1
    db.insert("spaces", "space_id",
              ["space_id", "space_code", "space_name", "space_type", "building",
               "floor", "room_number", "capacity", "current_status", "usage_policy",
               "auto_booking_enabled"],
              rows)
    print(f"  spaces: {len(rows)} generated")
    # curated: (space_id, space_type, current_status, auto_booking_enabled, capacity)
    return [(r[0], r[3], r[8], r[10], r[7]) for r in rows]


def build_facilities_and_assets(db, cfg, catalog_ids, is_trackable, spaces, rng):
    """space_facility rows + facility_assets rows. Trackable quantity == assets."""
    sf_rows = []
    asset_rows = []
    sf_id = db.max_id("space_facility", "space_facility_id") + 1
    asset_id = db.max_id("facility_assets", "asset_id") + 1
    asset_tag_seq = 1
    # space_id -> {catalog_id: space_facility_id} for incident targets
    space_sf = {}
    # space_facility_id -> [(asset_id)] for incident asset-level targets
    sf_assets = {}

    n_min, n_max = cfg["facility_instances_per_space"]
    a_min, a_max = cfg["assets_per_trackable_facility"]

    for (space_id, stype, status, _auto, _cap) in spaces:
        pool = list(catalog_ids.keys())
        k = rng.randint(n_min, n_max)
        chosen = rng.sample(pool, k=min(k, len(pool)))
        space_sf[space_id] = {}
        for cat_name in chosen:
            cid = catalog_ids[cat_name]
            trackable = is_trackable[cat_name]
            if trackable:
                qty = rng.randint(a_min, a_max)
            else:
                qty = rng.randint(1, 4)
            sf_rows.append((sf_id, space_id, cid, qty))
            space_sf[space_id][cid] = sf_id
            if trackable:
                assets = []
                for _ in range(qty):
                    tag = f"GEN-A{asset_tag_seq:06d}"
                    ast = rng.choice(ASSET_STATUSES)
                    asset_rows.append((asset_id, tag, space_id, cid, ast, sf_id))
                    assets.append(asset_id)
                    asset_id += 1
                    asset_tag_seq += 1
                sf_assets[sf_id] = assets
            sf_id += 1

    # Disable the quantity-vs-assets trigger while seeding both tables.
    db.cur.execute("DISABLE TRIGGER TRG_ValidateFacilityQuantity ON dbo.space_facility;")
    try:
        db.insert("space_facility", "space_facility_id",
                  ["space_facility_id", "space_id", "catalog_id", "quantity"], sf_rows)
        db.insert("facility_assets", "asset_id",
                  ["asset_id", "asset_tag", "space_id", "catalog_id", "status", "space_facility_id"],
                  asset_rows)
    finally:
        db.cur.execute("ENABLE TRIGGER TRG_ValidateFacilityQuantity ON dbo.space_facility;")
    print(f"  space_facility: {len(sf_rows)} rows, facility_assets: {len(asset_rows)} rows")
    return space_sf, sf_assets


def build_maintenance(db, cfg, spaces, user_ids, rng):
    """Maintenance records over the semester. Returns per-space blocked
    intervals (out-of-service) and advisory intervals."""
    rows = []
    maint_id = db.max_id("maintenance_records", "maintenance_id") + 1
    space_maint = {sid: [] for sid, *_ in spaces}   # sid -> [(start, end, impact, maint_id)]
    n_total = cfg["maintenance_records"]
    sem_start = dt.datetime.strptime(cfg["semester_start"], "%Y-%m-%d")
    sem_end = dt.datetime.strptime(cfg["semester_end"], "%Y-%m-%d")
    # Distribute records across spaces weighted by booking load.
    weight = [1.0 if st == "Available" else 0.4 for (_sid, _st, st, _a, _c) in spaces]
    total_w = sum(weight)
    counts = [int(n_total * w / total_w) for w in weight]
    assigned = sum(counts)
    if assigned < n_total:
        for _ in range(n_total - assigned):
            counts[rng.randrange(len(counts))] += 1

    for idx, ((space_id, stype, status, _auto, _cap), cnt) in enumerate(zip(spaces, counts)):
        for _ in range(cnt):
            impact = "out-of-service" if rng.random() < cfg["maintenance_oos_ratio"] else "advisory"
            start = sem_start + dt.timedelta(
                days=rng.randint(0, (sem_end - sem_start).days),
                hours=rng.randint(7, 18))
            dur_h = rng.randint(2, 60)
            end = start + dt.timedelta(hours=dur_h)
            if end > sem_end + dt.timedelta(days=7):
                end = sem_end + dt.timedelta(days=7)
            desc = rng.choice(INCIDENT_DESCRIPTIONS)
            reporter = rng.choice(user_ids["users"])
            assigned_staff = rng.choice(user_ids["staff"]) if user_ids["staff"] else None
            is_open = end > dt.datetime.now()
            m_status = rng.choice(MAINTENANCE_STATUSES)
            completion = None if is_open or m_status != "Completed" else end
            result_note = None if completion is None else "Resolved."
            rows.append((maint_id, space_id, reporter, assigned_staff, desc,
                         start, completion, m_status, result_note, impact))
            # Effective blocking/acknowledgement window: open records (no
            # completion_time) stay active until far-future, matching
            # validation.sql ISNULL(completion_time, '9999-12-31').
            eff_end = completion if completion is not None else dt.datetime(9999, 12, 31, 23, 59, 59)
            space_maint[space_id].append((start, eff_end, impact, maint_id))
            maint_id += 1
    db.insert("maintenance_records", "maintenance_id",
              ["maintenance_id", "space_id", "reporter_id", "assigned_staff_id",
               "problem_description", "start_time", "completion_time", "status",
               "result_note", "impact_level"],
              rows)
    print(f"  maintenance_records: {len(rows)} generated")
    return space_maint


def overlaps(a_start, a_end, b_start, b_end):
    return a_start < b_end and b_start < a_end


def build_bookings(db, cfg, spaces, user_ids, space_maint, rng):
    """Bookings + approvals + usage_sessions + advisory acknowledgements."""
    booking_rows = []
    approval_rows = []
    session_rows = []
    ack_rows = []
    b_id = db.max_id("bookings", "booking_id") + 1
    a_id = db.max_id("approvals", "approval_id") + 1
    s_id = db.max_id("usage_sessions", "session_id") + 1
    k_id = db.max_id("advisory_acknowledgements", "acknowledgement_id") + 1

    sem_start = dt.datetime.strptime(cfg["semester_start"], "%Y-%m-%d")
    sem_end = dt.datetime.strptime(cfg["semester_end"], "%Y-%m-%d")
    weekdays = []
    d = sem_start
    while d <= sem_end:
        if d.weekday() < 5:
            weekdays.append(d)
        d += dt.timedelta(days=1)

    committed_w = cfg["bookings"]["committed_status_weights"]
    transient_w = cfg["bookings"]["transient_status_weights"]
    c_per_week = cfg["bookings"]["committed_per_space_per_week"]
    t_per_week = cfg["bookings"]["transient_per_space_per_week"]
    dur_min, dur_max = cfg["bookings"]["duration_hours"]

    staff_ids = user_ids["staff"] + user_ids["managers"]
    staff_or_mgr = user_ids["staff"] + user_ids["managers"]
    n_committed = n_transient = 0

    # Partition semester into weeks for slot assignment.
    week_groups = []
    for i in range(0, len(weekdays), 5):
        week_groups.append(weekdays[i:i + 5])

    for (space_id, stype, status, auto, capacity) in spaces:
        if status != "Available":
            continue  # Temporarily Closed / Retired / In Use -> no new bookings
        blocked = [(s, e) for (s, e, imp, _m) in space_maint.get(space_id, []) if imp == "out-of-service"]
        advisories = [(s, e, m) for (s, e, imp, m) in space_maint.get(space_id, []) if imp == "advisory"]

        for week in week_groups:
            # committed slots: distinct (day, block) pairs -> disjoint by construction
            slots = [(day, bh, eh) for day in week for (bh, eh) in TIME_BLOCKS]
            chosen_committed = rng.sample(slots, k=min(c_per_week, len(slots)))
            for (day, bh, eh) in chosen_committed:
                start = day.replace(hour=bh, minute=0, second=0)
                # duration must stay within the time block so committed
                # bookings never bleed into the adjacent block (BR-01)
                max_dur = eh - bh
                dur = min(rng.randint(dur_min, dur_max), max_dur)
                end = start + dt.timedelta(hours=dur)
                if end >= day.replace(hour=eh, minute=0, second=0):
                    end = day.replace(hour=eh, minute=0, second=0)
                # skip if overlaps an out-of-service window (BR-11)
                if any(overlaps(start, end, bs, be) for (bs, be) in blocked):
                    continue
                status = rng.choices(list(committed_w.keys()),
                                     weights=list(committed_w.values()))[0]
                purpose = rng.choice(BOOKING_PURPOSES.get(stype, PURPOSES))
                participants = rng.randint(1, capacity)
                user = rng.choice(user_ids["users"])
                # advisory acknowledgement
                overlapped_adv = [(s, e, m) for (s, e, m) in advisories
                                  if overlaps(start, end, s, e)]
                ack = 1 if overlapped_adv else 0
                snapshot = None
                if overlapped_adv:
                    snapshot = "; ".join(f"advisory#{m}" for (_s, _e, m) in overlapped_adv)
                booking_rows.append((b_id, user, space_id, start, end, purpose,
                                     participants, status, ack, snapshot))
                # approval
                if status in ("Approved", "Checked In", "Completed", "No-show"):
                    if auto and rng.random() < 0.6:
                        staff = None
                        note = "Automatic approval per usage policy."
                    else:
                        staff = rng.choice(staff_or_mgr)
                        note = rng.choice(["Approved for " + purpose + ".", "Approved. Sound check required."])
                    approval_rows.append((a_id, b_id, staff, start - dt.timedelta(days=rng.randint(1, 7)),
                                          note, None))
                    a_id += 1
                elif status == "Rejected":
                    staff = rng.choice(staff_or_mgr)
                    approval_rows.append((a_id, b_id, staff, start - dt.timedelta(days=rng.randint(1, 7)),
                                          "Denied.", "Space already reserved for another event."))
                    a_id += 1
                # usage session
                if status in ("Checked In", "Completed"):
                    astart = start + dt.timedelta(minutes=rng.randint(0, 10))
                    aend = end + dt.timedelta(minutes=rng.randint(-5, 5)) if status == "Completed" else None
                    staff = rng.choice(staff_ids) if staff_ids else None
                    session_rows.append((s_id, b_id, staff, astart, aend,
                                         "Good", rng.choice(USAGE_NOTES), rng.choice(USAGE_NOTES)))
                    s_id += 1
                # advisory acknowledgements (BR-11)
                for (_s, _e, m) in overlapped_adv:
                    ack_rows.append((k_id, b_id, m, user, start - dt.timedelta(days=1)))
                    k_id += 1
                n_committed += 1
                b_id += 1

            # transient slots (Pending/Rejected/Cancelled) - may overlap anything
            chosen_transient = rng.sample(slots, k=min(t_per_week, len(slots)))
            for (day, bh, eh) in chosen_transient:
                start = day.replace(hour=bh, minute=0, second=0)
                end = start + dt.timedelta(hours=rng.randint(dur_min, dur_max))
                status = rng.choices(list(transient_w.keys()),
                                     weights=list(transient_w.values()))[0]
                purpose = rng.choice(BOOKING_PURPOSES.get(stype, PURPOSES))
                participants = rng.randint(1, capacity)
                user = rng.choice(user_ids["users"])
                booking_rows.append((b_id, user, space_id, start, end, purpose,
                                     participants, status, 0, None))
                if status == "Rejected":
                    staff = rng.choice(staff_or_mgr)
                    approval_rows.append((a_id, b_id, staff, start - dt.timedelta(days=rng.randint(1, 7)),
                                          "Denied.", "Capacity insufficient for requested space."))
                    a_id += 1
                n_transient += 1
                b_id += 1

    db.insert("bookings", "booking_id",
              ["booking_id", "user_id", "space_id", "start_time", "end_time",
               "purpose", "expected_participants", "status", "advisory_acknowledged",
               "advisory_snapshot"],
              booking_rows)
    if approval_rows:
        db.insert("approvals", "approval_id",
                  ["approval_id", "booking_id", "staff_id", "decision_time",
                   "decision_note", "rejection_reason"],
                  approval_rows)
    if session_rows:
        db.insert("usage_sessions", "session_id",
                  ["session_id", "booking_id", "staff_id", "actual_start_time",
                   "actual_end_time", "initial_condition", "final_condition", "usage_notes"],
                  session_rows)
    if ack_rows:
        db.insert("advisory_acknowledgements", "acknowledgement_id",
                  ["acknowledgement_id", "booking_id", "maintenance_id",
                   "acknowledged_by", "acknowledged_at"],
                  ack_rows)
    print(f"  bookings: {n_committed} committed + {n_transient} transient = {n_committed + n_transient}")
    print(f"  approvals: {len(approval_rows)}, usage_sessions: {len(session_rows)}, "
          f"advisory_acknowledgements: {len(ack_rows)}")


def build_incidents(db, cfg, spaces, user_ids, space_sf, sf_assets, space_maint, rng):
    """Incident reports (room/facility/asset level) + consolidation into
    existing maintenance records (many reports -> one record)."""
    report_rows = []
    consolid_rows = []
    r_id = db.max_id("incident_reports", "report_id") + 1
    c_id = db.max_id("report_consolidations", "consolidation_id") + 1
    sem_start = dt.datetime.strptime(cfg["semester_start"], "%Y-%m-%d")
    sem_end = dt.datetime.strptime(cfg["semester_end"], "%Y-%m-%d")

    n_total = cfg["incident_reports"]
    weights = [1.0 if st == "Available" else 0.3 for (_sid, _st, st, _a, _c) in spaces]
    total_w = sum(weights)
    counts = [int(n_total * w / total_w) for w in weights]
    for _ in range(n_total - sum(counts)):
        counts[rng.randrange(len(counts))] += 1

    # Collect maintenance records we may consolidate into, by space.
    # space_id -> list of maintenance ids (advisory ones preferentially).
    maint_by_space = {}
    for sid, lst in space_maint.items():
        mids = [m for (_s, _e, _imp, m) in lst]
        if mids:
            maint_by_space[sid] = mids

    # Deterministically pick a pool of maintenance records to "receive" reports.
    all_mids = [m for lst in maint_by_space.values() for m in lst]
    rng.shuffle(all_mids)
    n_consolidated = int(n_total * cfg["consolidated_incident_ratio"])
    target_maints = all_mids[:max(1, n_consolidated // 2)]

    reported = 0
    consolidated_reports = 0
    staff_or_mgr = user_ids["staff"] + user_ids["managers"]
    t_weights = cfg["incident_target_weights"]
    targets = list(t_weights.keys())
    t_probs = list(t_weights.values())

    for (space_id, stype, status, _auto, _cap), cnt in zip(spaces, counts):
        for _ in range(cnt):
            reported += 1
            user = rng.choice(user_ids["users"])
            when = sem_start + dt.timedelta(days=rng.randint(0, (sem_end - sem_start).days),
                                            hours=rng.randint(8, 20))
            desc = rng.choice(INCIDENT_DESCRIPTIONS)
            sf_map = space_sf.get(space_id, {})
            target = rng.choices(targets, weights=t_probs)[0]
            sf_id = None
            ast_id = None
            if target == "facility" and sf_map:
                sf_id = rng.choice(list(sf_map.values()))
            elif target == "asset":
                candidates = [aid for sfid, assets in sf_assets.items()
                              if sfid in sf_map.values() for aid in assets]
                if candidates:
                    ast_id = rng.choice(candidates)
                    # find the space_facility for this asset
                    for sfid, assets in sf_assets.items():
                        if ast_id in assets:
                            sf_id = sfid
                            break
            # consolidation: a share of reports link to a maintenance record
            status = "Open"
            maint_for_report = None
            if maint_by_space.get(space_id) and consolidated_reports < n_consolidated:
                maint_for_report = rng.choice(maint_by_space[space_id])
                status = "Consolidated"
                consolidated_reports += 1
            report_rows.append((r_id, user, space_id, sf_id, ast_id, desc, when, status))
            if maint_for_report is not None:
                consolid_rows.append((c_id, r_id, maint_for_report,
                                      rng.choice(staff_or_mgr),
                                      when + dt.timedelta(hours=rng.randint(1, 48))))
                c_id += 1
            r_id += 1

    db.insert("incident_reports", "report_id",
              ["report_id", "user_id", "space_id", "space_facility_id", "asset_id",
               "description", "reported_at", "status"],
              report_rows)
    if consolid_rows:
        db.insert("report_consolidations", "consolidation_id",
                  ["consolidation_id", "incident_report_id", "maintenance_id",
                   "consolidated_by", "consolidated_at"],
                  consolid_rows)
    print(f"  incident_reports: {len(report_rows)} generated "
          f"({consolidated_reports} consolidated into maintenance records)")


# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--reset", action="store_true",
                    help="Delete previously generated rows first (idempotent re-run).")
    ap.add_argument("--config", default=os.path.join(BASE_DIR, "config.json"))
    args = ap.parse_args()

    with open(args.config, encoding="utf-8") as f:
        cfg = json.load(f)

    rng = random.Random(cfg["seed"])

    db = DB()
    try:
        cursor = db.cur
        if args.reset:
            reset_generated(db, cursor)

        print("Generating data (seed=%d)..." % cfg["seed"])

        cat_id_by_name, is_trackable = build_catalog(db, rng)
        build_users(db, cfg, rng)
        spaces = build_spaces(db, cfg, rng)
        space_sf, sf_assets = build_facilities_and_assets(
            db, cfg, cat_id_by_name, is_trackable, spaces, rng)

        # user id pools by role
        user_rows = cursor.execute(
            "SELECT user_id, role FROM dbo.users WHERE email LIKE '%@gen.school.edu'").fetchall()
        user_ids = {
            "users": [r[0] for r in user_rows],
            "staff": [r[0] for r in user_rows if r[1] == "Facility Staff"],
            "managers": [r[0] for r in user_rows if r[1] == "Facility Manager"],
        }

        space_maint = build_maintenance(db, cfg, spaces, user_ids, rng)
        build_bookings(db, cfg, spaces, user_ids, space_maint, rng)
        build_incidents(db, cfg, spaces, user_ids, space_sf, sf_assets, space_maint, rng)

        db.commit()
        print("SUCCESS: dataset generated and committed.")
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


if __name__ == "__main__":
    main()
