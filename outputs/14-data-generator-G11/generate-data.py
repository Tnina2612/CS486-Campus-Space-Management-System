"""
Large-scale Phase 2 data generator for the Campus Space Management System.

Generates >= 100,000 bookings across >= 3 academic years into SQL Server,
together with users, spaces, facilities, maintenance records (advisory and
out-of-service), approvals, usage sessions, and advisory acknowledgements.

Guarantees enforced while generating:
  - no two APPROVED bookings overlap the same space
  - no APPROVED booking overlaps an out-of-service maintenance period
  - advisory maintenance is allowed; matching acknowledgement rows are created
  - FK references are valid; start_time < end_time always

Configuration: config.json  (see README for defaults).
Run:  python generate-data.py
"""
import json
import os
import random
import sys
from collections import defaultdict

import pyodbc

HERE = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(HERE, "config.json")
DEFAULT_CONN = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=localhost;DATABASE=CampusSpaceManagement;Trusted_Connection=yes;"
)


def load_config():
    with open(CONFIG_PATH, "r", encoding="utf-8") as fh:
        return json.load(fh)


def daterange(start, end):
    """Yield naive datetime objects within [start, end) at 8:00-18:00 windows."""
    import datetime

    cur = start
    while cur < end:
        if 8 <= cur.hour <= 17:
            yield cur
        cur += datetime.timedelta(minutes=30)


