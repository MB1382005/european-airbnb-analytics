
USE Airbnb_DWH;
GO

SET NOCOUNT ON;

-- Collect missing-value results
IF OBJECT_ID('tempdb..#MissingReport') IS NOT NULL
    DROP TABLE #MissingReport;

CREATE TABLE #MissingReport (
    TableName SYSNAME,
    ColumnName SYSNAME,
    TotalRows BIGINT,
    MissingCount BIGINT
);

DECLARE @Table SYSNAME;
DECLARE @Column SYSNAME;
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

OPEN TableCursor;
FETCH NEXT FROM TableCursor INTO @Table;

WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE ColumnCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT c.name
    FROM sys.columns c
    WHERE c.object_id =
        OBJECT_ID(N'BRONZE.' + QUOTENAME(@Table));

    OPEN ColumnCursor;
    FETCH NEXT FROM ColumnCursor INTO @Column;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @SQL = N'
        INSERT INTO #MissingReport
        SELECT
            @T,
            @C,
            COUNT_BIG(*),
            COALESCE(SUM(CASE
                WHEN ' + QUOTENAME(@Column) + N' IS NULL
                  OR LTRIM(RTRIM(' +
                     QUOTENAME(@Column) + N')) = ''''
                THEN CONVERT(BIGINT,1)
                ELSE CONVERT(BIGINT,0)
            END), 0)
        FROM BRONZE.' + QUOTENAME(@Table) + N';';

        EXEC sys.sp_executesql
            @SQL,
            N'@T SYSNAME, @C SYSNAME',
            @T = @Table,
            @C = @Column;

        FETCH NEXT FROM ColumnCursor INTO @Column;
    END;

    CLOSE ColumnCursor;
    DEALLOCATE ColumnCursor;

    FETCH NEXT FROM TableCursor INTO @Table;
END;

CLOSE TableCursor;
DEALLOCATE TableCursor;

SELECT
    TableName,
    ColumnName,
    TotalRows,
    MissingCount,
    CAST(
        100.0 * MissingCount /
        NULLIF(TotalRows, 0)
        AS DECIMAL(6,2)
    ) AS MissingPercent
FROM #MissingReport
ORDER BY TableName, ColumnName;
GO



USE Airbnb_DWH;
GO

IF OBJECT_ID('tempdb..#InvalidReport') IS NOT NULL
    DROP TABLE #InvalidReport;

CREATE TABLE #InvalidReport (
    TableName SYSNAME,
    TotalRows BIGINT,
    InvalidPrice BIGINT,
    InvalidCapacity BIGINT,
    InvalidRating BIGINT,
    InvalidDistance BIGINT,
    InvalidCoordinates BIGINT,
    InvalidBoolean BIGINT
);

DECLARE @Table SYSNAME;
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
  );

OPEN TableCursor;
FETCH NEXT FROM TableCursor INTO @Table;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = N'
    INSERT INTO #InvalidReport
    SELECT
        @T,
        COUNT_BIG(*),

        -- Price must be positive
        SUM(CASE WHEN
            TRY_CONVERT(FLOAT, realSum) IS NULL
            OR TRY_CONVERT(FLOAT, realSum) <= 0
            THEN 1 ELSE 0 END),

        -- Capacity must be positive
        SUM(CASE WHEN
            TRY_CONVERT(FLOAT, person_capacity) IS NULL
            OR TRY_CONVERT(FLOAT, person_capacity) <= 0
            THEN 1 ELSE 0 END),

        -- Satisfaction score: 0 to 100
        SUM(CASE WHEN
            TRY_CONVERT(FLOAT,
                guest_satisfaction_overall) IS NULL
            OR TRY_CONVERT(FLOAT,
                guest_satisfaction_overall)
                NOT BETWEEN 0 AND 100
            THEN 1 ELSE 0 END),

        -- Distances cannot be negative
        SUM(CASE WHEN
            TRY_CONVERT(FLOAT, dist) IS NULL
            OR TRY_CONVERT(FLOAT, dist) < 0
            OR TRY_CONVERT(FLOAT, metro_dist) IS NULL
            OR TRY_CONVERT(FLOAT, metro_dist) < 0
            THEN 1 ELSE 0 END),

        -- Latitude and longitude ranges
        SUM(CASE WHEN
            TRY_CONVERT(FLOAT, lat) IS NULL
            OR TRY_CONVERT(FLOAT, lat)
                NOT BETWEEN -90 AND 90
            OR TRY_CONVERT(FLOAT, lng) IS NULL
            OR TRY_CONVERT(FLOAT, lng)
                NOT BETWEEN -180 AND 180
            THEN 1 ELSE 0 END),

        -- Boolean fields
        SUM(CASE WHEN
            LOWER(LTRIM(RTRIM(room_shared)))
                NOT IN (''true'', ''false'')
            OR LOWER(LTRIM(RTRIM(room_private)))
                NOT IN (''true'', ''false'')
            OR LOWER(LTRIM(RTRIM(host_is_superhost)))
                NOT IN (''true'', ''false'')
            THEN 1 ELSE 0 END)
    FROM BRONZE.' + QUOTENAME(@Table) + N';';

    EXEC sys.sp_executesql
        @SQL,
        N'@T SYSNAME',
        @T = @Table;

    FETCH NEXT FROM TableCursor INTO @Table;
END;

CLOSE TableCursor;
DEALLOCATE TableCursor;

SELECT *
FROM #InvalidReport
ORDER BY TableName;
GO



USE Airbnb_DWH;
GO

IF OBJECT_ID('tempdb..#DuplicateReport') IS NOT NULL
    DROP TABLE #DuplicateReport;

CREATE TABLE #DuplicateReport (
    TableName SYSNAME,
    DuplicateIndexGroups BIGINT,
    ExtraIndexRows BIGINT
);

DECLARE @Table SYSNAME;
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
  );

OPEN TableCursor;
FETCH NEXT FROM TableCursor INTO @Table;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = N'
    INSERT INTO #DuplicateReport
    SELECT
        @T,
        COUNT_BIG(*),
        COALESCE(SUM(
            CONVERT(BIGINT, Cnt) - 1
        ), 0)
    FROM (
        SELECT SourceIndex, COUNT(*) AS Cnt
        FROM BRONZE.' + QUOTENAME(@Table) + N'
        GROUP BY SourceIndex
        HAVING COUNT(*) > 1
    ) D;';

    EXEC sys.sp_executesql
        @SQL,
        N'@T SYSNAME',
        @T = @Table;

    FETCH NEXT FROM TableCursor INTO @Table;
END;

CLOSE TableCursor;
DEALLOCATE TableCursor;

SELECT *
FROM #DuplicateReport
ORDER BY TableName;
GO
    