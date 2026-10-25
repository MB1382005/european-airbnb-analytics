
USE Airbnb_DWH;
GO

CREATE TABLE SILVER.AirbnbCleaned
(
    SilverID BIGINT IDENTITY(1,1) PRIMARY KEY,

    SourceIndex INT,
    City NVARCHAR(50),
    DayType NVARCHAR(20),
    SourceFile NVARCHAR(100),

    realSum FLOAT,
    room_type NVARCHAR(100),
    room_shared BIT,
    room_private BIT,
    person_capacity FLOAT,
    host_is_superhost BIT,
    multi INT,
    biz INT,
    cleanliness_rating FLOAT,
    guest_satisfaction_overall FLOAT,
    bedrooms INT,
    dist FLOAT,
    metro_dist FLOAT,
    attr_index FLOAT,
    attr_index_norm FLOAT,
    rest_index FLOAT,
    rest_index_norm FLOAT,
    lng FLOAT,
    lat FLOAT
);
GO


SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'SILVER'
  AND TABLE_NAME = 'AirbnbCleaned'
ORDER BY ORDINAL_POSITION;





USE Airbnb_DWH;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

-- ============================================
-- SILVER LAYER - AIRBNB DATA WAREHOUSE
-- Merge 20 Bronze tables into one Silver table
-- ============================================

DECLARE @Table SYSNAME;
DECLARE @City NVARCHAR(50);
DECLARE @DayType NVARCHAR(20);
DECLARE @SourceFile NVARCHAR(100);
DECLARE @SQL NVARCHAR(MAX);

DECLARE TableCursor CURSOR LOCAL FAST_FORWARD FOR
SELECT t.name
FROM sys.tables t
JOIN sys.schemas s
    ON t.schema_id = s.schema_id
WHERE s.name = 'BRONZE'
  AND (
      t.name LIKE '%[_]weekdays'
      OR t.name LIKE '%[_]weekends'
  )
ORDER BY t.name;

BEGIN TRY

    BEGIN TRANSACTION;

    -- Clear old Silver data before reloading
    DELETE FROM SILVER.AirbnbCleaned;

    OPEN TableCursor;

    FETCH NEXT FROM TableCursor INTO @Table;

    WHILE @@FETCH_STATUS = 0
    BEGIN

        -- Extract city from table name
        SET @City =
            LEFT(@Table, CHARINDEX('_', @Table) - 1);

        -- Determine weekday or weekend
        SET @DayType =
            CASE
                WHEN @Table LIKE '%[_]weekdays'
                    THEN 'Weekday'
                ELSE 'Weekend'
            END;

        -- Original CSV filename
        SET @SourceFile = @Table + N'.csv';

        -- Insert cleaned and converted data
        SET @SQL = N'
        INSERT INTO SILVER.AirbnbCleaned
        (
            SourceIndex,
            City,
            DayType,
            SourceFile,
            realSum,
            room_type,
            room_shared,
            room_private,
            person_capacity,
            host_is_superhost,
            multi,
            biz,
            cleanliness_rating,
            guest_satisfaction_overall,
            bedrooms,
            dist,
            metro_dist,
            attr_index,
            attr_index_norm,
            rest_index,
            rest_index_norm,
            lng,
            lat
        )
        SELECT
            TRY_CONVERT(INT, SourceIndex),

            @City,
            @DayType,
            @File,

            TRY_CONVERT(FLOAT, realSum),

            room_type,

            CASE
                WHEN LOWER(LTRIM(RTRIM(room_shared)))
                    = ''true'' THEN 1
                WHEN LOWER(LTRIM(RTRIM(room_shared)))
                    = ''false'' THEN 0
                ELSE NULL
            END,

            CASE
                WHEN LOWER(LTRIM(RTRIM(room_private)))
                    = ''true'' THEN 1
                WHEN LOWER(LTRIM(RTRIM(room_private)))
                    = ''false'' THEN 0
                ELSE NULL
            END,

            TRY_CONVERT(FLOAT, person_capacity),

            CASE
                WHEN LOWER(LTRIM(RTRIM(host_is_superhost)))
                    = ''true'' THEN 1
                WHEN LOWER(LTRIM(RTRIM(host_is_superhost)))
                    = ''false'' THEN 0
                ELSE NULL
            END,

            TRY_CONVERT(INT, multi),
            TRY_CONVERT(INT, biz),

            TRY_CONVERT(FLOAT, cleanliness_rating),

            TRY_CONVERT(
                FLOAT,
                guest_satisfaction_overall
            ),

            TRY_CONVERT(INT, bedrooms),

            TRY_CONVERT(FLOAT, dist),
            TRY_CONVERT(FLOAT, metro_dist),
            TRY_CONVERT(FLOAT, attr_index),
            TRY_CONVERT(FLOAT, attr_index_norm),
            TRY_CONVERT(FLOAT, rest_index),
            TRY_CONVERT(FLOAT, rest_index_norm),
            TRY_CONVERT(FLOAT, lng),
            TRY_CONVERT(FLOAT, lat)

        FROM BRONZE.' + QUOTENAME(@Table) + N';
        ';

        EXEC sys.sp_executesql
            @SQL,
            N'@City NVARCHAR(50),
              @DayType NVARCHAR(20),
              @File NVARCHAR(100)',
            @City = @City,
            @DayType = @DayType,
            @File = @SourceFile;

        PRINT 'Loaded: ' + @Table;

        FETCH NEXT FROM TableCursor INTO @Table;

    END;

    CLOSE TableCursor;
    DEALLOCATE TableCursor;

    COMMIT TRANSACTION;

    PRINT 'Silver loading completed successfully.';

