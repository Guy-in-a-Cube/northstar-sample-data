CREATE PROCEDURE [ctl].[usp_start_load_run]
    @LoadRunID    varchar(36),
    @PipelineName varchar(200)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [ctl].[LoadRun]
    (
        [LoadRunID],
        [PipelineName],
        [LoadStartUTC],
        [LoadStatus]
    )
    VALUES
    (
        @LoadRunID,
        @PipelineName,
        SYSUTCDATETIME(),
        'Running'
    );
END;


/* ============================================================
   LOG LOAD STEP
   ============================================================ */

GO

CREATE PROCEDURE [ctl].[usp_log_load_step]
    @LoadRunID    varchar(36),
    @ObjectName   varchar(200),
    @ObjectType   varchar(50),
    @RowsAffected bigint,
    @TotalRows    bigint,
    @StepStartUTC datetime2(3),
    @StepStatus   varchar(20),
    @ErrorMessage varchar(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [ctl].[LoadRunDetail]
    (
        [LoadRunID],
        [ObjectName],
        [ObjectType],
        [RowsAffected],
        [TotalRows],
        [StepStartUTC],
        [StepEndUTC],
        [StepStatus],
        [ErrorMessage]
    )
    VALUES
    (
        @LoadRunID,
        @ObjectName,
        @ObjectType,
        @RowsAffected,
        @TotalRows,
        @StepStartUTC,
        SYSUTCDATETIME(),
        @StepStatus,
        @ErrorMessage
    );
END;


/* ============================================================
   COMPLETE LOAD RUN
   ============================================================ */

GO

CREATE PROCEDURE [ctl].[usp_complete_load_run]
    @LoadRunID varchar(36)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [ctl].[LoadRun]
    SET
        [LoadEndUTC] = SYSUTCDATETIME(),
        [LoadStatus] = 'Success'
    WHERE [LoadRunID] = @LoadRunID;
END;


/* ============================================================
   FAIL LOAD RUN
   ============================================================ */

GO

CREATE PROCEDURE [ctl].[usp_fail_load_run]
    @LoadRunID    varchar(36),
    @ErrorMessage varchar(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [ctl].[LoadRun]
    SET
        [LoadEndUTC]   = SYSUTCDATETIME(),
        [LoadStatus]   = 'Failed',
        [ErrorMessage] = @ErrorMessage
    WHERE [LoadRunID] = @LoadRunID;
END;

GO
