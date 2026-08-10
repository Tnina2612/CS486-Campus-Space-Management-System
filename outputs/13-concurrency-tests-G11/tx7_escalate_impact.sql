-- =============================================================================
-- tx7_escalate_impact.sql
-- Simulates a manager escalating a maintenance record from advisory to
-- out-of-service via sp_set_maintenance_impact, concurrent with a booking
-- approval thread targeting the same space and an overlapping time window.
--
-- Placeholder {{MAINTENANCE_ID}} is replaced by test_concurrency.py at runtime.
--
-- Expected behaviour:
--   * Returns ESCALATED on success (impact_level -> out-of-service).
--   * Any failure maps to ESCALATION_FAILED.
--
-- The final SELECT returns result_status so the runner can classify the
-- outcome without parsing ODBC exceptions.
-- =============================================================================
DECLARE @rs NVARCHAR(40) = N'NO_STATUS';

BEGIN TRY
    EXEC dbo.sp_set_maintenance_impact
        @maintenance_id = {{MAINTENANCE_ID}},
        @impact_level   = N'out-of-service';
    SET @rs = N'ESCALATED';
END TRY
BEGIN CATCH
    SET @rs = N'ESCALATION_FAILED';
END CATCH

SELECT ISNULL(@rs, N'NO_STATUS') AS result_status;
GO
