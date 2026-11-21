CREATE TABLE [dw].[DimDate] (
    [DateKey]         INT          NOT NULL,
    [FullDate]        DATE         NOT NULL,
    [CalendarYear]    INT          NOT NULL,
    [CalendarQuarter] INT          NOT NULL,
    [MonthNumber]     INT          NOT NULL,
    [MonthName]       VARCHAR (20) NOT NULL,
    [YearMonth]       CHAR (7)     NOT NULL,
    [DayOfWeekName]   VARCHAR (20) NOT NULL,
    [IsWeekend]       BIT          NOT NULL,
    [Season]          VARCHAR (20) NOT NULL,
    [DayOfWeekNumber] INT          NULL,
    [YearMonthSort]   INT          NULL
);


GO

ALTER TABLE [dw].[DimDate]
    ADD CONSTRAINT [PK_DimDate] PRIMARY KEY NONCLUSTERED ([DateKey] ASC) NOT ENFORCED;


GO

ALTER TABLE [dw].[DimDate]
    ADD CONSTRAINT [UQ_DimDate_FullDate] UNIQUE NONCLUSTERED ([FullDate] ASC) NOT ENFORCED;


GO

CREATE TABLE [dw].[DimProperty] (
    [PropertyKey]     BIGINT        IDENTITY NOT NULL,
    [PropertyCode]    INT           NOT NULL,
    [PropertyName]    VARCHAR (100) NOT NULL,
    [Region]          VARCHAR (50)  NULL,
    [Market]          VARCHAR (100) NULL,
    [PropertyType]    VARCHAR (50)  NULL,
    [LuxuryTier]      VARCHAR (50)  NULL,
    [RoomCount]       INT           NULL,
    [OpenDate]        DATE          NULL,
    [SourceUpdatedAt] DATETIME2 (3) NULL
);


GO

ALTER TABLE [dw].[DimProperty]
    ADD CONSTRAINT [PK_DimProperty] PRIMARY KEY NONCLUSTERED ([PropertyKey] ASC) NOT ENFORCED;


GO

ALTER TABLE [dw].[DimProperty]
    ADD CONSTRAINT [UQ_DimProperty_PropertyCode] UNIQUE NONCLUSTERED ([PropertyCode] ASC) NOT ENFORCED;


GO

CREATE TABLE [dw].[DimGuest] (
    [GuestKey]        BIGINT        IDENTITY NOT NULL,
    [GuestCode]       INT           NOT NULL,
    [GuestSegment]    VARCHAR (50)  NULL,
    [LoyaltyTier]     VARCHAR (50)  NULL,
    [AgeGroup]        VARCHAR (50)  NULL,
    [HomeRegion]      VARCHAR (100) NULL,
    [GuestExternalID] VARCHAR (50)  NULL,
    [GuestName]       VARCHAR (200) NULL,
    [Email]           VARCHAR (200) NULL,
    [SourceUpdatedAt] DATETIME2 (3) NULL
);


GO

ALTER TABLE [dw].[DimGuest]
    ADD CONSTRAINT [PK_DimGuest] PRIMARY KEY NONCLUSTERED ([GuestKey] ASC) NOT ENFORCED;


GO

ALTER TABLE [dw].[DimGuest]
    ADD CONSTRAINT [UQ_DimGuest_GuestCode] UNIQUE NONCLUSTERED ([GuestCode] ASC) NOT ENFORCED;


GO

CREATE TABLE [dw].[DimChannel] (
    [ChannelKey]      BIGINT        IDENTITY NOT NULL,
    [ChannelCode]     INT           NOT NULL,
    [ChannelName]     VARCHAR (100) NOT NULL,
    [ChannelType]     VARCHAR (50)  NULL,
    [SourceUpdatedAt] DATETIME2 (3) NULL
);


GO

ALTER TABLE [dw].[DimChannel]
    ADD CONSTRAINT [PK_DimChannel] PRIMARY KEY NONCLUSTERED ([ChannelKey] ASC) NOT ENFORCED;


GO

ALTER TABLE [dw].[DimChannel]
    ADD CONSTRAINT [UQ_DimChannel_ChannelCode] UNIQUE NONCLUSTERED ([ChannelCode] ASC) NOT ENFORCED;


GO

CREATE TABLE [dw].[DimExperience] (
    [ExperienceKey]   BIGINT        IDENTITY NOT NULL,
    [ExperienceCode]  INT           NOT NULL,
    [ExperienceName]  VARCHAR (100) NOT NULL,
    [ExperienceType]  VARCHAR (100) NULL,
    [SourceUpdatedAt] DATETIME2 (3) NULL
);


GO

ALTER TABLE [dw].[DimExperience]
    ADD CONSTRAINT [PK_DimExperience] PRIMARY KEY NONCLUSTERED ([ExperienceKey] ASC) NOT ENFORCED;


GO

ALTER TABLE [dw].[DimExperience]
    ADD CONSTRAINT [UQ_DimExperience_ExperienceCode] UNIQUE NONCLUSTERED ([ExperienceCode] ASC) NOT ENFORCED;


GO
