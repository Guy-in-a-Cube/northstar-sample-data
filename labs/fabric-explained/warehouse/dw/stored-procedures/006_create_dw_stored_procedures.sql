CREATE   PROCEDURE [dw].[usp_load_dim_date]
    @LoadRunID VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    /* ============================================================
       Purpose
       Maintain the Date dimension required by the analytical model.

       Source:
           Date ranges derived from landed operational data and
           other analytical sources.

       Target:
           dw.DimDate

       Responsibility:
           Ensure the Date dimension covers the complete date range
           required by all warehouse facts.

       Behavior:
           - Determine the minimum and maximum required dates
           - Generate any missing calendar dates
           - Preserve existing Date dimension rows
       ============================================================ */

    DECLARE @StepStartUTC DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsAffected BIGINT;
    DECLARE @TotalRows BIGINT;
    DECLARE @ErrorMessage NVARCHAR(4000);

    DECLARE @StartDate DATE;
    DECLARE @EndDate   DATE;

    BEGIN TRY

        SELECT
            @StartDate = MIN(DateValue),
            @EndDate   = MAX(DateValue)
        FROM
        (
            SELECT MIN(booking_date) AS DateValue
            FROM [lh_northstar].[landing].[Booking]
            WHERE is_deleted = 0

            UNION ALL

            SELECT MAX(check_out_date)
            FROM [lh_northstar].[landing].[Booking]
            WHERE is_deleted = 0

            UNION ALL

            SELECT MIN(stay_date)
            FROM [lh_northstar].[landing].[StayNight]
            WHERE is_deleted = 0

            UNION ALL

            SELECT MAX(stay_date)
            FROM [lh_northstar].[landing].[StayNight]
            WHERE is_deleted = 0

            UNION ALL

            SELECT MIN(inventory_date)
            FROM [lh_northstar].[landing].[PropertyDailyInventory]
            WHERE is_deleted = 0

            UNION ALL

            SELECT MAX(inventory_date)
            FROM [lh_northstar].[landing].[PropertyDailyInventory]
            WHERE is_deleted = 0

            UNION ALL

            SELECT MIN(stay_date)
            FROM [lh_northstar].[landing].[SatisfactionSurvey]
            WHERE is_deleted = 0

            UNION ALL

            SELECT MAX(stay_date)
            FROM [lh_northstar].[landing].[SatisfactionSurvey]
            WHERE is_deleted = 0

            UNION ALL

            SELECT MIN(BudgetMonth)
            FROM [PropertyBudget].[dbo].[Property Budget]

            UNION ALL

            SELECT MAX(BudgetMonth)
            FROM [PropertyBudget].[dbo].[Property Budget]
        ) AS DateRange;

        IF @StartDate IS NULL OR @EndDate IS NULL
        BEGIN
            THROW 51001,
                'Unable to determine DimDate range from source data.',
                1;
        END;

        WITH
        d0 AS
        (
            SELECT n
            FROM
            (
                VALUES
                    (0),(1),(2),(3),(4),
                    (5),(6),(7),(8),(9)
            ) AS v(n)
        ),
        Numbers AS
        (
            SELECT
                  a.n
                + b.n * 10
                + c.n * 100
                + d.n * 1000 AS n
            FROM d0 AS a
            CROSS JOIN d0 AS b
            CROSS JOIN d0 AS c
            CROSS JOIN d0 AS d
        ),
        Dates AS
        (
            SELECT
                DATEADD(DAY, n, @StartDate) AS FullDate
            FROM Numbers
            WHERE n <= DATEDIFF(DAY, @StartDate, @EndDate)
        )
        INSERT INTO [dw].[DimDate]
        (
            [DateKey],
            [FullDate],
            [CalendarYear],
            [CalendarQuarter],
            [MonthNumber],
            [MonthName],
            [YearMonth],
            [YearMonthSort],
            [DayOfWeekName],
            [DayOfWeekNumber],
            [IsWeekend],
            [Season]
        )
        SELECT
              YEAR(dt.FullDate) * 10000
            + MONTH(dt.FullDate) * 100
            + DAY(dt.FullDate),

            dt.FullDate,

            YEAR(dt.FullDate),

            DATEPART(QUARTER, dt.FullDate),

            MONTH(dt.FullDate),

            DATENAME(MONTH, dt.FullDate),

            LEFT(CONVERT(VARCHAR(10), dt.FullDate, 23), 7),

            /* YearMonthSort: YYYYMM */
            (YEAR(dt.FullDate) * 100) + MONTH(dt.FullDate),

            DATENAME(WEEKDAY, dt.FullDate),

            /* Monday = 1 through Sunday = 7 */
            (DATEDIFF(
                DAY,
                CAST('19000101' AS DATE),
                dt.FullDate
            ) % 7) + 1,

            CASE
                WHEN DATENAME(WEEKDAY, dt.FullDate)
                     IN ('Saturday', 'Sunday')
                THEN 1
                ELSE 0
            END,

            CASE
                WHEN MONTH(dt.FullDate) IN (12, 1, 2) THEN 'Winter'
                WHEN MONTH(dt.FullDate) IN (3, 4, 5) THEN 'Spring'
                WHEN MONTH(dt.FullDate) IN (6, 7, 8) THEN 'Summer'
                ELSE 'Fall'
            END

        FROM Dates AS dt
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM [dw].[DimDate] AS existing
            WHERE existing.FullDate = dt.FullDate
        );

        SET @RowsAffected = @@ROWCOUNT;

        SELECT
            @TotalRows = COUNT_BIG(*)
        FROM [dw].[DimDate];

        EXEC [ctl].[usp_log_load_step]
            @LoadRunID    = @LoadRunID,
            @ObjectName   = 'dw.DimDate',
            @ObjectType   = 'Dimension',
            @RowsAffected = @RowsAffected,
            @TotalRows    = @TotalRows,
            @StepStartUTC = @StepStartUTC,
            @StepStatus   = 'Success',
            @ErrorMessage = NULL;

        SELECT
            @RowsAffected AS RowsAffected,
            MIN(FullDate) AS FirstDate,
            MAX(FullDate) AS LastDate,
            @TotalRows AS TotalDimensionRows
        FROM [dw].[DimDate];

    END TRY
    BEGIN CATCH

        SET @ErrorMessage = ERROR_MESSAGE();

        EXEC [ctl].[usp_log_load_step]
            @LoadRunID    = @LoadRunID,
            @ObjectName   = 'dw.DimDate',
            @ObjectType   = 'Dimension',
            @RowsAffected = NULL,
            @TotalRows    = NULL,
            @StepStartUTC = @StepStartUTC,
            @StepStatus   = 'Failed',
            @ErrorMessage = @ErrorMessage;

        THROW;

    END CATCH;
