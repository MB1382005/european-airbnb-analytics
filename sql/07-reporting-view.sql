
USE Airbnb_DWH;
GO

CREATE OR ALTER VIEW GOLD.vw_AirbnbMaster
AS
SELECT
    f.FactID,
    f.SilverID,
    f.SourceIndex,
    f.SourceFile,

    c.CityName AS City,
    d.DayTypeName AS DayType,
    r.RoomTypeName AS RoomType,

    f.Price,
    f.RoomShared,
    f.RoomPrivate,
    f.PersonCapacity,
    f.HostIsSuperhost,
    f.Multi,
    f.Biz,
    f.CleanlinessRating,
    f.GuestSatisfaction,
    f.Bedrooms,
    f.DistanceToCenter,
    f.DistanceToMetro,
    f.AttractionIndex,
    f.AttractionIndexNorm,
    f.RestaurantIndex,
    f.RestaurantIndexNorm,
    f.Longitude,
    f.Latitude,
    f.IsPriceOutlier

FROM GOLD.FactAirbnb AS f
JOIN GOLD.DimCity AS c
    ON f.CityID = c.CityID
JOIN GOLD.DimRoomType AS r
    ON f.RoomTypeID = r.RoomTypeID
JOIN GOLD.DimDayType AS d
    ON f.DayTypeID = d.DayTypeID;
GO

SELECT COUNT(*) AS TotalRows
FROM GOLD.vw_AirbnbMaster;
GO
