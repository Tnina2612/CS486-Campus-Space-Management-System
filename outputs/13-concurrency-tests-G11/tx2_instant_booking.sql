-- =============================================================================
-- tx2_instant_booking.sql
-- Simulates USER B auto-booking Room A (space "TEST-ROOM-A") from 10:00 to
-- 12:00 on the test date via sp_AutoApproveBookingRequest. This window overlaps
-- tx1_instant_booking.sql (09:00-11:00), exercising the SAME-FLOW race
-- (two concurrent instant bookings).
--
-- Placeholders {{USER_ID}} and {{SPACE_ID}} are replaced by
-- test_concurrency.py at runtime.
--
-- Expected behaviour:
--   * If this transaction wins the race it commits and returns AUTO_APPROVED.
--   * If the concurrent instant booking committed first, the procedure raises
--     and the TRY/CATCH maps the outcome to OVERLAP (BR-01 protected).
--
-- The final SELECT returns result_status so the runner can classify the
-- outcome (COMMIT vs REJECTED) without parsing ODBC exceptions.
-- =============================================================================
DECLARE @rs NVARCHAR(40) = N'NO_STATUS';

BEGIN TRY
    EXEC dbo.sp_AutoApproveBookingRequest
        @user_id               = {{USER_ID}},
        @space_id              = {{SPACE_ID}},
        @start_time            = '{{TEST_DATE}} 10:00:00',
        @end_time              = '{{TEST_DATE}} 12:00:00',
        @purpose               = N'Workshop',
        @expected_participants = 12;
    SET @rs = N'AUTO_APPROVED';
END TRY
BEGIN CATCH
    SET @rs = N'OVERLAP';
END CATCH

SELECT ISNULL(@rs, N'NO_STATUS') AS result_status;
GO
