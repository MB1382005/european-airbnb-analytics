
USE Airbnb_DWH;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

-- ============================================
-- GOLD LAYER - AIRBNB DATA WAREHOUSE
-- Dimensions + Fact Table + Relationships
-- ============================================


-- ============================================
-- 1. DIM CITY
-- ============================================

IF OBJECT_ID('GOLD.DimCity', 'U') IS NULL
BEGIN
    CREATE TABLE GOLD.DimCity
    (
        CityID INT IDENTITY(1,1) PRIMARY KEY,
        CityName NVARCHAR(50) NOT NULL UNIQUE
    );
END;
GO

INSERT INTO GOLD.DimCity (CityName)
SELECT DISTINCT s.City
FROM SILVER.AirbnbCleaned AS s
WHERE s.City IS NOT NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM GOLD.DimCity AS d
      WHERE d.CityName = s.City
  );
GO


-- ============================================
-- 2. DIM ROOM TYPE
-- ============================================

IF OBJECT_ID('GOLD.DimRoomType', 'U') IS NULL
BEGIN
    CREATE TABLE GOLD.DimRoomType
    (
        RoomTypeID INT IDENTITY(1,1) PRIMARY KEY,
        RoomTypeName NVARCHAR(100) NOT NULL UNIQUE
    );
END;
GO

INSERT INTO GOLD.DimRoomType (RoomTypeName)
SELECT DISTINCT s.room_type
FROM SILVER.AirbnbCleaned AS s
WHERE s.room_type IS NOT NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM GOLD.DimRoomType AS d
      WHERE d.RoomTypeName = s.room_type
  );
GO


-- ============================================
-- 3. DIM DAY TYPE
-- ============================================

IF OBJECT_ID('GOLD.DimDayType', 'U') IS NULL
BEGIN
    CREATE TABLE GOLD.DimDayType
    (
        DayTypeID INT IDENTITY(1,1) PRIMARY KEY,
        DayTypeName NVARCHAR(20) NOT NULL UNIQUE
    );
END;
GO

INSERT INTO GOLD.DimDayType (DayTypeName)
SELECT DISTINCT s.DayType
FROM SILVER.AirbnbCleaned AS s
WHERE s.DayType IS NOT NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM GOLD.DimDayType AS d
      WHERE d.DayTypeName = s.DayType
  );
GO


-- ============================================
-- 4. FACT AIRBNB
-- ============================================

IF OBJECT_ID('GOLD.FactAirbnb', 'U') IS NULL
BEGIN
    CREATE TABLE GOLD.FactAirbnb
    (
        FactID BIGINT IDENTITY(1,1) PRIMARY KEY,

        SilverID BIGINT NOT NULL UNIQUE,

        CityID INT NOT NULL,
        RoomTypeID INT NOT NULL,
        DayTypeID INT NOT NULL,

        SourceIndex INT,
        SourceFile NVARCHAR(100),

        Price FLOAT,
        RoomShared BIT,
        RoomPrivate BIT,
        PersonCapacity FLOAT,
        HostIsSuperhost BIT,
        Multi INT,
        Biz INT,
        CleanlinessRating FLOAT,
        GuestSatisfaction FLOAT,
        Bedrooms INT,
        DistanceToCenter FLOAT,
        DistanceToMetro FLOAT,
        AttractionIndex FLOAT,
        AttractionIndexNorm FLOAT,
        RestaurantIndex FLOAT,
        RestaurantIndexNorm FLOAT,
        Longitude FLOAT,
        Latitude FLOAT,

        CONSTRAINT FK_FactAirbnb_City
            FOREIGN KEY (CityID)
            REFERENCES GOLD.DimCity(CityID),

        CONSTRAINT FK_FactAirbnb_RoomType
            FOREIGN KEY (RoomTypeID)
            REFERENCES GOLD.DimRoomType(RoomTypeID),

        CONSTRAINT FK_FactAirbnb_DayType
            FOREIGN KEY (DayTypeID)
            REFERENCES GOLD.DimDayType(DayTypeID)
    );
END;
GO


-- ============================================
-- 5. LOAD FACT TABLE
-- ============================================

