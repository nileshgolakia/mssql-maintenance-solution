CREATE PROCEDURE dbo.usp_MaintenanceAlerting
    @Recipients NVARCHAR(MAX),
    @ProfileName SYSNAME = 'GeneralProfile'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @XmlBody XML;
    DECLARE @HtmlBody NVARCHAR(MAX);

    -- Check if any errors occurred in the last 24 hours
    IF EXISTS (SELECT 1 FROM dbo.CommandLog WHERE ErrorNumber <> 0 AND StartTime > DATEADD(DAY, -1, GETDATE()))
    BEGIN
        -- Generate HTML table for the errors
        SET @XmlBody = (
            SELECT 
                td = DatabaseName, '',
                td = CommandType, '',
                td = StartTime, '',
                td = ErrorNumber, '',
                td = ErrorMessage, ''
            FROM dbo.CommandLog
            WHERE ErrorNumber <> 0 
              AND StartTime > DATEADD(DAY, -1, GETDATE())
            FOR XML PATH('tr'), ELEMENTS
        );

        SET @HtmlBody = '<html><body><h3>Critical Maintenance Failures</h3>
            <table border="1">
            <tr><th>Database</th><th>Task</th><th>Start Time</th><th>Error #</th><th>Message</th></tr>' 
            + CAST(@XmlBody AS NVARCHAR(MAX)) + 
            '</table></body></html>';

        -- Send Email
        EXEC msdb.dbo.sp_send_dbmail
            @profile_name = @ProfileName,
            @recipients = @Recipients,
            @subject = 'CRITICAL: SQL Server Maintenance Failure',
            @body = @HtmlBody,
            @body_format = 'HTML';
    END
END