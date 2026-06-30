# 02 — Conceptual ERD Design

## 1. Entity Inventory (from Step 1)

| # | Entity | Type |
|---|--------|------|
| 1 | USER | Core |
| 2 | SPACE | Core |
| 3 | FACILITY_CATALOG | Core |
| 4 | SPACE_FACILITY | Associative (resolves SPACE ⟷ FACILITY_CATALOG M:N) |
| 5 | FACILITY_ASSET | Core |
| 6 | BOOKING | Core |
| 7 | APPROVAL | Core |
| 8 | USAGE_SESSION | Core |
| 9 | MAINTENANCE_RECORD | Core |

## 2. Attributes (Conceptual Types)

### USER
- `user_id` (integer, PK)
- `full_name` (string)
- `email` (string) "UK"
- `phone` (string)
- `role` (string)
- `department` (string)
- `account_status` (string)

### SPACE
- `space_code` (string, PK)
- `space_name` (string)
- `space_type` (string)
- `building` (string)
- `floor` (integer)
- `room_number` (string)
- `capacity` (integer)
- `current_status` (string)
- `usage_policy` (string)

### FACILITY_CATALOG
- `catalog_id` (integer, PK)
- `facility_name` (string)
- `description` (string)
- `is_trackable` (boolean)

### SPACE_FACILITY
- `space_code` (string, PK)
- `catalog_id` (integer, PK)
- `quantity` (integer)

### FACILITY_ASSET
- `asset_id` (integer, PK)
- `asset_tag` (string) "UK"
- `status` (string)

### BOOKING
- `booking_id` (integer, PK)
- `requested_start` (datetime)
- `requested_end` (datetime)
- `purpose` (string)
- `expected_participants` (integer)
- `status` (string)
- `created_at` (datetime)

### APPROVAL
- `approval_id` (integer, PK)
- `decision_time` (datetime)
- `decision_note` (string)
- `rejection_reason` (string)

### USAGE_SESSION
- `session_id` (integer, PK)
- `actual_start_time` (datetime)
- `initial_condition` (string)
- `actual_end_time` (datetime)
- `final_condition` (string)
- `usage_notes` (string)

### MAINTENANCE_RECORD
- `maintenance_id` (integer, PK)
- `problem_description` (string)
- `problem_category` (string)
- `start_time` (datetime)
- `completion_time` (datetime)
- `status` (string)
- `result_note` (string)

## 3. Relationships & Participation Constraints (Crow's Foot)

| Left Entity | Crow's Foot | Right Entity | Crow's Foot | Label | Description |
|-------------|-------------|--------------|-------------|-------|-------------|
| USER | `||` | BOOKING | `o{` | submits | A booking must have exactly one requester. A user may have zero or many bookings. |
| SPACE | `||` | BOOKING | `o{` | hosts | A booking must reference exactly one space. A space may have zero or many bookings. |
| SPACE | `||` | SPACE_FACILITY | `o{` | contains | Each SPACE_FACILITY row belongs to exactly one space. A space may have zero or many facility entries. |
| FACILITY_CATALOG | `||` | SPACE_FACILITY | `o{` | categorized_as | Each SPACE_FACILITY row references exactly one catalog entry. A catalog entry may appear in zero or many space mappings. |
| FACILITY_CATALOG | `||` | FACILITY_ASSET | `o{` | defines | Each asset belongs to exactly one catalog type. A catalog type may have zero or many assets. |
| SPACE | `||` | FACILITY_ASSET | `o{` | located_in | Each asset is located in exactly one space. A space may contain zero or many assets. |
| BOOKING | `|o` | APPROVAL | `||` | has | An approval belongs to exactly one booking. A booking may have zero or one approval. |
| BOOKING | `|o` | USAGE_SESSION | `||` | records | A usage session belongs to exactly one booking. A booking may have zero or one usage session. |
| USER | `||` | APPROVAL | `o{` | reviews | An approval must have exactly one reviewer. A user may review zero or many approvals. |
| USER | `||` | USAGE_SESSION | `o{` | checks_in | A usage session must have exactly one check-in staff. A staff may check in zero or many sessions. |
| USER | `|o` | USAGE_SESSION | `o{` | checks_out | A usage session may have zero or one check-out staff. A staff may check out zero or many sessions. |
| SPACE | `||` | MAINTENANCE_RECORD | `o{` | undergoes | Each maintenance record references exactly one space. A space may have zero or many maintenance records. |
| USER | `||` | MAINTENANCE_RECORD | `o{` | reports | Each maintenance record must have one reporter. A user may report zero or many issues. |
| USER | `|o` | MAINTENANCE_RECORD | `o{` | assigned_to | A maintenance record may have zero or one assigned staff. A staff may be assigned to zero or many tasks. |

