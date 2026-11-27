SELECT TOP (1000001)
    [t1].[YearMonth] AS [c10],
    [t2].[PropertyName] AS [c14],
    SUM([t0].[RoomRevenue]) AS [a0],
    COUNT_BIG(*) AS [a1],
    SUM(CAST([t0].[RoomsOccupied] AS BIGINT)) AS [a2]
FROM
(
    (
        (
            SELECT [StayNightID], [StayDateKey], [PropertyKey],
                [NightNumber], [RoomsOccupied], [RoomRevenue]
            FROM [dw].[FactStayNight] AS [$Table]
        ) AS [t0]
        LEFT OUTER JOIN
        (
            SELECT [DateKey], [FullDate], [YearMonth]
            FROM [dw].[DimDate] AS [$Table]
        ) AS [t1]
            ON ([t0].[StayDateKey] = [t1].[DateKey])
    )
    LEFT OUTER JOIN
    (
        SELECT [PropertyKey], [PropertyCode], [PropertyName]
        FROM [dw].[DimProperty] AS [$Table]
    ) AS [t2]
        ON ([t0].[PropertyKey] = [t2].[PropertyKey])
)
WHERE
(
    ([t2].[PropertyCode] = 201)
    AND (([t1].[YearMonth] IN ('2026-03', '2026-04')))
)
GROUP BY [t1].[YearMonth], [t2].[PropertyName]