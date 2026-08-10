-- =============================================================================
-- tx5_staff_approval_b.sql
-- Simulates a SECOND STAFF member approving a DIFFERENT PENDING booking that
-- overlaps the same space+time window as the booking approved in
-- tx2_staff_approval.sql. This tests STAFF vs STAFF contention: two staff
-- members must not independently approve two different pending bookings that
-- would create an overlap (BR-01).
--
-- Placeholders {{PENDING_BOOKING_ID_B}} and {{STAFF_ID_B}} are replaced by
-- test_concurrency.py at runtime.
--
-- Expected behaviour:
--   * If this transaction wins the race, its pending booking becomes Approved.
--   * If the other staff member's approval committed first, the procedure
--     raises and the TRY/CATCH maps the outcome to OVERLAP.
--
-- The final SELECT returns result_status so the runner can classify the
-- outcome (COMMIT vs REJECTED) without parsing ODBC exceptions.
-- =============================================================================
DECLARE @rs NVARCHAR(40) = N'NO_STATUS';

BEGIN TRY
    EXEC dbo.sp_book_space_staff_approve
        @booking_id    = {{PENDING_BOOKING_ID_B}},
        @staff_id      = {{STAFF_ID_B}},
        @decision_note = N'Approved by staff B (concurrency test).';
    SET @rs = N'APPROVED';
END TRY
BEGIN CATCH
    SET @rs = N'OVERLAP';
END CATCH

SELECT ISNULL(@rs, N'NO_STATUS') AS result_status;
GO
