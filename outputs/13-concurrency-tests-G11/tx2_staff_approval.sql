-- =============================================================================
-- tx2_staff_approval.sql
-- Simulates a STAFF member approving a PENDING booking for Room A from 10:00
-- to 12:00 on the test date (overlaps tx1_instant_booking.sql's 09:00-11:00).
-- Exercises the CROSS-FLOW contention: instant booking vs staff approval.
--
-- Placeholders {{PENDING_BOOKING_ID}} and {{STAFF_ID}} are replaced by
-- test_concurrency.py at runtime.
--
-- Expected behaviour:
--   * If this transaction wins the race, the pending booking becomes Approved
--     and the runner returns APPROVED.
--   * If the concurrent instant booking committed first, the procedure raises
--     and the TRY/CATCH maps the outcome to OVERLAP (BR-01 protected).
--
-- The final SELECT returns result_status so the runner can classify the
-- outcome (COMMIT vs REJECTED) without parsing ODBC exceptions.
-- =============================================================================
DECLARE @rs NVARCHAR(40) = N'NO_STATUS';

BEGIN TRY
    EXEC dbo.sp_book_space_staff_approve
        @booking_id    = {{PENDING_BOOKING_ID}},
        @staff_id      = {{STAFF_ID}},
        @decision_note = N'Approved by staff (concurrency test).';
    SET @rs = N'APPROVED';
END TRY
BEGIN CATCH
    SET @rs = N'OVERLAP';
END CATCH

SELECT ISNULL(@rs, N'NO_STATUS') AS result_status;
GO
