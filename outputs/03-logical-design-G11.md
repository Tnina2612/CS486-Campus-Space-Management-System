# Logical Database Design

## Group
G11

## Notation
`TableName(PK, attr1, attr2, FK1, FK2, ...)`  
PK = Primary Key, FK = Foreign Key, UK = Unique Key, CK = Candidate Key

---

## Relational Schema

### 1. [user]
```
user(user_id PK, full_name, email UK, phone, role, department, account_status)
```
- `email` is a UNIQUE candidate key.
- `role` CHECK constraint: 'Student', 'Lecturer', 'TA', 'FacilityStaff', 'DeptAdmin', 'FacilityManager'.
- `account_status` CHECK constraint: 'Active', 'Inactive', 'Suspended'.

### 2. space
```
space(space_code PK, space_name, space_type, building, floor, room_number, capacity, status, usage_policy)
```
- `space_type` CHECK constraint: 'Auditorium', 'Classroom', 'ComputerLab', 'ProjectLab', 'MeetingRoom', 'Workspace'.
- `status` CHECK constraint: 'Available', 'InUse', 'UnderMaintenance', 'TemporarilyClosed', 'Retired'.
- `capacity` CHECK: > 0.

### 3. facility_catalog
```
facility_catalog(catalog_id PK, name, description, is_trackable)
```
- `is_trackable` is BIT (0 = non-trackable, 1 = trackable).

### 4. space_facility
```
space_facility(id PK, space_code FK, catalog_id FK, quantity)
```
- FK: `space_code` REFERENCES space(space_code).
- FK: `catalog_id` REFERENCES facility_catalog(catalog_id).
- UNIQUE constraint on (`space_code`, `catalog_id`).
- `quantity` CHECK: > 0.
- This resolves the M:N relationship between space and facility_catalog.

### 5. facility_asset
```
facility_asset(asset_id PK, catalog_id FK, space_code FK, asset_tag UK, status)
```
- FK: `catalog_id` REFERENCES facility_catalog(catalog_id).
- FK: `space_code` REFERENCES space(space_code).
- `asset_tag` UNIQUE.
- `status` CHECK constraint: 'Working', 'UnderRepair', 'Retired'.

### 6. booking
```
booking(booking_id PK, space_code FK, requester_id FK, requested_start, requested_end, purpose, participants, booking_type, status)
```
- FK: `space_code` REFERENCES space(space_code).
- FK: `requester_id` REFERENCES user(user_id).
- `booking_type` CHECK: 'Lecture', 'Examination', 'Seminar', 'Workshop', 'Meeting', 'StudentActivity', 'Administrative'.
- `status` CHECK: 'Pending', 'Approved', 'Rejected', 'Cancelled', 'CheckedIn', 'Completed', 'NoShow'.
- `participants` CHECK: > 0.
- CHECK: `requested_end` > `requested_start`.

### 7. booking_approval
```
booking_approval(approval_id PK, booking_id FK UK, approver_id FK, decision_time, decision_note, rejection_reason)
```
- FK: `booking_id` REFERENCES booking(booking_id).
- FK: `approver_id` REFERENCES user(user_id).
- `booking_id` is UNIQUE (1:1 relationship with booking).
- `rejection_reason` is NULL when status is approved, NOT NULL when rejected.

### 8. booking_session
```
booking_session(session_id PK, booking_id FK UK, actual_start, checked_in_by FK, initial_condition, actual_end, completed_by FK, final_condition, usage_notes)
```
- FK: `booking_id` REFERENCES booking(booking_id).
- FK: `checked_in_by` REFERENCES user(user_id).
- FK: `completed_by` REFERENCES user(user_id).
- `booking_id` is UNIQUE (1:1 relationship with booking).
- CHECK: `actual_end` > `actual_start` when both are present.

### 9. maintenance_record
```
maintenance_record(maintenance_id PK, space_code FK, reporter_id FK, assigned_to FK, problem_description, problem_type, start_time, completion_time, status, result_note)
```
- FK: `space_code` REFERENCES space(space_code).
- FK: `reporter_id` REFERENCES user(user_id).
- FK: `assigned_to` REFERENCES user(user_id) — nullable until assigned.
- `problem_type` CHECK: 'BrokenProjector', 'ACFailure', 'DamagedFurniture', 'Cleaning', 'Network', 'Other'.
- `status` CHECK: 'Reported', 'InProgress', 'Completed', 'Cancelled'.

---

## Referential Integrity Summary

| FK Constraint | Source Table | Source Column(s) | Referenced Table | Referenced Column | Delete Rule | Update Rule |
|---|---|---|---|---|---|---|
| FK_booking_space | booking | space_code | space | space_code | NO ACTION | CASCADE |
| FK_booking_user | booking | requester_id | user | user_id | NO ACTION | NO ACTION |
| FK_approval_booking | booking_approval | booking_id | booking | booking_id | CASCADE | NO ACTION |
| FK_approval_approver | booking_approval | approver_id | user | user_id | NO ACTION | NO ACTION |
| FK_session_booking | booking_session | booking_id | booking | booking_id | CASCADE | NO ACTION |
| FK_session_checkin | booking_session | checked_in_by | user | user_id | NO ACTION | NO ACTION |
| FK_session_checkout | booking_session | completed_by | user | user_id | NO ACTION | NO ACTION |
| FK_maintenance_space | maintenance_record | space_code | space | space_code | NO ACTION | CASCADE |
| FK_maintenance_reporter | maintenance_record | reporter_id | user | user_id | NO ACTION | NO ACTION |
| FK_maintenance_assignee | maintenance_record | assigned_to | user | user_id | NO ACTION | NO ACTION |
| FK_sf_space | space_facility | space_code | space | space_code | CASCADE | CASCADE |
| FK_sf_catalog | space_facility | catalog_id | facility_catalog | catalog_id | NO ACTION | NO ACTION |
| FK_fa_catalog | facility_asset | catalog_id | facility_catalog | catalog_id | NO ACTION | NO ACTION |
| FK_fa_space | facility_asset | space_code | space | space_code | CASCADE | CASCADE |

---

## Business Rule Enforcement Mapping

| Business Rule | Enforcement Mechanism |
|---|---|
| No overlapping approved bookings | Application-level CHECK or T-SQL trigger / UDF; SQL Server has no native interval exclusion constraint |
| Unavailable space cannot be booked | Application logic checks space.status before approving; FK ensures space exists |
| Approval recording | booking_approval table ensures mandatory fields on approval/rejection |
| Check-in/Check-out recording | booking_session table captures actual times and conditions |
| Maintenance prevents booking | Application logic checks active maintenance records before allowing booking |
| Historical preservation | No hard DELETE on historical records; status-based soft lifecycle |
| Facility hybrid pattern | Three tables (catalog, mapping, asset) with FK constraints and trigger for quantity validation |
| Unique asset tag | UNIQUE constraint on facility_asset.asset_tag |