END;

GO

CREATE   PROCEDURE [dw].[usp_load_dim_property]
    @LoadRunID VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    /* ============================================================
       Purpose
       Load the current-state Property dimension from the Fabric
       Warehouse landing schema.

       Source:
           [lh_northstar].[landing].[Property]
           Populated incrementally from Azure SQL by Copy Job

       Target:
           dw.DimProperty

       Grain:
           One row per PropertyCode

       Responsibility:
           Transform landed operational property data into the
           analytics-ready Property dimension.

       Behavior:
           - Insert new properties
           - Update changed properties
           - Preserve the warehouse surrogate PropertyKey
           - Do not physically delete dimension members
       ============================================================ */

    DECLARE @StepStartUTC DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsAffected BIGINT;
    DECLARE @TotalRows BIGINT;
    DECLARE @ErrorMessage NVARCHAR(4000);

    BEGIN TRY

        MERGE dw.DimProperty AS tgt
        USING
        (
            SELECT
                property_code,
                property_name,
                region,
                market,
                property_type,
                luxury_tier,
                room_count,
                open_date,
                updated_at_utc
            FROM [lh_northstar].[landing].[Property]
            WHERE is_deleted = 0
        ) AS src
            ON tgt.PropertyCode = src.property_code

        WHEN MATCHED
             AND
             (
                 tgt.SourceUpdatedAt IS NULL
                 OR src.updated_at_utc > tgt.SourceUpdatedAt
             )
        THEN UPDATE SET
            tgt.PropertyName    = src.property_name,
            tgt.Region          = src.region,
            tgt.Market          = src.market,
            tgt.PropertyType    = src.property_type,
            tgt.LuxuryTier      = src.luxury_tier,
            tgt.RoomCount       = src.room_count,
            tgt.OpenDate        = src.open_date,
            tgt.SourceUpdatedAt = src.updated_at_utc

        WHEN NOT MATCHED BY TARGET
        THEN INSERT
        (
            PropertyCode,
            PropertyName,
            Region,
            Market,
            PropertyType,
            LuxuryTier,
            RoomCount,
            OpenDate,
            SourceUpdatedAt
        )
        VALUES
        (
            src.property_code,
            src.property_name,
            src.region,
            src.market,
            src.property_type,
            src.luxury_tier,
            src.room_count,
            src.open_date,
            src.updated_at_utc
        );

        SET @RowsAffected = @@ROWCOUNT;

        SELECT
            @TotalRows = COUNT_BIG(*)
        FROM dw.DimProperty;

        EXEC ctl.usp_log_load_step
            @LoadRunID    = @LoadRunID,
            @ObjectName   = 'dw.DimProperty',
            @ObjectType   = 'Dimension',
            @RowsAffected = @RowsAffected,
            @TotalRows    = @TotalRows,
            @StepStartUTC = @StepStartUTC,
            @StepStatus   = 'Success',
            @ErrorMessage = NULL;

        SELECT
            @RowsAffected AS RowsAffected,
            @TotalRows AS TotalDimensionRows;

    END TRY
    BEGIN CATCH

        SET @ErrorMessage = ERROR_MESSAGE();

        EXEC ctl.usp_log_load_step
            @LoadRunID    = @LoadRunID,
            @ObjectName   = 'dw.DimProperty',
            @ObjectType   = 'Dimension',
            @RowsAffected = NULL,
            @TotalRows    = NULL,
            @StepStartUTC = @StepStartUTC,
            @StepStatus   = 'Failed',
            @ErrorMessage = @ErrorMessage;

        THROW;

    END CATCH;
END;

GO

