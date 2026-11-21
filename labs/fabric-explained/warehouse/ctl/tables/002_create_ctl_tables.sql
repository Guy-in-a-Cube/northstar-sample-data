CREATE TABLE [ctl].[LoadRun] (
    [LoadRunID]    VARCHAR (36)   NOT NULL,
    [PipelineName] VARCHAR (200)  NOT NULL,
    [LoadStartUTC] DATETIME2 (3)  NOT NULL,
    [LoadEndUTC]   DATETIME2 (3)  NULL,
    [LoadStatus]   VARCHAR (20)   NOT NULL,
    [ErrorMessage] VARCHAR (4000) NULL
);


GO

ALTER TABLE [ctl].[LoadRun]
    ADD CONSTRAINT [PK_LoadRun] PRIMARY KEY NONCLUSTERED ([LoadRunID] ASC) NOT ENFORCED;


GO

CREATE TABLE [ctl].[LoadRunDetail] (
    [LoadRunID]    VARCHAR (36)   NOT NULL,
    [ObjectName]   VARCHAR (200)  NOT NULL,
    [ObjectType]   VARCHAR (50)   NOT NULL,
    [RowsAffected] BIGINT         NULL,
    [TotalRows]    BIGINT         NULL,
    [StepStartUTC] DATETIME2 (3)  NOT NULL,
    [StepEndUTC]   DATETIME2 (3)  NULL,
    [StepStatus]   VARCHAR (20)   NOT NULL,
    [ErrorMessage] VARCHAR (4000) NULL
);


GO

ALTER TABLE [ctl].[LoadRunDetail]
    ADD CONSTRAINT [FK_LoadRunDetail_LoadRun] FOREIGN KEY ([LoadRunID]) REFERENCES [ctl].[LoadRun] ([LoadRunID]) NOT ENFORCED;


GO
