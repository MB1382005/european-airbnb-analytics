# Original SQL filenames

| Supplied file | Repository file |
|---|---|
| SQLQuery3.sql | sql/00-setup.sql |
| SQLQuery4.sql | sql/01-bronze-import.sql |
| 2-Validation.sql | sql/02-bronze-validation.sql |
| 3-Silver_layer.sql | sql/03-silver-layer.sql |
| 4-Gold_layer.sql | sql/04-gold-layer.sql |
| 5-Gold_Validation.sql | sql/05-gold-validation.sql |
| 6-Normalization.sql | sql/06-relationship-validation.sql |
| 7-Export.sql | sql/07-reporting-view.sql |

SQL logic was retained. The original user-specific dataset path was replaced with C:\AirbnbData\ in the import script. The empty SSMS project shell was omitted because it does not reference the supplied queries.

Screenshots: Overview at 1s, City Analysis at 20s and Price Insights at approximately 42.6s in the supplied Air.mp4.