CREATE   PROCEDURE [dw].[usp_load_dim_guest]
    @LoadRunID VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    /* ============================================================
       Purpose
       Load the current-state Guest dimension from the Fabric
       Warehouse landing schema.

       Source:
           [lh_northstar].[landing].[Guest]
           Populated incrementally from Azure SQL by Copy Job

       Target:
           dw.DimGuest

       Grain:
           One row per GuestCode

       Responsibility:
           Transform landed operational guest data into the
           analytics-ready Guest dimension.

       Behavior:
           - Insert new guests
           - Update changed guests
           - Preserve the warehouse surrogate GuestKey
           - Do not physically delete dimension members
       ============================================================ */

    DECLARE @StepStartUTC DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsAffected BIGINT;
    DECLARE @TotalRows BIGINT;
    DECLARE @ErrorMessage NVARCHAR(4000);

    BEGIN TRY

        MERGE dw.DimGuest AS tgt
        USING
        (
            SELECT
                guest_code,
                guest_segment,
                loyalty_tier,
                age_group,
                home_region,
                guest_external_id,
                guest_name,
                email,
                updated_at_utc
            FROM [lh_northstar].[landing].[Guest]
            WHERE is_deleted = 0
        ) AS src
            ON tgt.GuestCode = src.guest_code

        WHEN MATCHED
             AND
             (
                 tgt.SourceUpdatedAt IS NULL
                 OR src.updated_at_utc > tgt.SourceUpdatedAt
             )
        THEN UPDATE SET
            tgt.GuestSegment    = src.guest_segment,
            tgt.LoyaltyTier     = src.loyalty_tier,
            tgt.AgeGroup        = src.age_group,
            tgt.HomeRegion      = src.home_region,
            tgt.GuestExternalID = src.guest_external_id,
            tgt.GuestName       = src.guest_name,
            tgt.Email           = src.email,
            tgt.SourceUpdatedAt = src.updated_at_utc

        WHEN NOT MATCHED BY TARGET
        THEN INSERT
        (
            GuestCode,
            GuestSegment,
            LoyaltyTier,
            AgeGroup,
            HomeRegion,
            GuestExternalID,
            GuestName,
            Email,
            SourceUpdatedAt
        )
        VALUES
        (
            src.guest_code,
            src.guest_segment,
            src.loyalty_tier,
            src.age_group,
            src.home_region,
            src.guest_external_id,
            src.guest_name,
            src.email,
            src.updated_at_utc
        );

        SET @RowsAffected = @@ROWCOUNT;

        SELECT
            @TotalRows = COUNT_BIG(*)
        FROM dw.DimGuest;

        EXEC ctl.usp_log_load_step
            @LoadRunID    = @LoadRunID,
            @ObjectName   = 'dw.DimGuest',
            @ObjectType   = 'Dimension',
            @RowsAffected = @RowsAffected,
            @TotalRows    = @TotalRows,
            @StepStartUTC = @StepStartUTC,
            @StepStatus   = 'Success',
            @ErrorMessage = NULL;

        SELECT
            @RowsAffected AS RowsAffected,
            @TotalRows AS TotalDimensionRows;

    END TRY
    BEGIN CATCH

        SET @ErrorMessage = ERROR_MESSAGE();

        EXEC ctl.usp_log_load_step
            @LoadRunID    = @LoadRunID,
            @ObjectName   = 'dw.DimGuest',
            @ObjectType   = 'Dimension',
            @RowsAffected = NULL,
            @TotalRows    = NULL,
            @StepStartUTC = @StepStartUTC,
            @StepStatus   = 'Failed',
            @ErrorMessage = @ErrorMessage;

        THROW;

    END CATCH;
END;

GO

CREATE   PROCEDURE [dw].[usp_load_dim_channel]
    @LoadRunID VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    /* ============================================================
       Purpose
       Load the current-state Channel dimension from the Fabric
       Warehouse landing schema.

       Source:
           [lh_northstar].[landing].[Channel]
           Populated incrementally from Azure SQL by Copy Job

       Target:
           dw.DimChannel

       Grain:
           One row per ChannelCode

       Responsibility:
           Transform landed channel data into the analytics-ready
           Channel dimension.

       Behavior:
           - Insert new channels
           - Update changed channels
           - Preserve the warehouse surrogate ChannelKey
           - Exclude source rows marked as deleted
       ============================================================ */

    DECLARE @StepStartUTC DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsAffected BIGINT;
    DECLARE @TotalRows BIGINT;
    DECLARE @ErrorMessage NVARCHAR(4000);

    BEGIN TRY

        MERGE dw.DimChannel AS tgt
        USING
        (
            SELECT
                channel_code,
                channel_name,
                channel_type,
                updated_at_utc
            FROM [lh_northstar].[landing].[Channel]
            WHERE is_deleted = 0
        ) AS src
            ON tgt.ChannelCode = src.channel_code

        WHEN MATCHED
             AND
             (
                 tgt.SourceUpdatedAt IS NULL
                 OR src.updated_at_utc > tgt.SourceUpdatedAt
             )
        THEN UPDATE SET
            tgt.ChannelName     = src.channel_name,
            tgt.ChannelType     = src.channel_type,
            tgt.SourceUpdatedAt = src.updated_at_utc

        WHEN NOT MATCHED BY TARGET
        THEN INSERT
        (
            ChannelCode,
            ChannelName,
            ChannelType,
            SourceUpdatedAt
        )
        VALUES
        (
            src.channel_code,
            src.channel_name,
            src.channel_type,
            src.updated_at_utc
        );

        SET @RowsAffected = @@ROWCOUNT;

        SELECT
            @TotalRows = COUNT_BIG(*)
        FROM dw.DimChannel;

        EXEC ctl.usp_log_load_step
            @LoadRunID    = @LoadRunID,
            @ObjectName   = 'dw.DimChannel',
            @ObjectType   = 'Dimension',
            @RowsAffected = @RowsAffected,
            @TotalRows    = @TotalRows,
            @StepStartUTC = @StepStartUTC,
            @StepStatus   = 'Success',
            @ErrorMessage = NULL;

        SELECT
            @RowsAffected AS RowsAffected,
            @TotalRows AS TotalDimensionRows;

    END TRY
    BEGIN CATCH

        SET @ErrorMessage = ERROR_MESSAGE();

        EXEC ctl.usp_log_load_step
            @LoadRunID    = @LoadRunID,
            @ObjectName   = 'dw.DimChannel',
            @ObjectType   = 'Dimension',
            @RowsAffected = NULL,
            @TotalRows    = NULL,
            @StepStartUTC = @StepStartUTC,
            @StepStatus   = 'Failed',
            @ErrorMessage = @ErrorMessage;

        THROW;

    END CATCH;
END;

GO

