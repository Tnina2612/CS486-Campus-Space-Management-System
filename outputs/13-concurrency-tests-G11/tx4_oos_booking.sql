-- =============================================================================
-- tx4_oos_booking.sql
-- Simulates an AUTO booking on a space with an ACTIVE OUT-OF-SERVICE
-- maintenance record overlapping the requested window.
--
-- Expected behaviour:
--   * The out-of-service maintenance BLOCKS the booking (BR-11 / INV-2).
--   * The procedure raises and the TRY/CATCH maps the outcome to
--     OUT_OF_SERVICE; no booking row is written.
--
-- Placeholders {{USER_ID}} and {{SPACE_ID}} are replaced by
-- test_concurrency.py at runtime.
-- =============================================================================
DECLARE @rs NVARCHAR(40) = N'NO_STATUS';

BEGIN TRY
    EXEC dbo.sp_AutoApproveBookingRequest
        @user_id               = {{USER_ID}},
        @space_id              = {{SPACE_ID}},
        @start_time            = '{{TEST_DATE}} 09:00:00',
        @end_time              = '{{TEST_DATE}} 11:00:00',
        @purpose               = N'Seminar',
        @expected_participants = 10;
    SET @rs = N'AUTO_APPROVED';
END TRY
BEGIN CATCH
    SET @rs = N'OUT_OF_SERVICE';
END CATCH

SELECT ISNULL(@rs, N'NO_STATUS') AS result_status;
GO
