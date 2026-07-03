# Conceptual ERD Design - G11

## 1. Entities (extracted from Step 1)

1. USER
2. SPACE
3. FACILITY_CATALOG
4. SPACE_FACILITY (Associative Entity)
5. FACILITY_ASSET
6. BOOKING
7. APPROVAL
8. USAGE_SESSION
9. MAINTENANCE_RECORD

## 2. Relationships (extracted from Step 1)

| Left Entity | Min | Max | Crow's Foot (L) | Crow's Foot (R) | Min | Max | Right Entity | Label |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| USER | 1 | 1 | `||` | `o{` | 0 | N | BOOKING | makes |
| SPACE | 1 | 1 | `||` | `o{` | 0 | N | BOOKING | has |
| SPACE | 1 | 1 | `||` | `o{` | 0 | N | SPACE_FACILITY | contains |
| FACILITY_CATALOG | 1 | 1 | `||` | `o{` | 0 | N | SPACE_FACILITY | categorized_by |
| SPACE | 1 | 1 | `||` | `o{` | 0 | N | FACILITY_ASSET | tracks |
| FACILITY_CATALOG | 1 | 1 | `||` | `o{` | 0 | N | FACILITY_ASSET | describes |
| BOOKING | 1 | 1 | `||` | `o|` | 0 | 1 | APPROVAL | approved_by |
| BOOKING | 1 | 1 | `||` | `o|` | 0 | 1 | USAGE_SESSION | recorded_as |
| SPACE | 1 | 1 | `||` | `o{` | 0 | N | MAINTENANCE_RECORD | undergoes |
| USER | 1 | 1 | `||` | `o{` | 0 | N | MAINTENANCE_RECORD | reports |
| USER | 1 | 1 | `||` | `o{` | 0 | N | MAINTENANCE_RECORD | assigned_to |

## 3. Mermaid ER Diagram

```mermaid
erDiagram
    USER ||--o{ BOOKING : makes
    SPACE ||--o{ BOOKING : has
    SPACE ||--o{ SPACE_FACILITY : contains
    FACILITY_CATALOG ||--o{ SPACE_FACILITY : categorized_by
    SPACE ||--o{ FACILITY_ASSET : tracks
    FACILITY_CATALOG ||--o{ FACILITY_ASSET : describes
    BOOKING ||--o| APPROVAL : approved_by
    BOOKING ||--o| USAGE_SESSION : recorded_as
    SPACE ||--o{ MAINTENANCE_RECORD : undergoes
    USER ||--o{ MAINTENANCE_RECORD : reports
    USER ||--o{ MAINTENANCE_RECORD : assigned_to

    USER {
        string user_id PK
        string full_name
        string email
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
        string floor
        string room_number
        integer capacity
        string current_status
        string usage_policy
    }
    FACILITY_CATALOG {
        string catalog_id PK
        string facility_name
        boolean is_trackable
    }
    SPACE_FACILITY {
        string space_code PK "FK"
        string catalog_id PK "FK"
        integer quantity
    }
    FACILITY_ASSET {
        string asset_tag PK
        string space_code FK
        string catalog_id FK
        string status
    }
    BOOKING {
        string booking_id PK
        string user_id FK
        string space_code FK
        datetime start_time
        datetime end_time
        string purpose
        integer expected_participants
        string status
    }
    APPROVAL {
        string approval_id PK
        string booking_id FK "UK"
        string staff_id FK
        datetime decision_time
        string decision_note
        string rejection_reason
    }
    USAGE_SESSION {
        string session_id PK
        string booking_id FK "UK"
        string staff_id FK
        datetime actual_start_time
        datetime actual_end_time
        string initial_condition
        string final_condition
        string usage_notes
    }
    MAINTENANCE_RECORD {
        string maintenance_id PK
        string space_code FK
        string reporter_id FK
        string assigned_staff_id FK
        string problem_description
        datetime start_time
        datetime completion_time
        string status
        string result_note
    }
```

## 4. Assumptions and Gaps

- **Maintenance status values** are not enumerated in Step 1 (OQ-01). The ERD uses a generic `string status` without constraints.
- **Account status values** are not enumerated in Step 1 (OQ-02). Same approach — generic `string`.
- No ISA/subtype hierarchies exist in Step 1.
- The `floor` attribute is typed as `string` to accommodate non-numeric values (e.g., "G" for ground).
