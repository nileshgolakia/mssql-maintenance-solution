SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_OptimizeIndexes]
    @DatabaseName NVARCHAR(255),
    @FragmentationThresholdLow  FLOAT = 10.0, -- REORGANIZE above 10%
    @FragmentationThresholdHigh FLOAT = 30.0  -- REBUILD above 30%
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SchemaName   NVARCHAR(128);
    DECLARE @ObjectName   NVARCHAR(128);
    DECLARE @IndexName    NVARCHAR(128);
    DECLARE @FragPercent  FLOAT;
    DECLARE @SQL          NVARCHAR(MAX);
    DECLARE @CommandLogID INT;

    -- Cursor to find fragmented indexes
    DECLARE IndexCursor CURSOR FOR
    SELECT 
        s.name AS SchemaName,
        t.name AS ObjectName,
        i.name AS IndexName,
        ips.avg_fragmentation_in_percent
    FROM sys.dm_db_index_physical_stats(DB_ID(@DatabaseName), NULL, NULL, NULL, 'LIMITED') AS ips
    INNER JOIN sys.indexes AS i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
    INNER JOIN sys.tables AS t ON i.object_id = t.object_id
    INNER JOIN sys.schemas AS s ON t.schema_id = s.schema_id
    WHERE ips.avg_fragmentation_in_percent > @FragmentationThresholdLow
      AND i.name IS NOT NULL
      AND ips.page_count > 128; -- Ignore small tables (under 1MB)

    OPEN IndexCursor;
    FETCH NEXT FROM IndexCursor INTO @SchemaName, @ObjectName, @IndexName, @FragPercent;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Determine Strategy: Rebuild vs Reorganize
        IF @FragPercent >= @FragmentationThresholdHigh
            SET @SQL = 'ALTER INDEX ' + QUOTENAME(@IndexName) + ' ON ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@ObjectName) + ' REBUILD WITH (ONLINE = ON, STATISTICS_NORECOMPUTE = OFF)';
        ELSE
            SET @SQL = 'ALTER INDEX ' + QUOTENAME(@IndexName) + ' ON ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@ObjectName) + ' REORGANIZE';

        
        INSERT INTO [dbo].[CommandLog] (DatabaseName, CommandType, Command, Status)
        VALUES (@DatabaseName, 'INDEX_OPTIMIZE', @SQL, 'RUNNING');
        SET @CommandLogID = SCOPE_IDENTITY();

        BEGIN TRY
            
            EXEC sp_executesql @SQL;

            
            UPDATE [dbo].[CommandLog] 
            SET EndTime = GETDATE(), Status = 'SUCCESS' 
            WHERE ID = @CommandLogID;
        END TRY
        BEGIN CATCH
            
            UPDATE [dbo].[CommandLog] 
            SET EndTime = GETDATE(), Status = 'FAILURE', ErrorMessage = ERROR_MESSAGE() 
            WHERE ID = @CommandLogID;
        END CATCH

        FETCH NEXT FROM IndexCursor INTO @SchemaName, @ObjectName, @IndexName, @FragPercent;
    END

    CLOSE IndexCursor;
    DEALLOCATE IndexCursor;
    
    PRINT 'Index Optimization for ' + @DatabaseName + ' completed. Check CommandLog for details.';
END
GO