CREATE   PROCEDURE [dw].[usp_load_dim_experience]
    @LoadRunID VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StepStartUTC DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsAffected BIGINT;
    DECLARE @TotalRows BIGINT;
    DECLARE @ErrorMessage NVARCHAR(4000);

    BEGIN TRY

        MERGE dw.DimExperience AS tgt
        USING
        (
            SELECT
                experience_code,
                experience_name,
                experience_type,
                updated_at_utc
            FROM [lh_northstar].[landing].[Experience]
            WHERE is_deleted = 0
        ) AS src
            ON tgt.ExperienceCode = src.experience_code

        WHEN MATCHED
             AND
             (
                 tgt.SourceUpdatedAt IS NULL
                 OR src.updated_at_utc > tgt.SourceUpdatedAt
             )
        THEN UPDATE SET
            tgt.ExperienceName  = src.experience_name,
            tgt.ExperienceType  = src.experience_type,
            tgt.SourceUpdatedAt = src.updated_at_utc

        WHEN NOT MATCHED BY TARGET
        THEN INSERT
        (
            ExperienceCode,
            ExperienceName,
            ExperienceType,
            SourceUpdatedAt
        )
        VALUES
        (
            src.experience_code,
            src.experience_name,
            src.experience_type,
            src.updated_at_utc
        );

        SET @RowsAffected = @@ROWCOUNT;

        SELECT
            @TotalRows = COUNT_BIG(*)
        FROM dw.DimExperience;

        EXEC ctl.usp_log_load_step
            @LoadRunID    = @LoadRunID,
            @ObjectName   = 'dw.DimExperience',
            @ObjectType   = 'Dimension',
            @RowsAffected = @RowsAffected,
            @TotalRows    = @TotalRows,
            @StepStartUTC = @StepStartUTC,
            @StepStatus   = 'Success',
            @ErrorMessage = NULL;

        SELECT
            @RowsAffected AS RowsAffected,
            @TotalRows AS TotalDimensionRows;

    END TRY
    BEGIN CATCH

        SET @ErrorMessage = ERROR_MESSAGE();

        EXEC ctl.usp_log_load_step
            @LoadRunID    = @LoadRunID,
            @ObjectName   = 'dw.DimExperience',
            @ObjectType   = 'Dimension',
            @RowsAffected = NULL,
            @TotalRows    = NULL,
            @StepStartUTC = @StepStartUTC,
            @StepStatus   = 'Failed',
            @ErrorMessage = @ErrorMessage;

        THROW;

    END CATCH;
END;

GO

CREATE   PROCEDURE [dw].[usp_load_fact_booking]
    @LoadRunID VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    /* ============================================================
       Purpose
       Load the Booking fact table from the Fabric Warehouse
       landing schema.

       Source:
           [lh_northstar].[landing].[Booking]
           Populated incrementally from Azure SQL by Copy Job

       Target:
           dw.FactBooking

       Grain:
           One row per reservation

       Responsibility:
           Transform landed reservation data into an
           analytics-ready booking fact.

           This fact represents reservation behavior and
           cancellation economics.

           Realized stay revenue belongs to dw.FactStayNight.

       Behavior:
           - Insert new reservations
           - Update changed reservations
           - Resolve warehouse dimension surrogate keys
           - Exclude source rows marked as deleted
       ============================================================ */

    DECLARE @StepStartUTC DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsAffected BIGINT;
    DECLARE @TotalRows BIGINT;
    DECLARE @ErrorMessage NVARCHAR(4000);

    BEGIN TRY

        MERGE dw.FactBooking AS tgt
        USING
        (
            SELECT
                b.booking_id,

                  YEAR(b.booking_date) * 10000
                + MONTH(b.booking_date) * 100
                + DAY(b.booking_date) AS BookingDateKey,

                  YEAR(b.check_in_date) * 10000
                + MONTH(b.check_in_date) * 100
                + DAY(b.check_in_date) AS CheckInDateKey,

                  YEAR(b.check_out_date) * 10000
                + MONTH(b.check_out_date) * 100
                + DAY(b.check_out_date) AS CheckOutDateKey,

                p.PropertyKey,
                g.GuestKey,
                c.ChannelKey,
                COALESCE(e.ExperienceKey, noexp.ExperienceKey) AS ExperienceKey,

                b.nights_stayed,
                b.rooms_booked,
                b.cancellation_amount,
                b.is_cancelled,
                b.is_loyalty_booking,
                b.updated_at_utc

            FROM [lh_northstar].[landing].[Booking] AS b

            INNER JOIN dw.DimProperty AS p
                ON b.property_code = p.PropertyCode

            INNER JOIN dw.DimGuest AS g
                ON b.guest_code = g.GuestCode

            INNER JOIN dw.DimChannel AS c
                ON b.channel_code = c.ChannelCode

            LEFT JOIN dw.DimExperience AS e
                ON b.experience_code = e.ExperienceCode

            CROSS JOIN dw.DimExperience AS noexp
             WHERE noexp.ExperienceCode = 0
               AND b.is_deleted = 0
        ) AS src
            ON tgt.BookingID = src.booking_id

        WHEN MATCHED
             AND
             (
                 tgt.SourceUpdatedAt IS NULL
                 OR src.updated_at_utc > tgt.SourceUpdatedAt
             )
        THEN UPDATE SET
            tgt.BookingDateKey     = src.BookingDateKey,
            tgt.CheckInDateKey     = src.CheckInDateKey,
            tgt.CheckOutDateKey    = src.CheckOutDateKey,
            tgt.PropertyKey        = src.PropertyKey,
            tgt.GuestKey           = src.GuestKey,
            tgt.ChannelKey         = src.ChannelKey,
            tgt.ExperienceKey      = src.ExperienceKey,
            tgt.NightsBooked       = src.nights_stayed,
            tgt.RoomsBooked        = src.rooms_booked,
            tgt.CancellationAmount = src.cancellation_amount,
            tgt.IsCancelled        = src.is_cancelled,
            tgt.IsLoyaltyBooking   = src.is_loyalty_booking,
            tgt.SourceUpdatedAt    = src.updated_at_utc

        WHEN NOT MATCHED BY TARGET
        THEN INSERT
        (
            BookingID,
            BookingDateKey,
            CheckInDateKey,
            CheckOutDateKey,
            PropertyKey,
            GuestKey,
            ChannelKey,
            ExperienceKey,
            NightsBooked,
            RoomsBooked,
            CancellationAmount,
            IsCancelled,
            IsLoyaltyBooking,
            SourceUpdatedAt
        )
        VALUES
        (
            src.booking_id,
            src.BookingDateKey,
            src.CheckInDateKey,
            src.CheckOutDateKey,
            src.PropertyKey,
            src.GuestKey,
            src.ChannelKey,
            src.ExperienceKey,
            src.nights_stayed,
            src.rooms_booked,
            src.cancellation_amount,
            src.is_cancelled,
            src.is_loyalty_booking,
            src.updated_at_utc
        );

        SET @RowsAffected = @@ROWCOUNT;

        SELECT
            @TotalRows = COUNT_BIG(*)
        FROM dw.FactBooking;

        EXEC ctl.usp_log_load_step
            @LoadRunID    = @LoadRunID,
            @ObjectName   = 'dw.FactBooking',
            @ObjectType   = 'Fact',
            @RowsAffected = @RowsAffected,
            @TotalRows    = @TotalRows,
            @StepStartUTC = @StepStartUTC,
            @StepStatus   = 'Success',
            @ErrorMessage = NULL;

        SELECT
            @RowsAffected AS RowsAffected,
            @TotalRows AS TotalFactRows;

    END TRY
    BEGIN CATCH

        SET @ErrorMessage = ERROR_MESSAGE();

        EXEC ctl.usp_log_load_step
            @LoadRunID    = @LoadRunID,
            @ObjectName   = 'dw.FactBooking',
            @ObjectType   = 'Fact',
            @RowsAffected = NULL,
            @TotalRows    = NULL,
            @StepStartUTC = @StepStartUTC,
            @StepStatus   = 'Failed',
            @ErrorMessage = @ErrorMessage;

        THROW;

    END CATCH;
