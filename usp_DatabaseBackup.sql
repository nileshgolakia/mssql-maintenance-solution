ALTER PROCEDURE [dbo].[usp_DatabaseBackup]
    @DatabaseName   NVARCHAR(255),
    @BackupType     NVARCHAR(10) = 'FULL', 
    @BackupDirectory NVARCHAR(500),
    @Compress       BIT = 1,
    @Verify         BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Timestamp NVARCHAR(20) = FORMAT(GETDATE(), 'yyyyMMdd_HHmmss');
    DECLARE @FilePath  NVARCHAR(1000);
    DECLARE @Ext       NVARCHAR(5) = CASE @BackupType WHEN 'FULL' THEN 'bak' WHEN 'DIFF' THEN 'diff' WHEN 'LOG' THEN 'trn' ELSE 'bak' END;
    DECLARE @SQL       NVARCHAR(MAX);
    DECLARE @CommandLogID INT;
    DECLARE @StartTime DATETIME = GETDATE();

    -- Path Sanitization
    IF RIGHT(@BackupDirectory, 1) <> '\' SET @BackupDirectory = @BackupDirectory + '\';
    SET @FilePath = @BackupDirectory + @DatabaseName + '_' + @BackupType + '_' + @Timestamp + '.' + @Ext;

    -- Build Base Command
    IF @BackupType = 'LOG'
        SET @SQL = 'BACKUP LOG ' + QUOTENAME(@DatabaseName) + ' TO DISK = ' + QUOTENAME(@FilePath, '''');
    ELSE
        SET @SQL = 'BACKUP DATABASE ' + QUOTENAME(@DatabaseName) + ' TO DISK = ' + QUOTENAME(@FilePath, '''');

    -- Build WITH Options
    DECLARE @WithOptions NVARCHAR(MAX) = '';
    IF @BackupType = 'DIFF' SET @WithOptions = @WithOptions + ', DIFFERENTIAL';
    IF @Compress = 1       SET @WithOptions = @WithOptions + ', COMPRESSION';
    SET @WithOptions = @WithOptions + ', CHECKSUM, STATS = 10';
    SET @SQL = @SQL + ' WITH ' + STUFF(@WithOptions, 1, 2, '');

    -- Initial Log Entry (Status: RUNNING)
    INSERT INTO [dbo].[CommandLog] (DatabaseName, CommandType, Command, StartTime, Status)
    VALUES (@DatabaseName, @BackupType, @SQL, @StartTime, 'RUNNING');
    
    SET @CommandLogID = SCOPE_IDENTITY();

    BEGIN TRY
        -- Execute Backup
        EXEC sp_executesql @SQL;

        -- Optional Verification
        IF @Verify = 1
        BEGIN
            DECLARE @VerifySQL NVARCHAR(MAX) = 'RESTORE VERIFYONLY FROM DISK = ' + QUOTENAME(@FilePath, '''');
            EXEC sp_executesql @VerifySQL;
        END

        -- Update Log on Success
        UPDATE [dbo].[CommandLog] 
        SET EndTime = GETDATE(), Status = 'SUCCESS' 
        WHERE ID = @CommandLogID;

        PRINT 'SUCCESS: ' + @BackupType + ' backup completed.';
    END TRY
    BEGIN CATCH
        -- Update Log on Failure
        UPDATE [dbo].[CommandLog] 
        SET EndTime = GETDATE(), 
            Status = 'FAILURE', 
            ErrorMessage = ERROR_MESSAGE() 
        WHERE ID = @CommandLogID;

        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMsg, 16, 1);
    END CATCH
END
GO