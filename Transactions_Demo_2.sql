USE University;
GO
--- Isolation levels
--- | Transaction isolation level | Dirty reads | Nonrepeatable reads | Phantoms |
--- | Read uncommitted	          |       X     |        X            |     X    |
--- | Read committed (default)    |       -     |        X            |     X    |
--- | Repeatable read		      |       -     |        -            |     X    |
--- | Serializable    	          |       -     |        -            |     -    |

-- session ID:
SELECT @@SPID
------
PRINT '--- DEMO 1: Transaction Isolation (READ UNCOMMITTED) ---';
BEGIN TRANSACTION
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT student_id, student_name, department_id
FROM Student
WHERE student_id = 'ST005';
COMMIT TRANSACTION;

PRINT '--- DEMO 2: Transaction Isolation (READ COMMITTED) ---';
BEGIN TRANSACTION
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT student_id, student_name, department_id
FROM Student
WHERE student_id = 'ST005';

WAITFOR DELAY '00:00:10'

SELECT student_id, student_name, department_id
FROM Student
WHERE student_id = 'ST005';
COMMIT;

PRINT '--- DEMO 3: Transaction Isolation (REPEATABLE READ) ---';
BEGIN TRANSACTION
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT student_id, student_name, department_id
FROM Student
WHERE student_id = 'ST005';

WAITFOR DELAY '00:00:10'

SELECT student_id, student_name, department_id
FROM Student
WHERE student_id = 'ST005';
COMMIT;

-- Phantom reads
BEGIN TRANSACTION
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT COUNT(*) FROM Student WHERE department_id = 'CS';
WAITFOR DELAY '00:00:10'
SELECT COUNT(*) FROM Student WHERE department_id = 'CS';
COMMIT;

PRINT '--- DEMO 4: Transaction Isolation (Serializable) ---';
-- Phantom reads
BEGIN TRANSACTION
SET TRANSACTION ISOLATION LEVEL Serializable;
SELECT COUNT(*) FROM Student WHERE department_id = 'CS';
WAITFOR DELAY '00:00:10'
SELECT COUNT(*) FROM Student WHERE department_id = 'CS';
COMMIT;