END;

GO

CREATE   PROCEDURE [dw].[usp_load_fact_stay_night]
    @LoadRunID VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    /* ============================================================
       Purpose
       Load realized stay-night activity from the Fabric Warehouse
       landing schema.

       Source:
           [lh_northstar].[landing].[StayNight]
           Populated incrementally from Azure SQL by Copy Job

       Target:
           dw.FactStayNight

       Grain:
           One row per stay-night record

       Responsibility:
           Transform landed stay activity into the analytical fact
           used for realized occupancy, revenue, customers served,
           and experience performance analysis.

       Behavior:
           - Insert new stay-night records
           - Update changed stay-night records
           - Resolve the Property surrogate key
           - Resolve the Guest surrogate key through FactBooking
           - Resolve the Experience surrogate key through FactBooking
           - Allow ExperienceKey to remain NULL when no experience
             was purchased
           - Exclude source rows marked as deleted
           - Log load execution details
       ============================================================ */

    DECLARE @StepStartUTC DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsAffected BIGINT;
    DECLARE @TotalRows BIGINT;
    DECLARE @ErrorMessage NVARCHAR(4000);

    BEGIN TRY

        MERGE dw.FactStayNight AS tgt
        USING
        (
            SELECT
                sn.stay_night_id,
                sn.booking_id,

                  YEAR(sn.stay_date) * 10000
                + MONTH(sn.stay_date) * 100
                + DAY(sn.stay_date) AS StayDateKey,

                p.PropertyKey,
                b.GuestKey,
                b.ExperienceKey,

                sn.night_number,
                sn.rooms_occupied,
                sn.room_revenue,
                sn.experience_revenue,
                sn.other_revenue,
                sn.discount_amount,
                sn.updated_at_utc

            FROM [lh_northstar].[landing].[StayNight] AS sn

            INNER JOIN dw.DimProperty AS p
                ON sn.property_code = p.PropertyCode

            INNER JOIN dw.FactBooking AS b
                ON sn.booking_id = b.BookingID

            WHERE sn.is_deleted = 0
        ) AS src
            ON tgt.StayNightID = src.stay_night_id

        WHEN MATCHED
             AND
             (
                 tgt.SourceUpdatedAt IS NULL
                 OR src.updated_at_utc > tgt.SourceUpdatedAt
             )
        THEN UPDATE SET
            tgt.BookingID          = src.booking_id,
            tgt.StayDateKey        = src.StayDateKey,
            tgt.PropertyKey        = src.PropertyKey,
            tgt.GuestKey           = src.GuestKey,
            tgt.ExperienceKey      = src.ExperienceKey,
            tgt.NightNumber        = src.night_number,
            tgt.RoomsOccupied      = src.rooms_occupied,
            tgt.RoomRevenue        = src.room_revenue,
            tgt.ExperienceRevenue  = src.experience_revenue,
            tgt.OtherRevenue       = src.other_revenue,
            tgt.DiscountAmount     = src.discount_amount,
            tgt.SourceUpdatedAt    = src.updated_at_utc

        WHEN NOT MATCHED BY TARGET
        THEN INSERT
        (
            StayNightID,
            BookingID,
            StayDateKey,
            PropertyKey,
            GuestKey,
            ExperienceKey,
            NightNumber,
            RoomsOccupied,
            RoomRevenue,
            ExperienceRevenue,
            OtherRevenue,
            DiscountAmount,
            SourceUpdatedAt
        )
        VALUES
        (
            src.stay_night_id,
            src.booking_id,
            src.StayDateKey,
            src.PropertyKey,
            src.GuestKey,
            src.ExperienceKey,
            src.night_number,
            src.rooms_occupied,
            src.room_revenue,
            src.experience_revenue,
            src.other_revenue,
            src.discount_amount,
            src.updated_at_utc
        );

        SET @RowsAffected = @@ROWCOUNT;

        SELECT
            @TotalRows = COUNT_BIG(*)
        FROM dw.FactStayNight;

        EXEC ctl.usp_log_load_step
            @LoadRunID    = @LoadRunID,
            @ObjectName   = 'dw.FactStayNight',
            @ObjectType   = 'Fact',
            @RowsAffected = @RowsAffected,
            @TotalRows    = @TotalRows,
            @StepStartUTC = @StepStartUTC,
            @StepStatus   = 'Success',
            @ErrorMessage = NULL;

        SELECT
            @RowsAffected AS RowsAffected,
            @TotalRows AS TotalFactRows;

    END TRY
    BEGIN CATCH

        SET @ErrorMessage = ERROR_MESSAGE();

        EXEC ctl.usp_log_load_step
            @LoadRunID    = @LoadRunID,
            @ObjectName   = 'dw.FactStayNight',
            @ObjectType   = 'Fact',
            @RowsAffected = NULL,
            @TotalRows    = NULL,
            @StepStartUTC = @StepStartUTC,
            @StepStatus   = 'Failed',
            @ErrorMessage = @ErrorMessage;

        THROW;

    END CATCH;