BEGIN TRY
    BEGIN TRANSACTION;

    -- Remove rows that no longer exist in Silver
    DELETE f
    FROM GOLD.FactAirbnb AS f
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM SILVER.AirbnbCleaned AS s
        WHERE s.SilverID = f.SilverID
    );

    -- Update existing rows from Silver
    UPDATE f
    SET
        f.CityID = c.CityID,
        f.RoomTypeID = r.RoomTypeID,
        f.DayTypeID = d.DayTypeID,
        f.SourceIndex = s.SourceIndex,
        f.SourceFile = s.SourceFile,
        f.Price = s.realSum,
        f.RoomShared = s.room_shared,
        f.RoomPrivate = s.room_private,
        f.PersonCapacity = s.person_capacity,
        f.HostIsSuperhost = s.host_is_superhost,
        f.Multi = s.multi,
        f.Biz = s.biz,
        f.CleanlinessRating = s.cleanliness_rating,
        f.GuestSatisfaction = s.guest_satisfaction_overall,
        f.Bedrooms = s.bedrooms,
        f.DistanceToCenter = s.dist,
        f.DistanceToMetro = s.metro_dist,
        f.AttractionIndex = s.attr_index,
        f.AttractionIndexNorm = s.attr_index_norm,
        f.RestaurantIndex = s.rest_index,
        f.RestaurantIndexNorm = s.rest_index_norm,
        f.Longitude = s.lng,
        f.Latitude = s.lat
    FROM GOLD.FactAirbnb AS f
    INNER JOIN SILVER.AirbnbCleaned AS s
        ON f.SilverID = s.SilverID
    INNER JOIN GOLD.DimCity AS c
        ON s.City = c.CityName
    INNER JOIN GOLD.DimRoomType AS r
        ON s.room_type = r.RoomTypeName
    INNER JOIN GOLD.DimDayType AS d
        ON s.DayType = d.DayTypeName;

    -- Insert rows that do not exist in Fact
    INSERT INTO GOLD.FactAirbnb
    (
        SilverID,
        CityID,
        RoomTypeID,
        DayTypeID,
        SourceIndex,
        SourceFile,
        Price,
        RoomShared,
        RoomPrivate,
        PersonCapacity,
        HostIsSuperhost,
        Multi,
        Biz,
        CleanlinessRating,
        GuestSatisfaction,
        Bedrooms,
        DistanceToCenter,
        DistanceToMetro,
        AttractionIndex,
        AttractionIndexNorm,
        RestaurantIndex,
        RestaurantIndexNorm,
        Longitude,
        Latitude
    )
    SELECT
        s.SilverID,
        c.CityID,
        r.RoomTypeID,
        d.DayTypeID,
        s.SourceIndex,
        s.SourceFile,
        s.realSum,
        s.room_shared,
        s.room_private,
        s.person_capacity,
        s.host_is_superhost,
        s.multi,
        s.biz,
        s.cleanliness_rating,
        s.guest_satisfaction_overall,
        s.bedrooms,
        s.dist,
        s.metro_dist,
        s.attr_index,
        s.attr_index_norm,
        s.rest_index,
        s.rest_index_norm,
        s.lng,
        s.lat
    FROM SILVER.AirbnbCleaned AS s
    INNER JOIN GOLD.DimCity AS c
        ON s.City = c.CityName
    INNER JOIN GOLD.DimRoomType AS r
        ON s.room_type = r.RoomTypeName
    INNER JOIN GOLD.DimDayType AS d
        ON s.DayType = d.DayTypeName
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM GOLD.FactAirbnb AS f
        WHERE f.SilverID = s.SilverID
    );

    -- Prevent silent loss of rows during joins
    IF (SELECT COUNT(*) FROM GOLD.FactAirbnb)
       <> (SELECT COUNT(*) FROM SILVER.AirbnbCleaned)
    BEGIN
        THROW 50001,
            'Fact row count does not match Silver.',
            1;
    END;

    COMMIT TRANSACTION;

    PRINT 'Gold Layer loaded successfully.';

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO


-- ============================================
-- 6. GOLD VALIDATION
-- ============================================

-- Overall row counts
SELECT
    (SELECT COUNT(*) FROM SILVER.AirbnbCleaned)
        AS SilverRows,

    (SELECT COUNT(*) FROM GOLD.FactAirbnb)
        AS GoldRows,

    (SELECT COUNT(*) FROM GOLD.DimCity)
        AS TotalCities,

    (SELECT COUNT(*) FROM GOLD.DimRoomType)
        AS TotalRoomTypes,

    (SELECT COUNT(*) FROM GOLD.DimDayType)
        AS TotalDayTypes;


