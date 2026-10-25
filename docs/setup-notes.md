# Setup and reload notes

- Use a new database. Setup and Silver table creation are not idempotent.
- The first part of the Bronze import script loads an Amsterdam staging table, `BRONZE.AirbnbImport`. The later loop loads the 20 city/day tables used by Silver. The staging table is not part of that merge.
- The Bronze loader skips tables that already contain rows. It does not detect changed source files, and its error handler prints failures and continues. Review the messages and per-table counts.
- Silver deletes and reloads its rows. Its identity values keep increasing. Rerun Gold after reloading Silver, and refresh Power BI only after the load and checks finish.
- Conversion uses TRY_CONVERT. Failed conversions become NULL; validation reports them. Validation queries do not automatically reject or remove every invalid row.
- Duplicate checks report duplicates; they do not remove them.
- Gold retains price outliers and adds a flag using city/room-type IQR. The global IQR query in Gold validation is a separate diagnostic.
- The City Analysis screenshot has a card labelled Count of HostIsSuperhost. A count of that column is not a count of true superhosts; review the measure before presenting it as one.
- The report was inspected through its layout metadata and demo video. Refresh, connection settings, embedded model contents and DAX results have not been verified in Power BI Desktop.
