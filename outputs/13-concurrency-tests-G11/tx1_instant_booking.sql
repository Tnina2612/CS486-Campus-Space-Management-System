-- =============================================================================
-- tx1_instant_booking.sql
-- Simulates USER A instantly booking Room A (space "TEST-ROOM-A")
-- from 09:00 to 11:00 on the test date.
--
-- Placeholders {{USER_ID}}, {{SPACE_ID}}, {{SYSTEM_STAFF_ID}} are replaced by
-- test_concurrency.py at runtime so the same file stays readable.
--
-- Expected behaviour:
--   * If this transaction wins the race, it commits (returns @booking_id).
--   * If a concurrent approved booking already overlaps, the procedure raises
--     error 50002 and the transaction rolls back.
-- =============================================================================
EXEC dbo.usp_CreateInstantBooking
    @user_id               = {{USER_ID}},
    @space_id              = {{SPACE_ID}},
    @start_time            = '{{TEST_DATE}} 09:00:00',
    @end_time              = '{{TEST_DATE}} 11:00:00',
    @purpose               = N'Seminar',
    @expected_participants = 10,
    @system_staff_id       = {{SYSTEM_STAFF_ID}},
    @booking_id            = NULL;
GO
