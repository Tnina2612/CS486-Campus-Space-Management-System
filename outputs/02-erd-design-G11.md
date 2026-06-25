# Conceptual ERD Design

## Group
G11

## Overview
This conceptual ERD models the Campus Space Management System using Crow's Foot notation. The design follows the "Catalog vs. Asset Hybrid Pattern" for facility management: a general `facility_catalog` defines item types, `space_facility` maps catalogs to spaces with quantities, and `facility_asset` individually tracks high-value items.

---

## Entity Summary

| Entity | Description |
|---|---|
| User | A person with a university account (student, lecturer, TA, staff, admin, manager) |
| Space | A bookable physical space (classroom, lab, meeting room, auditorium, etc.) |
| FacilityCatalog | A catalog entry defining a type of facility item (e.g., 'Projector') |
| SpaceFacility | Associative entity linking Space and FacilityCatalog with quantity |
| FacilityAsset | An individually tracked physical asset linked to a catalog and space |
| Booking | A request to use a space for a specific time period |
| BookingApproval | The decision record for a booking (approval/rejection) |
| BookingSession | Check-in/check-out record for a completed booking |
| MaintenanceRecord | A maintenance issue reported for a space |

---

## Mermaid ER Diagram

```mermaid
erDiagram
    User {
        int user_id PK
        string full_name
        string email
        string phone
        string role
        string department
        string account_status
    }

    Space {
        string space_code PK
        string space_name
        string space_type
        string building
        int floor
        string room_number
        int capacity
        string status
        text usage_policy
    }

    FacilityCatalog {
        int catalog_id PK
        string name
        string description
        bit is_trackable
    }

    SpaceFacility {
        int id PK
        string space_code FK
        int catalog_id FK
        int quantity
    }

    FacilityAsset {
        int asset_id PK
        int catalog_id FK
        string space_code FK
        string asset_tag UK
        string status
    }

    Booking {
        int booking_id PK
        string space_code FK
        int requester_id FK
        datetime requested_start
        datetime requested_end
        text purpose
        int participants
        string booking_type
        string status
    }

    BookingApproval {
        int approval_id PK
        int booking_id FK
        int approver_id FK
        datetime decision_time
        text decision_note
        text rejection_reason
    }

    BookingSession {
        int session_id PK
        int booking_id FK
        datetime actual_start
        int checked_in_by FK
        text initial_condition
        datetime actual_end
        int completed_by FK
        text final_condition
        text usage_notes
    }

    MaintenanceRecord {
        int maintenance_id PK
        string space_code FK
        int reporter_id FK
        int assigned_to FK
        text problem_description
        string problem_type
        datetime start_time
        datetime completion_time
        string status
        text result_note
    }

    User ||--o{ Booking : submits
    User ||--o{ BookingApproval : approves
    User ||--o{ BookingSession : "checks in"
    User ||--o{ BookingSession : "checks out"
    User ||--o{ MaintenanceRecord : reports
    User ||--o{ MaintenanceRecord : "assigned to"

    Space ||--o{ Booking : "is booked in"
    Space ||--o{ MaintenanceRecord : undergoes
    Space ||--o{ SpaceFacility : contains
    Space ||--o{ FacilityAsset : houses

    FacilityCatalog ||--o{ SpaceFacility : "cataloged in"
    FacilityCatalog ||--o{ FacilityAsset : "type of"

    Booking ||--o| BookingApproval : has
    Booking ||--o| BookingSession : results_in
```

---

## Relationship Details

| Relationship | Entity 1 | Cardinality | Entity 2 | Cardinality | Participation |
|---|---|---|---|---|---|
| User submits Booking | User | 1 | Booking | N | User: optional, Booking: mandatory |
| User approves Booking | User | 1 | BookingApproval | N | User: optional, BookingApproval: mandatory |
| User checks in BookingSession | User | 1 | BookingSession | N | User: optional, BookingSession: optional |
| User checks out BookingSession | User | 1 | BookingSession | N | User: optional, BookingSession: optional |
| User reports Maintenance | User | 1 | MaintenanceRecord | N | User: optional, MaintenanceRecord: mandatory |
| User assigned to Maintenance | User | 1 | MaintenanceRecord | N | User: optional, MaintenanceRecord: optional |
| Space has Booking | Space | 1 | Booking | N | Space: mandatory, Booking: mandatory |
| Space has Maintenance | Space | 1 | MaintenanceRecord | N | Space: mandatory, MaintenanceRecord: mandatory |
| Space has SpaceFacility | Space | 1 | SpaceFacility | N | Space: mandatory, SpaceFacility: optional |
| Space houses FacilityAsset | Space | 1 | FacilityAsset | N | Space: mandatory, FacilityAsset: optional |
| FacilityCatalog in SpaceFacility | FacilityCatalog | 1 | SpaceFacility | N | FacilityCatalog: mandatory, SpaceFacility: optional |
| FacilityCatalog is type of FacilityAsset | FacilityCatalog | 1 | FacilityAsset | N | FacilityCatalog: mandatory, FacilityAsset: mandatory |
| Booking has BookingApproval | Booking | 1 | BookingApproval | 0..1 | Booking: optional, BookingApproval: mandatory |
| Booking results in BookingSession | Booking | 1 | BookingSession | 0..1 | Booking: optional, BookingSession: mandatory |

---

## Hybrid Pattern Visual Summary

```
Space ──1:N──► SpaceFacility ◄──N:1── FacilityCatalog
  │                                     │
  │1:N                                  │1:N
  └────────────────────────────────────► FacilityAsset
```

- **SpaceFacility** resolves the M:N between Space and FacilityCatalog with a `quantity` attribute.
- **FacilityAsset** handles 1:N tracking for high-value items (when `is_trackable = 1`).
