
USE Airbnb_DWH;
GO

CREATE TABLE BRONZE.AirbnbImport (
    SourceIndex NVARCHAR(100),
    realSum NVARCHAR(100),
    room_type NVARCHAR(100),
    room_shared NVARCHAR(100),
    room_private NVARCHAR(100),
    person_capacity NVARCHAR(100),
    host_is_superhost NVARCHAR(100),
    multi NVARCHAR(100),
    biz NVARCHAR(100),
    cleanliness_rating NVARCHAR(100),
    guest_satisfaction_overall NVARCHAR(100),
    bedrooms NVARCHAR(100),
    dist NVARCHAR(100),
    metro_dist NVARCHAR(100),
    attr_index NVARCHAR(100),
    attr_index_norm NVARCHAR(100),
    rest_index NVARCHAR(100),
    rest_index_norm NVARCHAR(100),
    lng NVARCHAR(100),
    lat NVARCHAR(100)
);
GO

USE Airbnb_DWH;
GO

BULK INSERT BRONZE.AirbnbImport
FROM 'C:\AirbnbData\amsterdam_weekdays.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);
GO


SELECT COUNT(*) AS TotalRows
FROM BRONZE.AirbnbImport;




USE Airbnb_DWH;
GO

SELECT COUNT(*) AS TotalRows
FROM BRONZE.AirbnbImport;

SELECT TOP 10
    SourceIndex,
    realSum,
    room_type,
    room_shared,
    room_private,
    person_capacity,
    lat,
    lng
FROM BRONZE.AirbnbImport;




USE Airbnb_DWH;
GO

SET NOCOUNT ON;

DECLARE @Folder NVARCHAR(500) =
    N'C:\AirbnbData\';

DECLARE @Files TABLE (
    FileName SYSNAME
);

INSERT INTO @Files (FileName)
VALUES
('amsterdam_weekdays'),
('amsterdam_weekends'),
('athens_weekdays'),
('athens_weekends'),
('barcelona_weekdays'),
('barcelona_weekends'),
('berlin_weekdays'),
('berlin_weekends'),
('budapest_weekdays'),
('budapest_weekends'),
('lisbon_weekdays'),
('lisbon_weekends'),
('london_weekdays'),
('london_weekends'),
('paris_weekdays'),
('paris_weekends'),
('rome_weekdays'),
('rome_weekends'),
('vienna_weekdays'),
('vienna_weekends');

DECLARE @File SYSNAME;
DECLARE @SQL NVARCHAR(MAX);
DECLARE @Path NVARCHAR(1000);

DECLARE FileCursor CURSOR LOCAL FAST_FORWARD FOR
SELECT FileName FROM @Files;

OPEN FileCursor;
FETCH NEXT FROM FileCursor INTO @File;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @Path = @Folder + @File + N'.csv';

    -- Create a separate Bronze table
    SET @SQL = N'
    IF OBJECT_ID(N''BRONZE.' +
        REPLACE(@File,'''','''''') +
        N''', N''U'') IS NULL
    BEGIN
        CREATE TABLE BRONZE.' + QUOTENAME(@File) + N' (
            SourceIndex NVARCHAR(100) NULL,
            realSum NVARCHAR(100) NULL,
            room_type NVARCHAR(100) NULL,
            room_shared NVARCHAR(100) NULL,
            room_private NVARCHAR(100) NULL,
            person_capacity NVARCHAR(100) NULL,
            host_is_superhost NVARCHAR(100) NULL,
            multi NVARCHAR(100) NULL,
            biz NVARCHAR(100) NULL,
            cleanliness_rating NVARCHAR(100) NULL,
            guest_satisfaction_overall NVARCHAR(100) NULL,
            bedrooms NVARCHAR(100) NULL,
            dist NVARCHAR(100) NULL,
            metro_dist NVARCHAR(100) NULL,
            attr_index NVARCHAR(100) NULL,
            attr_index_norm NVARCHAR(100) NULL,
            rest_index NVARCHAR(100) NULL,
            rest_index_norm NVARCHAR(100) NULL,
            lng NVARCHAR(100) NULL,
            lat NVARCHAR(100) NULL
        );
    END;';

    EXEC sys.sp_executesql @SQL;

    -- Import only into an empty table
    SET @SQL = N'
    IF NOT EXISTS (
        SELECT 1 FROM BRONZE.' + QUOTENAME(@File) + N'
    )
    BEGIN
        BULK INSERT BRONZE.' + QUOTENAME(@File) + N'
        FROM ''' + REPLACE(@Path,'''','''''') + N'''
        WITH (
            FORMAT = ''CSV'',
            FIRSTROW = 2,
            FIELDQUOTE = ''"'',
            FIELDTERMINATOR = '','',
            ROWTERMINATOR = ''0x0a'',
            CODEPAGE = ''65001'',
            TABLOCK
        );
    END;';

    BEGIN TRY
        EXEC sys.sp_executesql @SQL;
        PRINT 'Processed: ' + @File;
    END TRY
    BEGIN CATCH
        PRINT 'FAILED: ' + @File;
        PRINT ERROR_MESSAGE();
    END CATCH;

    FETCH NEXT FROM FileCursor INTO @File;
END;

CLOSE FileCursor;
DEALLOCATE FileCursor;
GO




USE Airbnb_DWH;
GO

SELECT
    t.name AS TableName,
    SUM(p.rows) AS TotalRows
FROM sys.tables t
JOIN sys.schemas s
    ON t.schema_id = s.schema_id
JOIN sys.partitions p
    ON t.object_id = p.object_id
WHERE s.name = 'BRONZE'
  AND p.index_id IN (0, 1)
  AND (
      t.name LIKE '%[_]weekdays'
      OR t.name LIKE '%[_]weekends'
  )
GROUP BY t.name
ORDER BY t.name;