END;

GO

CREATE   PROCEDURE [dw].[usp_load_fact_guest_satisfaction]
    @LoadRunID VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    /* ============================================================
       Purpose
       Load guest satisfaction survey results from the Fabric
       Warehouse landing schema.

       Source:
           [lh_northstar].[landing].[SatisfactionSurvey]
           Populated incrementally from Azure SQL by Copy Job

       Target:
           dw.FactGuestSatisfaction

       Grain:
           One row per survey response

       Responsibility:
           Transform landed survey data into an analytics-ready
           guest satisfaction fact.

       Date Roles:
           StayDateKey   = date the guest stayed
           SurveyDateKey = date the survey was submitted

       Behavior:
           - Insert new survey responses
           - Update changed survey responses
           - Resolve Property, Guest, and Channel surrogate keys
           - Exclude source rows marked as deleted
       ============================================================ */

    DECLARE @StepStartUTC DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsAffected BIGINT;
    DECLARE @TotalRows BIGINT;
    DECLARE @ErrorMessage NVARCHAR(4000);

    BEGIN TRY

        MERGE dw.FactGuestSatisfaction AS tgt
        USING
        (
            SELECT
                s.survey_id,

                  YEAR(s.stay_date) * 10000
                + MONTH(s.stay_date) * 100
                + DAY(s.stay_date) AS StayDateKey,

                  YEAR(s.survey_date) * 10000
                + MONTH(s.survey_date) * 100
                + DAY(s.survey_date) AS SurveyDateKey,

                p.PropertyKey,
                g.GuestKey,
                c.ChannelKey,

                s.satisfaction_score,
                s.service_score,
                s.cleanliness_score,
                s.value_score,
                s.would_recommend,
                s.updated_at_utc

            FROM [lh_northstar].[landing].[SatisfactionSurvey] AS s

            INNER JOIN dw.DimProperty AS p
                ON s.property_code = p.PropertyCode

            INNER JOIN dw.DimGuest AS g
                ON s.guest_code = g.GuestCode

            INNER JOIN dw.DimChannel AS c
                ON s.channel_code = c.ChannelCode

            WHERE s.is_deleted = 0
        ) AS src
            ON tgt.SurveyID = src.survey_id

        WHEN MATCHED
             AND
             (
                 tgt.SourceUpdatedAt IS NULL
                 OR src.updated_at_utc > tgt.SourceUpdatedAt
             )
        THEN UPDATE SET
            tgt.StayDateKey       = src.StayDateKey,
            tgt.SurveyDateKey     = src.SurveyDateKey,
            tgt.PropertyKey       = src.PropertyKey,
            tgt.GuestKey          = src.GuestKey,
            tgt.ChannelKey        = src.ChannelKey,
            tgt.SatisfactionScore = src.satisfaction_score,
            tgt.ServiceScore      = src.service_score,
            tgt.CleanlinessScore  = src.cleanliness_score,
            tgt.ValueScore        = src.value_score,
            tgt.WouldRecommend    = src.would_recommend,
            tgt.SourceUpdatedAt   = src.updated_at_utc

        WHEN NOT MATCHED BY TARGET
        THEN INSERT
        (
            SurveyID,
            StayDateKey,
            SurveyDateKey,
            PropertyKey,
            GuestKey,
            ChannelKey,
            SatisfactionScore,
            ServiceScore,
            CleanlinessScore,
            ValueScore,
            WouldRecommend,
            SourceUpdatedAt
        )
        VALUES
        (
            src.survey_id,
            src.StayDateKey,
            src.SurveyDateKey,
            src.PropertyKey,
            src.GuestKey,
            src.ChannelKey,
            src.satisfaction_score,
            src.service_score,
            src.cleanliness_score,
            src.value_score,
            src.would_recommend,
            src.updated_at_utc
        );

        SET @RowsAffected = @@ROWCOUNT;

        SELECT
            @TotalRows = COUNT_BIG(*)
        FROM dw.FactGuestSatisfaction;

        EXEC ctl.usp_log_load_step
            @LoadRunID    = @LoadRunID,
            @ObjectName   = 'dw.FactGuestSatisfaction',
            @ObjectType   = 'Fact',
            @RowsAffected = @RowsAffected,
            @TotalRows    = @TotalRows,
            @StepStartUTC = @StepStartUTC,
            @StepStatus   = 'Success',
            @ErrorMessage = NULL;

        SELECT
            @RowsAffected AS RowsAffected,
            @TotalRows AS TotalFactRows;

    END TRY
    BEGIN CATCH

        SET @ErrorMessage = ERROR_MESSAGE();

        EXEC ctl.usp_log_load_step
            @LoadRunID    = @LoadRunID,
            @ObjectName   = 'dw.FactGuestSatisfaction',
            @ObjectType   = 'Fact',
            @RowsAffected = NULL,
            @TotalRows    = NULL,
            @StepStartUTC = @StepStartUTC,
            @StepStatus   = 'Failed',
            @ErrorMessage = @ErrorMessage;

        THROW;

    END CATCH;
