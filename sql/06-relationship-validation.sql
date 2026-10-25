
USE Airbnb_DWH;
GO

-- ============================================
-- GOLD LAYER - FOREIGN KEY VALIDATION
-- ============================================

SELECT
    fk.name AS ForeignKeyName,

    ps.name + '.' + pt.name AS ChildTable,
    pc.name AS ForeignKeyColumn,

    rs.name + '.' + rt.name AS ParentTable,
    rc.name AS PrimaryKeyColumn,

    fk.is_disabled AS IsDisabled,
    fk.is_not_trusted AS IsNotTrusted

FROM sys.foreign_keys AS fk

JOIN sys.foreign_key_columns AS fkc
    ON fk.object_id = fkc.constraint_object_id

JOIN sys.tables AS pt
    ON fk.parent_object_id = pt.object_id

JOIN sys.schemas AS ps
    ON pt.schema_id = ps.schema_id

JOIN sys.tables AS rt
    ON fk.referenced_object_id = rt.object_id

JOIN sys.schemas AS rs
    ON rt.schema_id = rs.schema_id

JOIN sys.columns AS pc
    ON pc.object_id = fkc.parent_object_id
   AND pc.column_id = fkc.parent_column_id

JOIN sys.columns AS rc
    ON rc.object_id = fkc.referenced_object_id
   AND rc.column_id = fkc.referenced_column_id

WHERE ps.name = 'GOLD'

ORDER BY fk.name;
GO



-- ============================================
-- ============================================

USE Airbnb_DWH;
GO

SELECT
    COUNT(*) AS TotalGoldRows,

    COUNT(DISTINCT SilverID) AS UniqueSilverIDs,

    COUNT(DISTINCT CityID) AS CitiesUsed,

    COUNT(DISTINCT RoomTypeID) AS RoomTypesUsed,

    COUNT(DISTINCT DayTypeID) AS DayTypesUsed,

    SUM(CASE WHEN Price IS NULL OR Price <= 0
        THEN 1 ELSE 0 END) AS InvalidPrices,

    SUM(CASE WHEN IsPriceOutlier IS NULL
        THEN 1 ELSE 0 END) AS MissingOutlierFlags

FROM GOLD.FactAirbnb;
GO
