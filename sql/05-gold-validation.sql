
USE Airbnb_DWH;
GO

-- ============================================
-- GOLD LAYER VALIDATION
-- ============================================

-- 1. Check row counts
SELECT
    (SELECT COUNT(*) FROM SILVER.AirbnbCleaned)
        AS SilverRows,
    (SELECT COUNT(*) FROM GOLD.FactAirbnb)
        AS GoldRows;


-- 2. Check foreign key relationships
SELECT
    SUM(CASE WHEN c.CityID IS NULL
        THEN 1 ELSE 0 END) AS InvalidCityFK,

    SUM(CASE WHEN r.RoomTypeID IS NULL
        THEN 1 ELSE 0 END) AS InvalidRoomTypeFK,

    SUM(CASE WHEN d.DayTypeID IS NULL
        THEN 1 ELSE 0 END) AS InvalidDayTypeFK

FROM GOLD.FactAirbnb AS f

LEFT JOIN GOLD.DimCity AS c
    ON f.CityID = c.CityID

LEFT JOIN GOLD.DimRoomType AS r
    ON f.RoomTypeID = r.RoomTypeID

LEFT JOIN GOLD.DimDayType AS d
    ON f.DayTypeID = d.DayTypeID;


-- 3. Check duplicate Silver IDs
SELECT
    COUNT(*) AS DuplicateSilverIDs
FROM
(
    SELECT SilverID
    FROM GOLD.FactAirbnb
    GROUP BY SilverID
    HAVING COUNT(*) > 1
) AS duplicates;


-- 4. Price statistics
SELECT
    COUNT(*) AS TotalRecords,
    ROUND(MIN(Price), 2) AS MinimumPrice,
    ROUND(MAX(Price), 2) AS MaximumPrice,
    ROUND(AVG(Price), 2) AS AveragePrice,
    ROUND(STDEV(Price), 2) AS PriceStdDev
FROM GOLD.FactAirbnb;


-- 5. High-price records
SELECT TOP 20
    c.CityName,
    r.RoomTypeName,
    d.DayTypeName,
    ROUND(f.Price, 2) AS Price,
    f.PersonCapacity,
    f.Bedrooms,
    f.GuestSatisfaction

FROM GOLD.FactAirbnb AS f

JOIN GOLD.DimCity AS c
    ON f.CityID = c.CityID

JOIN GOLD.DimRoomType AS r
    ON f.RoomTypeID = r.RoomTypeID

JOIN GOLD.DimDayType AS d
    ON f.DayTypeID = d.DayTypeID

ORDER BY f.Price DESC;
GO





USE Airbnb_DWH;
GO

WITH PriceQuartiles AS
(
    SELECT
        Price,
        PERCENTILE_CONT(0.25)
            WITHIN GROUP (ORDER BY Price)
            OVER () AS Q1,

        PERCENTILE_CONT(0.75)
            WITHIN GROUP (ORDER BY Price)
            OVER () AS Q3

    FROM GOLD.FactAirbnb
),
PriceAnalysis AS
(
    SELECT
        Price,
        Q1,
        Q3,
        Q3 - Q1 AS IQR,
        Q1 - 1.5 * (Q3 - Q1) AS LowerFence,
        Q3 + 1.5 * (Q3 - Q1) AS UpperFence
    FROM PriceQuartiles
)
SELECT
    ROUND(MAX(Q1), 2) AS Q1,
    ROUND(MAX(Q3), 2) AS Q3,
    ROUND(MAX(IQR), 2) AS IQR,
    ROUND(MAX(LowerFence), 2) AS LowerFence,
    ROUND(MAX(UpperFence), 2) AS UpperFence,

    COUNT(*) AS TotalRecords,

    SUM(
        CASE
            WHEN Price < LowerFence
              OR Price > UpperFence
            THEN 1 ELSE 0
        END
    ) AS OutlierRecords,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN Price < LowerFence
                  OR Price > UpperFence
                THEN 1 ELSE 0
            END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS OutlierPercentage

FROM PriceAnalysis;
GO






USE Airbnb_DWH;
GO

WITH Quartiles AS
(
    SELECT
        f.FactID,
        f.CityID,
        f.RoomTypeID,
        f.Price,

        PERCENTILE_CONT(0.25)
            WITHIN GROUP (ORDER BY f.Price)
            OVER (
                PARTITION BY f.CityID, f.RoomTypeID
            ) AS Q1,

        PERCENTILE_CONT(0.75)
            WITHIN GROUP (ORDER BY f.Price)
            OVER (
                PARTITION BY f.CityID, f.RoomTypeID
            ) AS Q3

    FROM GOLD.FactAirbnb AS f
),
OutlierFlags AS
(
    SELECT
        *,
        CASE
            WHEN Price < Q1 - 1.5 * (Q3 - Q1)
              OR Price > Q3 + 1.5 * (Q3 - Q1)
            THEN 1
            ELSE 0
        END AS IsOutlier
    FROM Quartiles
)
SELECT
    c.CityName,
    r.RoomTypeName,

    COUNT(*) AS TotalRecords,

    SUM(o.IsOutlier) AS OutlierRecords,

    ROUND(
        100.0 * SUM(o.IsOutlier)
        / NULLIF(COUNT(*), 0),
        2
    ) AS OutlierPercentage

FROM OutlierFlags AS o

JOIN GOLD.DimCity AS c
    ON o.CityID = c.CityID

JOIN GOLD.DimRoomType AS r
    ON o.RoomTypeID = r.RoomTypeID

GROUP BY
    c.CityName,
    r.RoomTypeName

ORDER BY
    OutlierPercentage DESC;
GO