END;

GO

CREATE   PROCEDURE [dw].[usp_load_fact_property_budget]
    @LoadRunID VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    /* ============================================================
       Purpose
       Load monthly property budget targets from the mirrored
       SharePoint List.

       Source:
           [PropertyBudget].[dbo].[Property Budget]
           Mirrored SharePoint List

       Target:
           dw.FactPropertyBudget

       Grain:
           One row per Property x Budget Month

       Responsibility:
           Provide monthly property targets for revenue and
           occupancy analysis.

       Behavior:
           - Insert new property/month budget records
           - Update budgets when the mirrored source changes
           - Resolve the Property surrogate key
       ============================================================ */

    DECLARE @StepStartUTC DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsAffected BIGINT;
    DECLARE @TotalRows BIGINT;
    DECLARE @ErrorMessage NVARCHAR(4000);

    BEGIN TRY

        MERGE dw.FactPropertyBudget AS tgt
        USING
        (
            SELECT
                p.PropertyKey,

                  YEAR(b.BudgetMonth) * 10000
                + MONTH(b.BudgetMonth) * 100
                + 1 AS BudgetMonthDateKey,

                b.BudgetRevenue,
                b.BudgetOccupancyPct,
                b.Modified AS SourceUpdatedAt

            FROM [PropertyBudget].[dbo].[Property Budget] AS b

            INNER JOIN dw.DimProperty AS p
                ON b.PropertyCode = p.PropertyCode
        ) AS src
            ON tgt.PropertyKey        = src.PropertyKey
           AND tgt.BudgetMonthDateKey = src.BudgetMonthDateKey

        WHEN MATCHED
             AND
             (
                 tgt.SourceUpdatedAt IS NULL
                 OR src.SourceUpdatedAt > tgt.SourceUpdatedAt
             )
        THEN UPDATE SET
            tgt.BudgetRevenue      = src.BudgetRevenue,
            tgt.BudgetOccupancyPct = src.BudgetOccupancyPct,
            tgt.SourceUpdatedAt    = src.SourceUpdatedAt

        WHEN NOT MATCHED BY TARGET
        THEN INSERT
        (
            PropertyKey,
            BudgetMonthDateKey,
            BudgetRevenue,
            BudgetOccupancyPct,
            SourceUpdatedAt
        )
        VALUES
        (
            src.PropertyKey,
            src.BudgetMonthDateKey,
            src.BudgetRevenue,
            src.BudgetOccupancyPct,
            src.SourceUpdatedAt
        );

        SET @RowsAffected = @@ROWCOUNT;

        SELECT
            @TotalRows = COUNT_BIG(*)
        FROM dw.FactPropertyBudget;

        EXEC ctl.usp_log_load_step
            @LoadRunID    = @LoadRunID,
            @ObjectName   = 'dw.FactPropertyBudget',
            @ObjectType   = 'Fact',
            @RowsAffected = @RowsAffected,
            @TotalRows    = @TotalRows,
            @StepStartUTC = @StepStartUTC,
            @StepStatus   = 'Success',
            @ErrorMessage = NULL;

        SELECT
            @RowsAffected AS RowsAffected,
            @TotalRows AS TotalFactRows;

    END TRY
    BEGIN CATCH

        SET @ErrorMessage = ERROR_MESSAGE();

        EXEC ctl.usp_log_load_step
            @LoadRunID    = @LoadRunID,
            @ObjectName   = 'dw.FactPropertyBudget',
            @ObjectType   = 'Fact',
            @RowsAffected = NULL,
            @TotalRows    = NULL,
            @StepStartUTC = @StepStartUTC,
            @StepStatus   = 'Failed',
            @ErrorMessage = @ErrorMessage;

        THROW;

    END CATCH;
END;

GO

