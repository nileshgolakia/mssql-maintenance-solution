
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:      [Nilesh Golakia/ngolakia]
-- Create date: 2026-03-31
-- Description: Performance-focused backup orchestration for Full, Diff, and Log.
-- Features:    Auto-compression, dynamic pathing, and integrated error logging.
-- =============================================

CREATE PROCEDURE [dbo].[usp_DatabaseBackup]
    @DatabaseName NVARCHAR(255),
    @BackupType NVARCHAR(10) = 'FULL', -- FULL, DIFF, or LOG
    @BackupDirectory NVARCHAR(500),
    @Compress BIT = 1,
    @Verify BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Timestamp NVARCHAR(20) = REPLACE(REPLACE(REPLACE(CONVERT(NVARCHAR(20), GETDATE(), 120), '-', ''), ' ', '_'), ':', '');
    DECLARE @FilePath NVARCHAR(1000);
    DECLARE @FileExtension NVARCHAR(5);
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @StartTime DATETIME = GETDATE();

    
    SET @FileExtension = CASE 
        WHEN @BackupType = 'FULL' THEN 'bak'
        WHEN @BackupType = 'DIFF' THEN 'diff'
        WHEN @BackupType = 'LOG'  THEN 'trn'
        ELSE 'bak'
    END;

    
    -- Format: Directory\DatabaseName_Type_YYYYMMDD_HHMMSS.ext
    SET @FilePath = @BackupDirectory + '\' + @DatabaseName + '_' + @BackupType + '_' + @Timestamp + '.' + @FileExtension;

    BEGIN TRY
        
        SET @SQL = CASE 
            WHEN @BackupType = 'LOG' 
                THEN 'BACKUP LOG [' + @DatabaseName + '] TO DISK = ''' + @FilePath + ''''
            ELSE 'BACKUP DATABASE [' + @DatabaseName + '] TO DISK = ''' + @FilePath + ''''
        END;

        
        IF @BackupType = 'DIFF' SET @SQL = @SQL + ' WITH DIFFERENTIAL';

        -- Add Compression & Verification
        IF @Compress = 1 AND @BackupType <> 'LOG' 
            SET @SQL = @SQL + CASE WHEN @BackupType = 'DIFF' THEN ', COMPRESSION' ELSE ' WITH COMPRESSION' END;
        
        IF @Verify = 1 
            SET @SQL = @SQL + '; RESTORE VERIFYONLY FROM DISK = ''' + @FilePath + ''';';

        
        -- In a real setup, we pass this to our internal engine for logging
        EXEC sp_executesql @SQL;

        
        PRINT 'Backup Successful: ' + @FilePath;
        
    END TRY
    BEGIN CATCH
        -- Error Handling
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'Backup Failed for ' + @DatabaseName + '. Error: ' + @ErrorMessage;
        
        -- You would typically call usp_LogMaintenance here
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END
GO
