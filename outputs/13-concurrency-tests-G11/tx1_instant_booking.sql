-- =============================================================================
-- tx1_instant_booking.sql
-- Simulates USER A auto-booking Room A (space "TEST-ROOM-A")
-- from 09:00 to 11:00 on the test date.
--
-- Placeholders {{USER_ID}} and {{SPACE_ID}} are replaced by
-- test_concurrency.py at runtime so the same file stays readable.
--
-- Expected behaviour:
--   * If this transaction wins the race, it commits and returns @booking_id.
--   * If a concurrent approved booking already overlaps, the procedure sets
--     @result_status = 'OVERLAP' and rolls back (BR-01 protected).
--   * If the space's AutoBookingEnabled is 0, @result_status = 'AUTO_BOOKING_DISABLED'
--     and no booking is created.
--
-- The last statement returns @result_status as a single-column result set so
-- test_concurrency.py can classify the outcome (COMMIT vs REJECTED) without
-- relying on exception propagation across pyodbc multi-statement batches.
-- =============================================================================
DECLARE @rs  NVARCHAR(40);
DECLARE @bid INT;

EXEC dbo.sp_AutoApproveBookingRequest
    @user_id               = {{USER_ID}},
    @space_id              = {{SPACE_ID}},
    @start_time            = '{{TEST_DATE}} 09:00:00',
    @end_time              = '{{TEST_DATE}} 11:00:00',
    @purpose               = N'Seminar',
    @expected_participants = 10,
    @result_status         = @rs OUTPUT,
    @booking_id            = @bid OUTPUT;

SELECT ISNULL(@rs, N'NO_STATUS') AS result_status;
GO
