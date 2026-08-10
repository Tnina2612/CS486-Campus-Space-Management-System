USE University;
GO

-- --- DEMO 1: TRANSACTION ISOLATION (READ UNCOMMITTED) ---
-- Scenario: Demonstrate how uncommitted changes can be seen by another session
-- if its isolation level is set to READ UNCOMMITTED.
-- To properly observe this, open two query windows.

-- session ID:
SELECT @@SPID
------
PRINT '--- DEMO 1: Transaction Isolation (READ UNCOMMITTED) ---';
-- Initial state for ST005
SELECT student_id, student_name, department_id
FROM Student
WHERE student_id = 'ST005';

GO
CREATE PROCEDURE department_transfer(@studentID varchar(9), @todeparmentId varchar(5))
AS
BEGIN TRANSACTION;
    
    PRINT 'Transaction started.';

    -- Update the student's department but DO NOT ROLLBACK yet
    UPDATE Student
    SET department_id =  @todeparmentId
    WHERE student_id = @studentID;

    PRINT 'Waiting for 05 seconds.';
    WAITFOR DELAY '00:00:05'; -- Simulate a delay for another session to read
    PRINT 'Delay finished.';

    ROLLBACK;
    PRINT 'Transaction rollbacked successfully.';
GO
exec department_transfer 'ST005', 'AI';
-- drop proc department_transfer;

PRINT '--- DEMO 2: Transaction Isolation (READ COMMITTED) ---';
GO
CREATE PROCEDURE department_transfer_commit(@studentID varchar(9), @todeparmentId varchar(5))
AS
BEGIN TRANSACTION;
    -- Update the student's department 
    UPDATE Student
    SET department_id =  @todeparmentId
    WHERE student_id = @studentID;
    COMMIT;
GO
exec department_transfer_commit 'ST005', 'AI';
--exec department_transfer_commit 'ST005', NULL;

-- drop proc department_transfer_commit;

PRINT '--- DEMO 3: Transaction Isolation (REPEATABLE READ) ---';
exec department_transfer_commit 'ST005', 'IS';

BEGIN TRANSACTION;
    -- Add new student
    INSERT INTO Student VALUES ('ST021', 'New Student', 'M', '2004/01/01', '23TT3', 'CS');
    COMMIT;

BEGIN TRANSACTION;
    -- delete new student
DELETE FROM Student
WHERE student_id = 'ST021';
COMMIT;

-- Verify final state
PRINT 'Final state of ST005 after commit:';
SELECT student_id, student_name, department_id
FROM Student
WHERE student_id = 'ST005';
