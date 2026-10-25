# SQL model

`SILVER.AirbnbCleaned` combines the city/day-type source tables and keeps their provenance.

`GOLD.FactAirbnb` has one row per linked Silver record, identified by a unique `SilverID`. It references `DimCity`, `DimRoomType` and `DimDayType` through foreign keys. It holds price, capacity, ratings, distances, location and the outlier flag.

`GOLD.vw_AirbnbMaster` joins these dimensions to the fact table for reporting.

The file originally named `6-Normalization.sql` checks relationships and row quality; it does not create another normalized layer. `7-Export.sql` creates a view rather than exporting a file.
