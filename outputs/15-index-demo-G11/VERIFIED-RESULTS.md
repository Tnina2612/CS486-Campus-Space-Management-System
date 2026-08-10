# Verified G11 indexing-demo results

These results came from a clean end-to-end run on 11 August 2026 using SQL
Server 2025 (17.0.1000.7), Enterprise Developer Edition. The SQL-only fixture
contained 150,000 Phase 14 `GEN-*` bookings plus 24 Phase 1 sample bookings,
408 total spaces, 4,008 total maintenance records, and 530 advisory
acknowledgements.

Each phase used one warm-up followed by three measured warm-cache runs. The
runner read live `logical_reads` and `cpu_time` counters from
`sys.dm_exec_requests` and measured elapsed time with `SYSUTCDATETIME()`.

| Query | Before reads | After reads | Read reduction | Before ms | After ms | Time reduction | Result check |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: | :--- |
| Booking conflict check | 1,994.00 | 6.00 | 99.70% | 46.332 | < 1 ms | n/a | 1 = 1 |
| Room finder | 106,861.00 | 690.33 | 99.35% | 3,197.582 | 13.333 | 99.58% | 44 = 44 |
| Approved hours per space | 2,011.00 | 594.00 | 70.46% | 352.755 | 161.884 | 54.11% | 408 = 408 |
| Approved bookings by weekday/hour | 2,006.00 | 589.00 | 70.64% | 289.452 | 97.943 | 66.16% | 35 = 35 |

The final visible Room Finder executions reported the following table reads in
SQL Server Messages:

- Before: `bookings` 102,306; `maintenance_records` 4,206;
  `space_facility` 180; facility-list temporary table 91; `spaces` 17.
- After: `bookings` 255; `maintenance_records` 104;
  `space_facility` 180; facility-list temporary table 91; `spaces` 17.

The automated runner also includes the small costs of materializing the 44
Room Finder output rows, so its total is slightly higher than the sum of the
individual target-table reads printed by the showcase statement.

Elapsed/CPU values will vary by machine. Logical reads and unchanged result
counts are the primary reproducible evidence. The final validation also found
zero overlapping demo bookings and zero approved-like bookings overlapping
out-of-service maintenance.
