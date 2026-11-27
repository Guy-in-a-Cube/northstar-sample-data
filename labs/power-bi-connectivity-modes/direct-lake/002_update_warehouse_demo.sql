DECLARE @ConfirmedLabWarehouse VARCHAR(128) = '';
DECLARE @ChangedRows INT = 0;

IF @ConfirmedLabWarehouse = '' OR @ConfirmedLabWarehouse <> DB_NAME()
    THROW 51010, 'Confirm that you own the current lab Warehouse, then enter its name. Never use a shared source.', 1;

SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID('dbo.NorthstarConnectivityRestore', 'U') IS NULL
        THROW 51011, 'Run the preparation script first. No restore checkpoint exists.', 1;

    IF (SELECT COUNT_BIG(*) FROM dbo.NorthstarConnectivityRestore) <> 5
        OR (SELECT COUNT_BIG(DISTINCT StayNightID) FROM dbo.NorthstarConnectivityRestore) <> 5
        OR EXISTS (SELECT 1 FROM dbo.NorthstarConnectivityRestore
            WHERE OwnerTag <> 'northstar-connectivity-directlake-v1'
                OR WarehouseName <> DB_NAME()
                OR DemoRoomRevenue <> OriginalRoomRevenue + 10.00
                OR StayDateKey NOT BETWEEN 20260301 AND 20260331)
        THROW 51012, 'Invalid restore checkpoint. Inspect it; do not overwrite it.', 1;

    IF EXISTS (
        SELECT saved.StayNightID
        FROM dbo.NorthstarConnectivityRestore AS saved
        LEFT JOIN dw.FactStayNight AS fact ON fact.StayNightID = saved.StayNightID
        GROUP BY saved.StayNightID
        HAVING COUNT_BIG(fact.StayNightID) <> 1
    )
        OR (SELECT COUNT_BIG(*) FROM dw.FactStayNight AS fact
            INNER JOIN dbo.NorthstarConnectivityRestore AS saved ON saved.StayNightID = fact.StayNightID
            WHERE fact.PropertyKey = saved.PropertyKey AND fact.StayDateKey = saved.StayDateKey
                AND fact.NightNumber = saved.NightNumber AND fact.RoomsOccupied = saved.RoomsOccupied) <> 5
        THROW 51013, 'Selected source rows changed, disappeared or have duplicate keys. No update was made.', 1;

    IF (SELECT COUNT_BIG(*) FROM dw.FactStayNight AS fact
        INNER JOIN dbo.NorthstarConnectivityRestore AS saved ON saved.StayNightID = fact.StayNightID
        WHERE fact.RoomRevenue = saved.DemoRoomRevenue) = 5
        PRINT 'Demo values are already applied. No additional increase was made.';
    ELSE
    BEGIN
        IF (SELECT COUNT_BIG(*) FROM dw.FactStayNight AS fact
            INNER JOIN dbo.NorthstarConnectivityRestore AS saved ON saved.StayNightID = fact.StayNightID
            WHERE fact.RoomRevenue = saved.OriginalRoomRevenue) <> 5
            THROW 51014, 'Mixed or unexpected revenue values. Stop and inspect the selected rows; no update was made.', 1;

        UPDATE fact
        SET RoomRevenue = saved.DemoRoomRevenue
        FROM dw.FactStayNight AS fact
        INNER JOIN dbo.NorthstarConnectivityRestore AS saved ON saved.StayNightID = fact.StayNightID
        WHERE fact.RoomRevenue = saved.OriginalRoomRevenue
            AND fact.PropertyKey = saved.PropertyKey AND fact.StayDateKey = saved.StayDateKey
            AND fact.NightNumber = saved.NightNumber AND fact.RoomsOccupied = saved.RoomsOccupied;

        SET @ChangedRows = @@ROWCOUNT;
        IF @ChangedRows <> 5
            THROW 51015, 'Expected exactly five updated rows. Transaction rolled back.', 1;
    END;

    IF (SELECT COUNT_BIG(*) FROM dw.FactStayNight AS fact
        INNER JOIN dbo.NorthstarConnectivityRestore AS saved ON saved.StayNightID = fact.StayNightID
        WHERE fact.RoomRevenue = saved.DemoRoomRevenue
            AND fact.PropertyKey = saved.PropertyKey AND fact.StayDateKey = saved.StayDateKey
            AND fact.NightNumber = saved.NightNumber AND fact.RoomsOccupied = saved.RoomsOccupied) <> 5
        THROW 51016, 'Post-update verification failed. Transaction rolled back.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT @ChangedRows AS ChangedRows,
    SUM(fact.RoomRevenue - saved.OriginalRoomRevenue) AS RevenueAboveSavedBaseline
FROM dw.FactStayNight AS fact
INNER JOIN dbo.NorthstarConnectivityRestore AS saved ON saved.StayNightID = fact.StayNightID;