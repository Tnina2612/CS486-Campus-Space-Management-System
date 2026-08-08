-- =============================================================================
-- tx2_staff_approval.sql
-- Simulates STAFF approving a PENDING booking for Room A
-- from 10:00 to 12:00 on the test date (overlaps tx1's 09:00-11:00).
--
-- Placeholder {{PENDING_BOOKING_ID}} identifies the pending booking created by
-- test_concurrency.py during the setup phase; {{STAFF_ID}} is the approving
-- staff member.
--
-- Expected behaviour:
--   * If this transaction wins the race, the pending booking becomes Approved.
--   * If tx1 committed first, the overlap check raises error 50002 and the
--     approval is rejected (BR-01 protected).
-- =============================================================================
EXEC dbo.usp_ApproveBooking
    @booking_id    = {{PENDING_BOOKING_ID}},
    @staff_id      = {{STAFF_ID}},
    @decision_note = N'Approved by staff (concurrency test).';
GO
