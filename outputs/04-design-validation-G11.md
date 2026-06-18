# Database Design Validation

## 1. Schema-to-ERD Conformance

| ERD Entity | Corresponding Table | Status |
|---|---|---|
| User | `user` | ✅ |
| Space | `space` | ✅ |
| Facility | `facility` | ✅ |
| Space_Facility | `space_facility` | ✅ |
| Booking_Request | `booking_request` | ✅ |
| Booking_Approval | `booking_approval` | ✅ |
| Booking_Session | `booking_session` | ✅ |
| Maintenance_Record | `maintenance_record` | ✅ |

All M:N relationships (Space ↔ Facility) have been properly resolved with an associative table `space_facility`. All 1:N and 1:1 relationships carry the correct foreign keys. The schema is a faithful translation of the ERD.

## 2. Business Rule Verification

| # | Business Rule | How the Schema Enforces It | Status |
|---|---|---|---|
| BR1 | No overlapping approved bookings for same space | Cannot be enforced declaratively in SQL Server (no exclusion constraints). Must be enforced via a `BEFORE INSERT`/`BEFORE UPDATE` trigger or application logic. A UNIQUE constraint on (space_code, time range) is not natively supported. A `CHECK` constraint using a UDF could partially address this, but a trigger is the recommended approach. | ⚠️ Requires trigger/application enforcement |
| BR2 | Unavailable space (maintenance/closed/retired) cannot be booked | `space.current_status` CHECK constraint restricts valid values. Application/trigger must check `current_status != 'available'` before allowing new booking requests. A trigger on `booking_request` can verify that the referenced `space.current_status` is 'available'. | ⚠️ Requires trigger enforcement |
| BR3 | Each user must have a valid university account | `user.email` is UNIQUE and NOT NULL. `user.account_status` defaults to 'active'. | ✅ |
| BR4 | Approval workflow — staff, time, notes recorded | `booking_approval` table captures staff_id, decision_time, decision_note, and rejection_reason. FK constraints ensure valid staff references. | ✅ |
| BR5 | Check-in records actual start, person, condition | `booking_session.actual_start_time`, `checkin_by`, `initial_condition` are all captured. | ✅ |
| BR6 | Checkout records actual end, final condition, notes | `booking_session.actual_end_time`, `completed_by`, `final_condition`, `usage_notes` are captured. End time and completed_by are nullable to allow recording checkout after check-in. | ✅ |
| BR7 | Status lifecycle: pending → approved → checked_in → completed/no_show | CHECK constraint on `booking_request.status` restricts values. However, the logical transition order cannot be enforced declaratively; a trigger must validate that status changes follow the correct order. | ⚠️ Requires trigger enforcement |
| BR8 | Historical records kept | No `DELETE` cascades on critical history tables. Only `space_facility` and `facility` use CASCADE delete, which are reference data. | ✅ |
| BR9 | Active maintenance blocks booking | Must be enforced via trigger: when inserting a booking_request, check whether the space has any `maintenance_record` with status 'reported' or 'in_progress'. | ⚠️ Requires trigger enforcement |
| BR10 | Role-based access | The `user.role` CHECK constraint provides the data foundation. Access control is implemented at the application layer. | ✅ (data layer ready) |

## 3. Key and Constraint Adequacy

| Constraint Type | Assessment | Status |
|---|---|---|
| Primary Keys | All tables have appropriate single-column or composite PKs. | ✅ |
| Foreign Keys | All FKs reference valid PKs. ON DELETE actions are sensible: NO ACTION for critical data, CASCADE for junction table, SET NULL for optional staff assignment. | ✅ |
| UNIQUE constraints | `user.email`, `facility.facility_name`, `booking_approval.booking_id`, `booking_session.booking_id` — all appropriate. | ✅ |
| CHECK constraints | Enforce valid enums for role, space_type, current_status, purpose, status, decision, problem_type. `CHECK(capacity > 0)`, `CHECK(expected_participants > 0)`, `CHECK(requested_end_time > requested_start_time)`. | ✅ |
| DEFAULT values | `account_status = 'active'`, `current_status = 'available'`, `booking.status = 'pending'`, `submitted_at = GETDATE()`, `decision_time = GETDATE()`, `maintenance.start_time = GETDATE()`, `maintenance.status = 'reported'`. | ✅ |
| IDENTITY | Auto-increment PKs on `user`, `facility`, `booking_request`, `booking_approval`, `booking_session`, `maintenance_record`. | ✅ |

## 4. Normalization Check

| Normal Form | Status | Notes |
|---|---|---|
| 1NF | ✅ | All columns atomic; no repeating groups. |
| 2NF | ✅ | All non-key attributes fully functionally dependent on the entire PK. Junction table `space_facility` has a composite PK with no non-key attributes. |
| 3NF | ✅ | No transitive dependencies. For example, `booking_request` does not store any space details (those are in `space`). `booking_session` does not store user details. |
| BCNF | ✅ | Every determinant is a candidate key. |

## 5. Gap Analysis

| Gap | Severity | Recommendation |
|---|---|---|
| Overlapping booking prevention | High | Implement a trigger (`trg_booking_request_no_overlap`) that checks for time overlap with existing approved/checked_in/completed bookings for the same space. |
| Status transition enforcement | Medium | Implement a trigger that validates allowed transitions (e.g., 'pending'→'approved', never 'approved'→'pending'). |
| Maintenance blocking | High | Implement a trigger that rejects booking requests for spaces with active (reported/in_progress) maintenance. |
| Unavailable space blocking | High | Implement a trigger that checks `space.current_status` before allowing new bookings. |
| Rejection reason mandatory | Medium | A CHECK constraint could enforce that when decision='rejected', rejection_reason IS NOT NULL. This can be added to the DDL. |

## 6. Conclusion

The relational schema is a correct and complete translation of the conceptual ERD. All entities, attributes, and relationships are preserved. The schema is normalized to BCNF. Business rules that require real-time validation (overlap prevention, maintenance blocking, status transitions) are **designed to be enforced via triggers** — the DDL provides the structural foundation, while triggers provide the behavioral rules. The schema is ready for implementation.
