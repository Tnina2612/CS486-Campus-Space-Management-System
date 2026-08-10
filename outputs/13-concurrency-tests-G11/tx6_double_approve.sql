-- =============================================================================
-- tx6_double_approve.sql
-- Simulates a staff member approving the SAME @booking_id as another concurrent
-- thread (double-approve). Exercises that exactly one approval row is recorded
-- for a booking.
--
-- Placeholders {{PENDING_BOOKING_ID}} and {{STAFF_ID}} are replaced by
-- test_concurrency.py at runtime.
--
-- Expected behaviour:
--   * The first caller to commit sees APPROVED (booking transitions Pending ->
--     Approved; one approvals row inserted).
--   * The second caller finds the booking no longer Pending; the procedure
--     raises and the TRY/CATCH maps the outcome to NOT_PENDING.
--
-- The final SELECT returns result_status so the runner can classify the
-- outcome without parsing ODBC exceptions.
-- =============================================================================
DECLARE @rs NVARCHAR(40) = N'NO_STATUS';

BEGIN TRY
    EXEC dbo.sp_book_space_staff_approve
        @booking_id    = {{PENDING_BOOKING_ID}},
        @staff_id      = {{STAFF_ID}},
        @decision_note = N'Double-approve test.';
    SET @rs = N'APPROVED';
END TRY
BEGIN CATCH
    SET @rs = N'NOT_PENDING';
END CATCH

SELECT ISNULL(@rs, N'NO_STATUS') AS result_status;
GO
