-- =============================================================================
-- tx3_advisory_booking.sql
-- Simulates an AUTO booking on a space with an ACTIVE ADVISORY maintenance
-- record overlapping the requested window.
--
-- Expected behaviour:
--   * The advisory does NOT block (BR-12). The booking is AUTO_APPROVED.
--   * The booking records advisory_acknowledged = 1 and an acknowledgement row
--     is written to advisory_acknowledgements for each active advisory.
--
-- Placeholders {{USER_ID}} and {{SPACE_ID}} are replaced by
-- test_concurrency.py at runtime.
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
