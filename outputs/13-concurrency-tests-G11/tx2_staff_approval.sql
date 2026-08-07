-- tx2_staff_approval.sql
-- Simulates a staff member approving a (pre-inserted) booking for Room A
-- 10:00-12:00, which overlaps tx1's 09:00-11:00. It routes through the same
-- safe booking path to demonstrate the lock prevents the overlap.
-- In the test, this represents a second concurrent insertion for the same
-- space and an overlapping window.

DECLARE @bo_id INT NULL;

EXEC dbo.usp_CreateBooking
    @user_id               = @user_id,
    @space_id              = @space_id,
    @start_time            = '2026-09-01 10:00',
    @end_time              = '2026-09-01 12:00',
    @purpose               = 'Lecture',
    @expected_participants = 25,
    @booking_id            = @bo_id OUTPUT;

SELECT @bo_id AS booking_id;