class Generator:
    def __init__(self, cfg, conn_str):
        self.cfg = cfg
        self.rng = random.Random(cfg["random_seed"])
        self.conn = pyodbc.connect(conn_str, autocommit=False)
        self.cur = self.conn.cursor()
        self.user_ids = {"Student": [], "Lecturer": [], "Teaching Assistant": [],
                         "Facility Staff": [], "Department Administrator": [],
                         "Facility Manager": []}
        self.space_ids = []
        self.catalog_ids = {}
        self.asset_ids_by_space_catalog = defaultdict(list)
        self.space_capacity = {}
        self.space_instant = {}
        self.space_facility = defaultdict(set)   # space_id -> set(catalog_id)
        self.maintenance_by_space = defaultdict(list)  # space_id -> list of (start,end,impact)

    # ------------------------------------------------------------------ #
    # Base entities
    # ------------------------------------------------------------------ #
    def seed_users(self):
        counts = self.cfg["users"]
        role_names = [
            ("students", "Student"),
            ("lecturers", "Lecturer"),
            ("tas", "Teaching Assistant"),
            ("facility_staff", "Facility Staff"),
            ("admins", "Department Administrator"),
            ("managers", "Facility Manager"),
        ]
        depts = ["Computer Science", "Data Science", "Software Eng",
                 "Information Systems", "Facilities"]
        n = 0
        for key, role in role_names:
            for i in range(counts.get(key, 0)):
                n += 1
                dept = depts[self.rng.randrange(len(depts))] if role != "Facility Staff" \
                       and role != "Facility Manager" else "Facilities"
                self.cur.execute(
                    "INSERT INTO dbo.users (full_name, email, phone_number, role, department, account_status) "
                    "VALUES (?,?,?,?,?,?)",
                    (f"{role} {n}", f"user{n}@uni.edu", f"555-{1000+n}",
                     role, dept, "Active"),
                )
                self.user_ids[role].append(self.last_id())
        self.conn.commit()
        print(f"Users seeded: {n}")

    def seed_spaces(self):
        types = ["Auditorium", "Classroom", "Computer Laboratory",
                 "Project Laboratory", "Meeting Room", "Student Workspace"]
        statuses = ["Available", "In Use", "Under Maintenance",
                    "Temporarily Closed", "Retired"]
        for i in range(self.cfg["spaces"]):
            cap = self.rng.choice([20, 30, 40, 50, 60, 100, 150, 200])
            status = statuses[self.rng.randrange(len(statuses))]
            instant = 1 if self.rng.random() < 0.5 else 0
            self.cur.execute(
                "INSERT INTO dbo.spaces (space_code, space_name, space_type, building, floor, "
                "room_number, capacity, current_status, usage_policy, allows_instant_booking) "
                "VALUES (?,?,?,?,?,?,?,?,?,?)",
                (f"SP{i+1:03d}", f"Space {i+1}", types[i % len(types)],
                 f"Building {i % 3 + 1}", i % 4, f"{i+1:02d}", cap, status,
                 "Open use", instant),
            )
            sid = self.last_id()
            self.space_ids.append(sid)
            self.space_capacity[sid] = cap
            self.space_instant[sid] = bool(instant)
        self.conn.commit()
        print(f"Spaces seeded: {len(self.space_ids)}")

    def seed_catalog(self):
        facilities = [
            ("Projector", 1), ("Whiteboard", 0), ("Microphone System", 1),
            ("Computer Workstation", 1), ("Livestreaming Kit", 1),
            ("Air Conditioner Unit", 0), ("Conference Phone", 1),
            ("Smart TV", 1), ("Document Camera", 1), ("Furniture Set", 0),
            ("Network Access Point", 0), ("Speaker System", 1),
        ]
        for name, track in facilities:
            self.cur.execute(
                "INSERT INTO dbo.facility_catalog (facility_name, is_trackable) VALUES (?,?)",
                (name, track),
            )
            self.catalog_ids[name] = self.last_id()
        self.conn.commit()

    def seed_space_facility_and_assets(self):
        names = list(self.catalog_ids)
        asset_counter = 0
        for sid in self.space_ids:
            k = self.rng.randint(self.cfg["space_facility_links_per_space"]["min"],
                                 self.cfg["space_facility_links_per_space"]["max"])
            chosen = self.rng.sample(names, min(k, len(names)))
            for name in chosen:
                cid = self.catalog_ids[name]
                quantity = self.rng.randint(1, 6)
                self.cur.execute(
                    "INSERT INTO dbo.space_facility (space_id, catalog_id, quantity) VALUES (?,?,?)",
                    (sid, cid, quantity),
                )
                self.space_facility[sid].add(cid)
                # Create individual assets for trackable facilities.
                if self.cfg:
                    self.cur.execute(
                        "SELECT is_trackable FROM dbo.facility_catalog WHERE catalog_id=?",
                        (cid,),
                    )
                    trackable = self.cur.fetchone()[0]
                    if trackable:
                        for _ in range(quantity):
                            asset_counter += 1
                            self.cur.execute(
                                "INSERT INTO dbo.facility_assets (asset_tag, space_id, catalog_id, status) "
                                "VALUES (?,?,?,?)",
                                (f"A{asset_counter:06d}", sid, cid, "Good"),
                            )
                            self.asset_ids_by_space_catalog[(sid, cid)].append(self.last_id())
        self.conn.commit()
        print(f"Space-facility links + assets seeded")

    # ------------------------------------------------------------------ #
    # Maintenance
    # ------------------------------------------------------------------ #
    def seed_maintenance(self):
        statuses = ["Reported", "Assigned", "In Progress", "Completed"]
        import datetime
        semester_rows = self.cfg["config_semester_rows"]
        for _ in range(self.cfg["maintenance_records"]):
            sid = self.rng.choice(self.space_ids)
            start = self.random_semester_time(semester_rows)
            duration = datetime.timedelta(days=self.rng.randint(1, 14))
            impact = self.rng.choices(["advisory", "out-of-service"],
                                      weights=[70, 30])[0]
            completed = self.rng.random() < 0.6
            status = "Completed" if completed else self.rng.choice(statuses[:3])
            completion = start + duration if completed else None
            self.cur.execute(
                "INSERT INTO dbo.maintenance_records "
                "(space_id, reporter_id, assigned_staff_id, problem_description, start_time, "
                "completion_time, status, result_note, impact_level, facility_catalog_id, facility_asset_id) "
                "VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                (sid, self.rng.choice(self.user_ids["Student"]),
                 self.rng.choice(self.user_ids["Facility Staff"]),
                 f"Problem {self.rng.randint(1, 9999)}", start, completion,
                 status, "Done" if completed else None, impact, None, None),
            )
            self.maintenance_by_space[sid].append((start, completion, impact))
        self.conn.commit()
        print(f"Maintenance records seeded: {self.cfg['maintenance_records']}")

    # ------------------------------------------------------------------ #
    # Bookings (concurrency-safe generation: no approved overlap)
    # ------------------------------------------------------------------ #
    def seed_bookings(self):
        import datetime
        semester_rows = self.cfg["config_semester_rows"]
        weights = self.cfg["booking_status_weights"]
        statuses = list(weights)
        w = [weights[s] for s in statuses]
        target = self.cfg["target_bookings"]
        n = 0
        while n < target:
            sid = self.rng.choice(self.space_ids)
            start = self.random_semester_time(semester_rows)
            end = start + datetime.timedelta(minutes=self.rng.randint(60, 480))
            status = self.rng.choices(statuses, weights=w)[0]
            if status in ("Approved", "Checked In", "Completed", "No-show"):
                # must not overlap an existing approved booking
                if self.overlaps_approved(sid, start, end):
                    continue
                # must not overlap out-of-service maintenance
                if self.overlaps_out_of_service(sid, start, end):
                    continue
            self.insert_booking(sid, start, end, status)
            n += 1
            if n % 10000 == 0:
                self.conn.commit()
                print(f"  ...{n} bookings")
        self.conn.commit()
        print(f"Bookings seeded: {n}")

    def overlaps_approved(self, sid, start, end):
        self.cur.execute(
            "SELECT 1 FROM dbo.bookings WHERE space_id=? AND status IN "
            "('Approved','Checked In','Completed','No-show') "
            "AND ? < end_time AND ? > start_time",
            (sid, start, end),
        )
        return self.cur.fetchone() is not None

    def overlaps_out_of_service(self, sid, start, end):
        self.cur.execute(
            "SELECT 1 FROM dbo.maintenance_records WHERE space_id=? AND impact_level='out-of-service' "
            "AND (completion_time IS NULL OR completion_time > ?) AND start_time < ?",
            (sid, start, end),
        )
        return self.cur.fetchone() is not None

    def insert_booking(self, sid, start, end, status):
        requester = self.rng.choice(
            self.user_ids["Student"] + self.user_ids["Lecturer"]
            + self.user_ids["Teaching Assistant"] + self.user_ids["Department Administrator"]
        )
        purpose = self.rng.choice(self.cfg["purpose_values"])
        expected = self.rng.randint(5, self.space_capacity[sid])
        self.cur.execute(
            "INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, "
            "expected_participants, status) VALUES (?,?,?,?,?,?,?)",
            (requester, sid, start, end, purpose, expected, status),
        )
        bid = self.last_id()
        self.add_lifecycle(bid, sid, start, end, status)

    def add_lifecycle(self, bid, sid, start, end, status):
        staff = self.user_ids["Facility Staff"] + self.user_ids["Facility Manager"]
        # Approval row for decided statuses (pending bookings have none).
        if status in ("Approved", "Rejected", "Checked In", "Completed", "No-show"):
            if status == "Rejected":
                self.cur.execute(
                    "INSERT INTO dbo.approvals (booking_id, staff_id, decision_time, decision_note, "
                    "rejection_reason) VALUES (?,?,?,?,?)",
                    (bid, self.rng.choice(staff), start - self.rng.randint(60, 720),
                     "Decided", "Capacity/conflict reason"),
                )
            else:
                self.cur.execute(
                    "INSERT INTO dbo.approvals (booking_id, staff_id, decision_time, decision_note, "
                    "rejection_reason) VALUES (?,?,?,?,?)",
                    (bid, self.rng.choice(staff), start - self.rng.randint(60, 720),
                     "Auto/approved", None),
                )
        # Usage session for completed/checked-in bookings.
        if status in ("Checked In", "Completed"):
            self.cur.execute(
                "INSERT INTO dbo.usage_sessions (booking_id, staff_id, actual_start_time, "
                "actual_end_time, initial_condition, final_condition, usage_notes) "
                "VALUES (?,?,?,?,?,?,?)",
                (bid, self.rng.choice(staff), start, end, "Good", "Good", "None"),
            )
        # Advisory acknowledgements: any active advisory overlapping the booking.
        if status in ("Approved", "Checked In", "Completed", "No-show"):
            self.cur.execute(
                "SELECT maintenance_id FROM dbo.maintenance_records WHERE space_id=? "
                "AND impact_level='advisory' AND (completion_time IS NULL OR completion_time > ?) "
                "AND start_time < ?",
                (sid, start, end),
            )
            for (mid,) in self.cur.fetchall():
                self.cur.execute(
                    "INSERT INTO dbo.advisory_acknowledgements (booking_id, maintenance_id, "
                    "acknowledged_at) VALUES (?,?,?)",
                    (bid, mid, start),
                )

    # ------------------------------------------------------------------ #
    # Helpers
    # ------------------------------------------------------------------ #
    def random_semester_time(self, semester_rows):
        import datetime
        row = self.rng.choice(semester_rows)
        lo = datetime.datetime.fromisoformat(row["start_lo"])
        hi = datetime.datetime.fromisoformat(row["start_hi"])
        return self.rng.choice(list(daterange(lo, hi)))

    def last_id(self):
        self.cur.execute("SELECT SCOPE_IDENTITY()")
        return int(self.cur.fetchone()[0])

    def run(self):
        print("Seeding base entities...")
        self.seed_users()
        self.seed_spaces()
        self.seed_catalog()
        self.seed_space_facility_and_assets()
        self.seed_maintenance()
        print("Seeding bookings...")
        self.seed_bookings()
        self.conn.close()
        print("Done.")


def main():
    cfg = load_config()
    conn_str = os.environ.get("CS486_CONN", DEFAULT_CONN)
    gen = Generator(cfg, conn_str)
    gen.run()


if __name__ == "__main__":
    main()