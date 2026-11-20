SET NOCOUNT ON;
SET XACT_ABORT ON;

IF @@TRANCOUNT <> 0
    THROW 50000, 'Run this script without an existing transaction.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'ops.Booking') IS NOT NULL
        OR OBJECT_ID(N'ops.Channel') IS NOT NULL
        OR OBJECT_ID(N'ops.Experience') IS NOT NULL
        OR OBJECT_ID(N'ops.Guest') IS NOT NULL
        OR OBJECT_ID(N'ops.Property') IS NOT NULL
        OR OBJECT_ID(N'ops.PropertyDailyInventory') IS NOT NULL
        OR OBJECT_ID(N'ops.SatisfactionSurvey') IS NOT NULL
        OR OBJECT_ID(N'ops.StayNight') IS NOT NULL
        THROW 50001, 'One or more target ops objects already exist. Use a database where all eight target names are unused; no existing objects will be changed.', 1;

    IF SCHEMA_ID(N'ops') IS NULL
        EXEC sys.sp_executesql N'CREATE SCHEMA [ops] AUTHORIZATION [dbo];';

    CREATE TABLE [ops].[Channel]
    (
        [channel_id] int IDENTITY(1,1) NOT NULL,
        [channel_code] int NOT NULL,
        [channel_name] nvarchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
        [channel_type] nvarchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
        [created_at_utc] datetime2(3) NOT NULL CONSTRAINT [DF_ops_Channel_created_at_utc] DEFAULT (sysutcdatetime()),
        [updated_at_utc] datetime2(3) NOT NULL,
        [is_deleted] bit NOT NULL CONSTRAINT [DF_ops_Channel_is_deleted] DEFAULT ((0)),
        [source_batch_id] uniqueidentifier NULL,
        CONSTRAINT [PK_ops_Channel] PRIMARY KEY CLUSTERED ([channel_id] ASC),
        CONSTRAINT [UQ_ops_Channel_channel_code] UNIQUE NONCLUSTERED ([channel_code] ASC)
    );

    CREATE TABLE [ops].[Experience]
    (
        [experience_id] int IDENTITY(1,1) NOT NULL,
        [experience_code] int NOT NULL,
        [experience_name] nvarchar(150) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
        [experience_type] nvarchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
        [created_at_utc] datetime2(3) NOT NULL CONSTRAINT [DF_ops_Experience_created_at_utc] DEFAULT (sysutcdatetime()),
        [updated_at_utc] datetime2(3) NOT NULL,
        [is_deleted] bit NOT NULL CONSTRAINT [DF_ops_Experience_is_deleted] DEFAULT ((0)),
        [source_batch_id] uniqueidentifier NULL,
        CONSTRAINT [PK_ops_Experience] PRIMARY KEY CLUSTERED ([experience_id] ASC),
        CONSTRAINT [UQ_ops_Experience_code] UNIQUE NONCLUSTERED ([experience_code] ASC)
    );

    CREATE TABLE [ops].[Guest]
    (
        [guest_id] int IDENTITY(1,1) NOT NULL,
        [guest_code] int NOT NULL,
        [guest_segment] nvarchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
        [loyalty_tier] nvarchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
        [age_group] nvarchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
        [home_region] nvarchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
        [guest_external_id] nvarchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
        [guest_name] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
        [email] nvarchar(320) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
        [created_at_utc] datetime2(3) NOT NULL CONSTRAINT [DF_ops_Guest_created_at_utc] DEFAULT (sysutcdatetime()),
        [updated_at_utc] datetime2(3) NOT NULL,
        [is_deleted] bit NOT NULL CONSTRAINT [DF_ops_Guest_is_deleted] DEFAULT ((0)),
        [source_batch_id] uniqueidentifier NULL,
        CONSTRAINT [PK_ops_Guest] PRIMARY KEY CLUSTERED ([guest_id] ASC),
        CONSTRAINT [UQ_ops_Guest_code] UNIQUE NONCLUSTERED ([guest_code] ASC)
    );

    CREATE TABLE [ops].[Property]
    (
        [property_id] int IDENTITY(1,1) NOT NULL,
        [property_code] int NOT NULL,
        [property_name] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
        [region] nvarchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
        [market] nvarchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
        [property_type] nvarchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
        [luxury_tier] nvarchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
        [room_count] int NOT NULL,
        [open_date] date NOT NULL,
        [created_at_utc] datetime2(3) NOT NULL CONSTRAINT [DF_ops_Property_created_at_utc] DEFAULT (sysutcdatetime()),
        [updated_at_utc] datetime2(3) NOT NULL,
        [is_deleted] bit NOT NULL CONSTRAINT [DF_ops_Property_is_deleted] DEFAULT ((0)),
        [source_batch_id] uniqueidentifier NULL,
        CONSTRAINT [PK_ops_Property] PRIMARY KEY CLUSTERED ([property_id] ASC),
        CONSTRAINT [UQ_ops_Property_code] UNIQUE NONCLUSTERED ([property_code] ASC)
    );

    CREATE TABLE [ops].[Booking]
    (
        [booking_id] bigint NOT NULL,
        [booking_date_key] int NOT NULL,
        [stay_date_key] int NOT NULL,
        [property_code] int NOT NULL,
        [guest_code] int NOT NULL,
        [channel_code] int NOT NULL,
        [experience_code] int NULL,
        [nights_stayed] int NOT NULL,
        [rooms_booked] int NOT NULL,
        [room_revenue] decimal(18,2) NOT NULL,
        [experience_revenue] decimal(18,2) NOT NULL,
        [other_revenue] decimal(18,2) NOT NULL,
        [discount_amount] decimal(18,2) NOT NULL,
        [cancellation_amount] decimal(18,2) NOT NULL,
        [is_cancelled] bit NOT NULL,
        [is_loyalty_booking] bit NOT NULL,
        [created_at_utc] datetime2(3) NOT NULL CONSTRAINT [DF_ops_Booking_created_at_utc] DEFAULT (sysutcdatetime()),
        [updated_at_utc] datetime2(3) NOT NULL,
        [is_deleted] bit NOT NULL CONSTRAINT [DF_ops_Booking_is_deleted] DEFAULT ((0)),
        [source_batch_id] uniqueidentifier NULL,
        [booking_date] date NOT NULL,
        [check_out_date] date NOT NULL,
        [check_in_date] date NOT NULL,
        CONSTRAINT [PK_ops_Booking] PRIMARY KEY CLUSTERED ([booking_id] ASC)
    );

    CREATE NONCLUSTERED INDEX [IX_ops_Booking_updated]
        ON [ops].[Booking] ([updated_at_utc] ASC);

    CREATE TABLE [ops].[PropertyDailyInventory]
    (
        [property_inventory_id] bigint IDENTITY(1,1) NOT NULL,
        [property_code] int NOT NULL,
        [inventory_date] date NOT NULL,
        [room_capacity] int NOT NULL,
        [rooms_out_of_service] int NOT NULL,
        [rooms_sellable] int NOT NULL,
        [created_at_utc] datetime2(3) NOT NULL CONSTRAINT [DF_ops_PropertyDailyInventory_created_at_utc] DEFAULT (sysutcdatetime()),
        [updated_at_utc] datetime2(3) NOT NULL CONSTRAINT [DF_ops_PropertyDailyInventory_updated_at_utc] DEFAULT (sysutcdatetime()),
        [is_deleted] bit NOT NULL CONSTRAINT [DF_ops_PropertyDailyInventory_is_deleted] DEFAULT ((0)),
        [source_batch_id] uniqueidentifier NULL,
        CONSTRAINT [PK_ops_PropertyDailyInventory] PRIMARY KEY CLUSTERED ([property_inventory_id] ASC),
        CONSTRAINT [UQ_ops_PropertyDailyInventory_property_date] UNIQUE NONCLUSTERED ([property_code] ASC, [inventory_date] ASC),
        CONSTRAINT [CK_ops_PropertyDailyInventory_capacity] CHECK ([room_capacity] >= (0)),
        CONSTRAINT [CK_ops_PropertyDailyInventory_math] CHECK ([rooms_sellable] = ([room_capacity] - [rooms_out_of_service])),
        CONSTRAINT [CK_ops_PropertyDailyInventory_oos] CHECK ([rooms_out_of_service] >= (0)),
        CONSTRAINT [CK_ops_PropertyDailyInventory_oos_capacity] CHECK ([rooms_out_of_service] <= [room_capacity]),
        CONSTRAINT [CK_ops_PropertyDailyInventory_sellable] CHECK ([rooms_sellable] >= (0))
    );

    CREATE TABLE [ops].[SatisfactionSurvey]
    (
        [survey_id] bigint NOT NULL,
        [stay_date_key] int NOT NULL,
        [property_code] int NOT NULL,
        [guest_code] int NOT NULL,
        [channel_code] int NOT NULL,
        [satisfaction_score] decimal(5,2) NOT NULL,
        [service_score] decimal(5,2) NOT NULL,
        [cleanliness_score] decimal(5,2) NOT NULL,
        [value_score] decimal(5,2) NOT NULL,
        [would_recommend] bit NOT NULL,
        [survey_date] date NULL,
        [created_at_utc] datetime2(3) NOT NULL CONSTRAINT [DF_ops_SatisfactionSurvey_created_at_utc] DEFAULT (sysutcdatetime()),
        [updated_at_utc] datetime2(3) NOT NULL,
        [is_deleted] bit NOT NULL CONSTRAINT [DF_ops_SatisfactionSurvey_is_deleted] DEFAULT ((0)),
        [source_batch_id] uniqueidentifier NULL,
        [stay_date] date NOT NULL,
        CONSTRAINT [PK_ops_SatisfactionSurvey] PRIMARY KEY CLUSTERED ([survey_id] ASC)
    );

    CREATE NONCLUSTERED INDEX [IX_ops_Survey_updated]
        ON [ops].[SatisfactionSurvey] ([updated_at_utc] ASC);

    CREATE TABLE [ops].[StayNight]
    (
        [stay_night_id] bigint IDENTITY(1,1) NOT NULL,
        [booking_id] bigint NOT NULL,
        [property_code] int NOT NULL,
        [stay_date] date NOT NULL,
        [night_number] int NOT NULL,
        [rooms_occupied] int NOT NULL,
        [created_at_utc] datetime2(3) NOT NULL CONSTRAINT [DF_ops_StayNight_created_at_utc] DEFAULT (sysutcdatetime()),
        [updated_at_utc] datetime2(3) NOT NULL CONSTRAINT [DF_ops_StayNight_updated_at_utc] DEFAULT (sysutcdatetime()),
        [is_deleted] bit NOT NULL CONSTRAINT [DF_ops_StayNight_is_deleted] DEFAULT ((0)),
        [source_batch_id] uniqueidentifier NULL,
        [room_revenue] decimal(18,2) NULL,
        [experience_revenue] decimal(18,2) NULL,
        [other_revenue] decimal(18,2) NULL,
        [discount_amount] decimal(18,2) NULL,
        CONSTRAINT [PK_ops_StayNight] PRIMARY KEY CLUSTERED ([stay_night_id] ASC),
        CONSTRAINT [UQ_ops_StayNight_booking_date] UNIQUE NONCLUSTERED ([booking_id] ASC, [stay_date] ASC),
        CONSTRAINT [CK_ops_StayNight_night_number] CHECK ([night_number] > (0)),
        CONSTRAINT [CK_ops_StayNight_rooms] CHECK ([rooms_occupied] > (0))
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT SCHEMA_NAME([schema_id]) AS [SchemaName], [name] AS [TableName]
FROM sys.tables
WHERE [schema_id] = SCHEMA_ID(N'ops')
    AND [name] IN (N'Booking', N'Channel', N'Experience', N'Guest', N'Property',
        N'PropertyDailyInventory', N'SatisfactionSurvey', N'StayNight')
ORDER BY [name];