## 4. Entity-Relationship Diagram (Mermaid erDiagram)

erDiagram
    USER {
        int user_id PK
        string full_name
        string email "UK"
        string phone
        string role
        string department
        string account_status
    }
    SPACE {
        string space_code PK
        string space_name
        string space_type
        string building
        int floor
        string room_number
        int capacity
        string current_status
        string usage_policy
    }
    FACILITY_CATALOG {
        int catalog_id PK
        string facility_name
        string description
        boolean is_trackable
    }
    SPACE_FACILITY {
        string space_code PK
        int catalog_id PK
        int quantity
    }
    FACILITY_ASSET {
        int asset_id PK
        string asset_tag "UK"
        string status
    }
    BOOKING {
        int booking_id PK
        datetime requested_start
        datetime requested_end
        string purpose
        int expected_participants
        string status
        datetime created_at
    }
    APPROVAL {
        int approval_id PK
        datetime decision_time
        string decision_note
        string rejection_reason
    }
    USAGE_SESSION {
        int session_id PK
        datetime actual_start_time
        string initial_condition
        datetime actual_end_time
        string final_condition
        string usage_notes
    }
    MAINTENANCE_RECORD {
        int maintenance_id PK
        string problem_description
        string problem_category
        datetime start_time
        datetime completion_time
        string status
        string result_note
    }
    USER ||--o{ BOOKING : submits
    SPACE ||--o{ BOOKING : hosts
    SPACE ||--o{ SPACE_FACILITY : contains
    FACILITY_CATALOG ||--o{ SPACE_FACILITY : categorized_as
    FACILITY_CATALOG ||--o{ FACILITY_ASSET : defines
    SPACE ||--o{ FACILITY_ASSET : located_in
    BOOKING |o--|| APPROVAL : has
    BOOKING |o--|| USAGE_SESSION : records
    USER ||--o{ APPROVAL : reviews
    USER ||--o{ USAGE_SESSION : checks_in
    USER |o--o{ USAGE_SESSION : checks_out
    SPACE ||--o{ MAINTENANCE_RECORD : undergoes
    USER ||--o{ MAINTENANCE_RECORD : reports
    USER |o--o{ MAINTENANCE_RECORD : assigned_to

## 5. Self-Review Checklist

| Criterion | Result |
|-----------|--------|
| Every entity in ERD matches Step 1 entity list | Pass |
| Every relationship in ERD matches Step 1 relationship list | Pass |
| No foreign keys listed as attributes | Pass |
| No entity or relationship unsupported by Step 1 | Pass |
| All entity names are UPPERCASE singular nouns | Pass |
| All attribute names are snake_case | Pass |
| Conceptual types used (string, integer, boolean, datetime) | Pass |
| Mermaid syntax valid (no %% comments, raw diagram text) | Pass |
| No orphan entities | Pass |
| Every entity has a PK | Pass |

## 6. Assumptions and Gaps

- The `USAGE_SESSION` entity has two USER references (checked_in_by, checked_out_by). These are modeled as two separate named relationships (`checks_in` with mandatory participation, `checks_out` with optional participation) consistent with Step 1.
- The `MAINTENANCE_RECORD` entity has two USER references (reporter_id, assigned_staff_id) modeled as separate named relationships (`reports` with mandatory participation, `assigned_to` with optional participation), consistent with Step 1.
- No gaps identified between Step 1 and Step 2.
