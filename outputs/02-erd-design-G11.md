# Conceptual ERD Design — G11

## Entities Extracted from Step 1

1. USER
2. SPACE
3. FACILITY_CATALOG
4. SPACE_FACILITY (Associative Entity)
5. FACILITY_ASSET
6. BOOKING
7. APPROVAL
8. USAGE_SESSION
9. MAINTENANCE

## Relationships Extracted from Step 1

| # | Entity 1 | Relationship | Entity 2 | Cardinality |
|---|----------|------------|----------|-------------|
| 1 | USER | makes | BOOKING | 1:N |
| 2 | SPACE | hosts | BOOKING | 1:N |
| 3 | BOOKING | is decided by | APPROVAL | 1:0..1 |
| 4 | BOOKING | has session | USAGE_SESSION | 1:0..1 |
| 5 | USER (staff) | decides | APPROVAL | 1:N |
| 6 | USER (staff) | checks in | USAGE_SESSION | 1:N |
| 7 | SPACE | contains (via SPACE_FACILITY) | FACILITY_CATALOG | M:N |
| 8 | FACILITY_CATALOG | classifies | FACILITY_ASSET | 1:N |
| 9 | SPACE | houses | FACILITY_ASSET | 1:N |
| 10 | SPACE | undergoes | MAINTENANCE | 1:N |
| 11 | USER (reporter) | reports | MAINTENANCE | 1:N |
| 12 | USER (assigned staff) | assigned to | MAINTENANCE | 0..1:N |

## Entity Verification Against Step 1

All 9 entities and 12 relationships listed above appear in the Step 1 analysis. No unsupported elements introduced.

## Conceptual ERD (Mermaid erDiagram — Crow's Foot Notation)

erDiagram
  USER {
    string user_id PK
    string full_name
    string email "UK"
    string phone_number
    string role
    string department
    string account_status
  }
  SPACE {
    string space_code PK
    string space_name
    string space_type
    string building
    integer floor
    string room_number
    integer capacity
    string current_status
    string usage_policy
  }
  FACILITY_CATALOG {
    string catalog_id PK
    string name "UK"
    string description
    boolean is_trackable
  }
  SPACE_FACILITY {
    string space_code PK
    string catalog_id PK
    integer quantity
  }
  FACILITY_ASSET {
    string asset_id PK
    string asset_tag "UK"
    string status
  }
  BOOKING {
    string booking_id PK
    datetime requested_start_time
    datetime requested_end_time
    string purpose
    integer expected_participants
    string booking_type
    string status
  }
  APPROVAL {
    string approval_id PK
    string decision
    datetime decision_time
    string decision_note
    string rejection_reason
  }
  USAGE_SESSION {
    string session_id PK
    datetime actual_start_time
    string initial_condition
    datetime actual_end_time
    string final_condition
    string usage_notes
  }
  MAINTENANCE {
    string maintenance_id PK
    string problem_description
    string problem_type
    datetime start_time
    datetime completion_time
    string status
    string result_note
  }
  USER }o--|| BOOKING : makes
  SPACE }o--|| BOOKING : hosts
  BOOKING |o--|| APPROVAL : is_decided_by
  BOOKING |o--|| USAGE_SESSION : has_session
  USER }o--|| APPROVAL : decides
  USER }o--|| USAGE_SESSION : checks_in
  SPACE }o--|| SPACE_FACILITY : contains
  FACILITY_CATALOG }o--|| SPACE_FACILITY : categorizes
  FACILITY_CATALOG }o--|| FACILITY_ASSET : classifies
  SPACE }o--|| FACILITY_ASSET : houses
  SPACE }o--|| MAINTENANCE : undergoes
  USER }o--|| MAINTENANCE : reports
  USER }o--o| MAINTENANCE : assigned_to

## Participation Constraints (Crow's Foot)

| Relationship | Entity | Min | Max | Constraint |
|-------------|--------|-----|-----|------------|
| makes (USER→BOOKING) | USER | 0 | N | Optional on USER side |
| makes (USER→BOOKING) | BOOKING | 1 | 1 | Mandatory on BOOKING side |
| hosts (SPACE→BOOKING) | SPACE | 0 | N | Optional on SPACE side |
| hosts (SPACE→BOOKING) | BOOKING | 1 | 1 | Mandatory on BOOKING side |
| is_decided_by (BOOKING→APPROVAL) | BOOKING | 0 | 1 | Optional on BOOKING side |
| is_decided_by (BOOKING→APPROVAL) | APPROVAL | 1 | 1 | Mandatory on APPROVAL side |
| has_session (BOOKING→USAGE_SESSION) | BOOKING | 0 | 1 | Optional on BOOKING side |
| has_session (BOOKING→USAGE_SESSION) | USAGE_SESSION | 1 | 1 | Mandatory on USAGE_SESSION side |
| decides (USER→APPROVAL) | USER | 0 | N | Optional on USER side |
| decides (USER→APPROVAL) | APPROVAL | 1 | 1 | Mandatory on APPROVAL side |
| checks_in (USER→USAGE_SESSION) | USER | 0 | N | Optional on USER side |
| checks_in (USER→USAGE_SESSION) | USAGE_SESSION | 1 | 1 | Mandatory on USAGE_SESSION side |
| contains (SPACE→SPACE_FACILITY) | SPACE | 0 | N | Optional on SPACE side |
| contains (SPACE→SPACE_FACILITY) | SPACE_FACILITY | 1 | 1 | Mandatory on SPACE_FACILITY side |
| categorizes (FC→SPACE_FACILITY) | FACILITY_CATALOG | 0 | N | Optional on FC side |
| categorizes (FC→SPACE_FACILITY) | SPACE_FACILITY | 1 | 1 | Mandatory on SPACE_FACILITY side |
| classifies (FC→FACILITY_ASSET) | FACILITY_CATALOG | 0 | N | Optional on FC side |
| classifies (FC→FACILITY_ASSET) | FACILITY_ASSET | 1 | 1 | Mandatory on FA side |
| houses (SPACE→FACILITY_ASSET) | SPACE | 0 | N | Optional on SPACE side |
| houses (SPACE→FACILITY_ASSET) | FACILITY_ASSET | 1 | 1 | Mandatory on FA side |
| undergoes (SPACE→MAINTENANCE) | SPACE | 0 | N | Optional on SPACE side |
| undergoes (SPACE→MAINTENANCE) | MAINTENANCE | 1 | 1 | Mandatory on MAINTENANCE side |
| reports (USER→MAINTENANCE) | USER | 0 | N | Optional on USER side |
| reports (USER→MAINTENANCE) | MAINTENANCE | 1 | 1 | Mandatory on MAINTENANCE side |
| assigned_to (USER→MAINTENANCE) | USER | 0 | N | Optional on USER side |
| assigned_to (USER→MAINTENANCE) | MAINTENANCE | 0 | 1 | Optional on MAINTENANCE side |

## Assumptions and Gaps

- SPACE_FACILITY.quantity represents the count of non-trackable items of that catalog type in the space.
- FACILITY_ASSET does not include FK attributes in the conceptual model because relationships handle the links.
- The USER→MAINTENANCE relationship appears twice with distinct roles: one for reporter (mandatory) and one for assigned staff (optional). These are semantically distinct and shown as separate relationship lines.
- The USER→USAGE_SESSION relationship (checked_in_by) is explicitly included — the staff member who performs check-in is distinct from the requester.
- No gap: all 9 entities and 12 relationships from Step 1 are fully represented.
