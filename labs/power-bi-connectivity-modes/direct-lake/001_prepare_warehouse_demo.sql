DECLARE @ConfirmedLabWarehouse VARCHAR(128) = '';

IF @ConfirmedLabWarehouse = '' OR @ConfirmedLabWarehouse <> DB_NAME()
    THROW 51000, 'Enter the current Warehouse name only after confirming you own this lab Warehouse. Never use a shared source.', 1;

SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID('dbo.NorthstarConnectivityRestore', 'U') IS NOT NULL
        THROW 51001, 'Restore checkpoint already exists. Keep it and use the update/reset scripts; do not overwrite it.', 1;

    IF (SELECT COUNT_BIG(*) FROM dw.DimProperty WHERE PropertyCode = 201) <> 1
        THROW 51002, 'Expected exactly one property with PropertyCode 201.', 1;

    CREATE TABLE dbo.NorthstarConnectivityRestore (
        OwnerTag VARCHAR(64) NOT NULL,
        WarehouseName VARCHAR(128) NOT NULL,
        StayNightID BIGINT NOT NULL,
        PropertyKey BIGINT NOT NULL,
        StayDateKey INT NOT NULL,
        NightNumber INT NOT NULL,
        RoomsOccupied INT NOT NULL,
        OriginalRoomRevenue DECIMAL(18, 2) NOT NULL,
        DemoRoomRevenue DECIMAL(18, 2) NOT NULL
    );

    INSERT INTO dbo.NorthstarConnectivityRestore (
        OwnerTag, WarehouseName, StayNightID, PropertyKey, StayDateKey,
        NightNumber, RoomsOccupied, OriginalRoomRevenue, DemoRoomRevenue
    )
    SELECT TOP (5)
        'northstar-connectivity-directlake-v1', DB_NAME(), fact.StayNightID,
        fact.PropertyKey, fact.StayDateKey, fact.NightNumber, fact.RoomsOccupied,
        fact.RoomRevenue, CAST(fact.RoomRevenue + 10.00 AS DECIMAL(18, 2))
    FROM dw.FactStayNight AS fact
    INNER JOIN dw.DimProperty AS property ON property.PropertyKey = fact.PropertyKey
    WHERE property.PropertyCode = 201
        AND fact.StayDateKey BETWEEN 20260301 AND 20260331
    ORDER BY fact.StayNightID;

    IF (SELECT COUNT_BIG(*) FROM dbo.NorthstarConnectivityRestore) <> 5
        OR (SELECT COUNT_BIG(DISTINCT StayNightID) FROM dbo.NorthstarConnectivityRestore) <> 5
        THROW 51003, 'Expected five distinct stay-night rows. Preparation rolled back.', 1;

    IF EXISTS (
        SELECT saved.StayNightID
        FROM dbo.NorthstarConnectivityRestore AS saved
        LEFT JOIN dw.FactStayNight AS fact ON fact.StayNightID = saved.StayNightID
        GROUP BY saved.StayNightID
        HAVING COUNT_BIG(fact.StayNightID) <> 1
    )
        THROW 51004, 'Each saved StayNightID must match exactly one source row. Preparation rolled back.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT StayNightID, OriginalRoomRevenue, DemoRoomRevenue,
    DemoRoomRevenue - OriginalRoomRevenue AS RevenueChange
FROM dbo.NorthstarConnectivityRestore
ORDER BY StayNightID;

SELECT COUNT_BIG(*) AS SavedRows,
    SUM(DemoRoomRevenue - OriginalRoomRevenue) AS ExpectedMarchRevenueIncrease
FROM dbo.NorthstarConnectivityRestore;