-- tx1_instant_booking.sql
-- User instantly books Room A 09:00-11:00. Uses the concurrency-safe procedure.
-- This script is parameterized by the Python runner via pyodbc variables.

DECLARE @new_id INT;
EXEC dbo.usp_CreateBooking
    @user_id               = ?,
    @space_id              = ?,
    @start_time            = '2026-09-01 09:00',
    @end_time              = '2026-09-01 11:00',
    @purpose               = 'Seminar',
    @expected_participants = 30,
    @booking_id            = @new_id OUTPUT;

SELECT @new_id AS booking_id;