END TRY

BEGIN CATCH

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    IF CURSOR_STATUS('local', 'TableCursor') >= 0
        CLOSE TableCursor;

    IF CURSOR_STATUS('local', 'TableCursor') >= -1
        DEALLOCATE TableCursor;

    THROW;

END CATCH;
GO

-- ============================================
-- VALIDATION: SILVER LAYER
-- ============================================

-- 1. Overall summary
SELECT
    COUNT(*) AS TotalRows,
    COUNT(DISTINCT City) AS TotalCities,
    COUNT(DISTINCT SourceFile) AS TotalFiles
FROM SILVER.AirbnbCleaned;

-- 2. Rows per city and day type
SELECT
    City,
    DayType,
    COUNT(*) AS TotalRows
FROM SILVER.AirbnbCleaned
GROUP BY City, DayType
ORDER BY City, DayType;

-- 3. Check conversion failures
SELECT
    SUM(CASE WHEN SourceIndex IS NULL
        THEN 1 ELSE 0 END) AS NullSourceIndex,

    SUM(CASE WHEN realSum IS NULL
        THEN 1 ELSE 0 END) AS NullPrice,

    SUM(CASE WHEN person_capacity IS NULL
        THEN 1 ELSE 0 END) AS NullCapacity,

    SUM(CASE WHEN lat IS NULL OR lng IS NULL
        THEN 1 ELSE 0 END) AS NullCoordinates

FROM SILVER.AirbnbCleaned;

-- 4. Preview cleaned records
SELECT TOP 10 *
FROM SILVER.AirbnbCleaned
ORDER BY SilverID;
GO


USE Airbnb_DWH;
GO

SELECT
    COUNT(*) AS TotalRows,

    SUM(CASE WHEN room_type IS NULL THEN 1 ELSE 0 END)
        AS NullRoomType,

    SUM(CASE WHEN room_shared IS NULL THEN 1 ELSE 0 END)
        AS NullRoomShared,

    SUM(CASE WHEN room_private IS NULL THEN 1 ELSE 0 END)
        AS NullRoomPrivate,

    SUM(CASE WHEN host_is_superhost IS NULL THEN 1 ELSE 0 END)
        AS NullSuperhost,

    SUM(CASE WHEN multi IS NULL THEN 1 ELSE 0 END)
        AS NullMulti,

    SUM(CASE WHEN biz IS NULL THEN 1 ELSE 0 END)
        AS NullBiz,

    SUM(CASE WHEN cleanliness_rating IS NULL THEN 1 ELSE 0 END)
        AS NullCleanliness,

    SUM(CASE WHEN guest_satisfaction_overall IS NULL THEN 1 ELSE 0 END)
        AS NullGuestSatisfaction,

    SUM(CASE WHEN bedrooms IS NULL THEN 1 ELSE 0 END)
        AS NullBedrooms,

    SUM(CASE WHEN dist IS NULL THEN 1 ELSE 0 END)
        AS NullDistance,

    SUM(CASE WHEN metro_dist IS NULL THEN 1 ELSE 0 END)
        AS NullMetroDistance,

    SUM(CASE WHEN attr_index IS NULL THEN 1 ELSE 0 END)
        AS NullAttractionIndex,

    SUM(CASE WHEN attr_index_norm IS NULL THEN 1 ELSE 0 END)
        AS NullAttractionIndexNorm,

    SUM(CASE WHEN rest_index IS NULL THEN 1 ELSE 0 END)
        AS NullRestaurantIndex,

    SUM(CASE WHEN rest_index_norm IS NULL THEN 1 ELSE 0 END)
        AS NullRestaurantIndexNorm

FROM SILVER.AirbnbCleaned;





USE Airbnb_DWH;
GO

WITH DuplicateGroups AS
(
    SELECT
        City,
        DayType,
        realSum,
        room_type,
        room_shared,
        room_private,
        person_capacity,
        host_is_superhost,
        multi,
        biz,
        cleanliness_rating,
        guest_satisfaction_overall,
        bedrooms,
        dist,
        metro_dist,
        attr_index,
        attr_index_norm,
        rest_index,
        rest_index_norm,
        lng,
        lat,
        COUNT(*) AS DuplicateCount

    FROM SILVER.AirbnbCleaned

    GROUP BY
        City,
        DayType,
        realSum,
        room_type,
        room_shared,
        room_private,
        person_capacity,
        host_is_superhost,
        multi,
        biz,
        cleanliness_rating,
        guest_satisfaction_overall,
        bedrooms,
        dist,
        metro_dist,
        attr_index,
        attr_index_norm,
        rest_index,
        rest_index_norm,
        lng,
        lat

    HAVING COUNT(*) > 1
)

SELECT
    COUNT(*) AS DuplicateGroups,
    COALESCE(
        SUM(DuplicateCount - 1), 0
    ) AS ExtraDuplicateRows
FROM DuplicateGroups;