CREATE   PROCEDURE [dw].[usp_load_fact_property_inventory]
    @LoadRunID VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    /* ============================================================
       Purpose
       Load daily property inventory from the Fabric Warehouse
       landing schema.

       Source:
           [lh_northstar].[landing].[PropertyDailyInventory]
           Populated incrementally from Azure SQL by Copy Job

       Target:
           dw.FactPropertyInventory

       Grain:
           One row per Property x Date

       Responsibility:
           Transform landed operational inventory data into an
           analytics-ready property inventory fact.

       Behavior:
           - Insert new daily inventory records
           - Update changed inventory records
           - Resolve the Property surrogate key
           - Exclude source rows marked as deleted
       ============================================================ */

    DECLARE @StepStartUTC DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @RowsAffected BIGINT;
    DECLARE @TotalRows BIGINT;
    DECLARE @ErrorMessage NVARCHAR(4000);

    BEGIN TRY

        MERGE dw.FactPropertyInventory AS tgt
        USING
        (
            SELECT
                i.property_inventory_id,

                  YEAR(i.inventory_date) * 10000
                + MONTH(i.inventory_date) * 100
                + DAY(i.inventory_date) AS DateKey,

                p.PropertyKey,

                i.room_capacity,
                i.rooms_out_of_service,
                i.rooms_sellable,
                i.updated_at_utc

            FROM [lh_northstar].[landing].[PropertyDailyInventory] AS i

            INNER JOIN dw.DimProperty AS p
                ON i.property_code = p.PropertyCode

            WHERE i.is_deleted = 0
        ) AS src
            ON tgt.PropertyInventoryID = src.property_inventory_id

        WHEN MATCHED
             AND
             (
                 tgt.SourceUpdatedAt IS NULL
                 OR src.updated_at_utc > tgt.SourceUpdatedAt
             )
        THEN UPDATE SET
            tgt.DateKey           = src.DateKey,
            tgt.PropertyKey       = src.PropertyKey,
            tgt.RoomCapacity      = src.room_capacity,
            tgt.RoomsOutOfService = src.rooms_out_of_service,
            tgt.RoomsSellable     = src.rooms_sellable,
            tgt.SourceUpdatedAt   = src.updated_at_utc

        WHEN NOT MATCHED BY TARGET
        THEN INSERT
        (
            PropertyInventoryID,
            DateKey,
            PropertyKey,
            RoomCapacity,
            RoomsOutOfService,
            RoomsSellable,
            SourceUpdatedAt
        )
        VALUES
        (
            src.property_inventory_id,
            src.DateKey,
            src.PropertyKey,
            src.room_capacity,
            src.rooms_out_of_service,
            src.rooms_sellable,
            src.updated_at_utc
        );

        SET @RowsAffected = @@ROWCOUNT;

        SELECT
            @TotalRows = COUNT_BIG(*)
        FROM dw.FactPropertyInventory;

        EXEC ctl.usp_log_load_step
            @LoadRunID    = @LoadRunID,
            @ObjectName   = 'dw.FactPropertyInventory',
            @ObjectType   = 'Fact',
            @RowsAffected = @RowsAffected,
            @TotalRows    = @TotalRows,
            @StepStartUTC = @StepStartUTC,
            @StepStatus   = 'Success',
            @ErrorMessage = NULL;

        SELECT
            @RowsAffected AS RowsAffected,
            @TotalRows AS TotalFactRows;

    END TRY
    BEGIN CATCH

        SET @ErrorMessage = ERROR_MESSAGE();

        EXEC ctl.usp_log_load_step
            @LoadRunID    = @LoadRunID,
            @ObjectName   = 'dw.FactPropertyInventory',
            @ObjectType   = 'Fact',
            @RowsAffected = NULL,
            @TotalRows    = NULL,
            @StepStartUTC = @StepStartUTC,
            @StepStatus   = 'Failed',
            @ErrorMessage = @ErrorMessage;

        THROW;

    END CATCH;
END;

GO

CREATE PROCEDURE [dw].[usp_load_fact_property_event]
    @LoadRunID varchar(36)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StepStartUTC datetime2(3) = SYSUTCDATETIME();
    DECLARE @RowsAffected bigint = 0;
    DECLARE @TotalRows bigint = 0;
    DECLARE @ErrorMessage varchar(4000);

    BEGIN TRY

        /* ============================================================
           Load Property Event Fact

           Grain:
               One row per property event

           Source:
               lh_northstar.processed.PropertyEvent

           Dimension resolution:
               property_code -> dw.DimProperty.PropertyKey
               event_date    -> dw.DimDate.DateKey
           ============================================================ */

        MERGE [dw].[FactPropertyEvent] AS tgt
        USING
        (
            SELECT
                src.event_id,
                p.PropertyKey,
                d.DateKey AS EventDateKey,
                CAST(src.event_timestamp AS datetime2(3)) AS EventTimestamp,
                src.event_type,
                CAST(src.room_number AS float) AS RoomNumber,
                src.severity,
                src.description,
                src.source_system

            FROM [lh_northstar].[processed].[PropertyEvent] AS src

            INNER JOIN [dw].[DimProperty] AS p
                ON src.property_code = p.PropertyCode

            INNER JOIN [dw].[DimDate] AS d
                ON src.event_date = d.FullDate
        ) AS src

        ON tgt.EventID = src.event_id

        WHEN MATCHED THEN
            UPDATE SET
                tgt.PropertyKey   = src.PropertyKey,
                tgt.EventDateKey  = src.EventDateKey,
                tgt.EventTimestamp = src.EventTimestamp,
                tgt.EventType     = src.event_type,
                tgt.RoomNumber    = src.RoomNumber,
                tgt.Severity      = src.severity,
                tgt.Description   = src.description,
                tgt.SourceSystem  = src.source_system

        WHEN NOT MATCHED BY TARGET THEN
            INSERT
            (
                EventID,
                PropertyKey,
                EventDateKey,
                EventTimestamp,
                EventType,
                RoomNumber,
                Severity,
                Description,
                SourceSystem
            )
            VALUES
            (
                src.event_id,
                src.PropertyKey,
                src.EventDateKey,
                src.EventTimestamp,
                src.event_type,
                src.RoomNumber,
                src.severity,
                src.description,
                src.source_system
            );

        SET @RowsAffected = @@ROWCOUNT;

        SELECT
            @TotalRows = COUNT_BIG(*)
        FROM [dw].[FactPropertyEvent];


        /* ============================================================
           Audit successful load
           ============================================================ */

        EXEC [ctl].[usp_log_load_step]
            @LoadRunID    = @LoadRunID,
            @ObjectName   = 'dw.FactPropertyEvent',
            @ObjectType   = 'Fact',
            @RowsAffected = @RowsAffected,
            @TotalRows    = @TotalRows,
            @StepStartUTC = @StepStartUTC,
            @StepStatus   = 'Success',
            @ErrorMessage = NULL;

    END TRY

    BEGIN CATCH

        SET @ErrorMessage = ERROR_MESSAGE();

        EXEC [ctl].[usp_log_load_step]
            @LoadRunID    = @LoadRunID,
            @ObjectName   = 'dw.FactPropertyEvent',
            @ObjectType   = 'Fact',
            @RowsAffected = 0,
            @TotalRows    = NULL,
            @StepStartUTC = @StepStartUTC,
            @StepStatus   = 'Failed',
            @ErrorMessage = @ErrorMessage;

        THROW;

    END CATCH;
END;

GO