-- City price analysis
SELECT
    c.CityName,
    COUNT(*) AS TotalRecords,
    ROUND(AVG(f.Price), 2) AS AveragePrice,
    ROUND(MIN(f.Price), 2) AS MinimumPrice,
    ROUND(MAX(f.Price), 2) AS MaximumPrice
FROM GOLD.FactAirbnb AS f
JOIN GOLD.DimCity AS c
    ON f.CityID = c.CityID
GROUP BY c.CityName
ORDER BY AveragePrice DESC;


-- Weekday vs Weekend analysis
SELECT
    d.DayTypeName,
    COUNT(*) AS TotalRecords,
    ROUND(AVG(f.Price), 2) AS AveragePrice
FROM GOLD.FactAirbnb AS f
JOIN GOLD.DimDayType AS d
    ON f.DayTypeID = d.DayTypeID
GROUP BY d.DayTypeName
ORDER BY d.DayTypeName;


-- Room type analysis
SELECT
    r.RoomTypeName,
    COUNT(*) AS TotalRecords,
    ROUND(AVG(f.Price), 2) AS AveragePrice
FROM GOLD.FactAirbnb AS f
JOIN GOLD.DimRoomType AS r
    ON f.RoomTypeID = r.RoomTypeID
GROUP BY r.RoomTypeName
ORDER BY AveragePrice DESC;


-- Preview joined Gold data
SELECT TOP 10
    f.FactID,
    c.CityName,
    r.RoomTypeName,
    d.DayTypeName,
    f.Price,
    f.PersonCapacity,
    f.GuestSatisfaction,
    f.DistanceToCenter
FROM GOLD.FactAirbnb AS f
JOIN GOLD.DimCity AS c
    ON f.CityID = c.CityID
JOIN GOLD.DimRoomType AS r
    ON f.RoomTypeID = r.RoomTypeID
JOIN GOLD.DimDayType AS d
    ON f.DayTypeID = d.DayTypeID
ORDER BY f.FactID;
GO





USE Airbnb_DWH;
GO

-- ============================================
-- ADD PRICE OUTLIER FLAG
-- ============================================

IF COL_LENGTH('GOLD.FactAirbnb', 'IsPriceOutlier') IS NULL
BEGIN
    ALTER TABLE GOLD.FactAirbnb
    ADD IsPriceOutlier BIT NULL;
END;
GO

-- Calculate IQR for each city and room type
WITH PriceQuartiles AS
(
    SELECT
        FactID,
        Price,

        PERCENTILE_CONT(0.25)
            WITHIN GROUP (ORDER BY Price)
            OVER (
                PARTITION BY CityID, RoomTypeID
            ) AS Q1,

        PERCENTILE_CONT(0.75)
            WITHIN GROUP (ORDER BY Price)
            OVER (
                PARTITION BY CityID, RoomTypeID
            ) AS Q3

    FROM GOLD.FactAirbnb
),
OutlierFlags AS
(
    SELECT
        FactID,

        CASE
            WHEN Price < Q1 - 1.5 * (Q3 - Q1)
              OR Price > Q3 + 1.5 * (Q3 - Q1)
            THEN 1
            ELSE 0
        END AS IsOutlier

    FROM PriceQuartiles
)

UPDATE f
SET f.IsPriceOutlier = o.IsOutlier
FROM GOLD.FactAirbnb AS f
JOIN OutlierFlags AS o
    ON f.FactID = o.FactID;
GO

-- ============================================
-- VALIDATION
-- ============================================

SELECT
    COUNT(*) AS TotalRecords,

    SUM(CASE WHEN IsPriceOutlier = 1
        THEN 1 ELSE 0 END) AS OutlierRecords,

    SUM(CASE WHEN IsPriceOutlier = 0
        THEN 1 ELSE 0 END) AS NormalRecords,

    SUM(CASE WHEN IsPriceOutlier IS NULL
        THEN 1 ELSE 0 END) AS UnclassifiedRecords

FROM GOLD.FactAirbnb;
GO
