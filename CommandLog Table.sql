CREATE TABLE [dbo].[CommandLog](
    [ID] [int] IDENTITY(1,1) NOT NULL,
    [DatabaseName] [sysname] NOT NULL,
    [CommandType] [nvarchar](50) NOT NULL, -- FULL, DIFF, LOG
    [Command] [nvarchar](max) NOT NULL,
    [StartTime] [datetime] NOT NULL,
    [EndTime] [datetime] NULL,
    [DurationSeconds] AS (DATEDIFF(second, [StartTime], [EndTime])),
    [Status] [nvarchar](20) NULL, -- SUCCESS, FAILURE
    [ErrorMessage] [nvarchar](max) NULL,
    CONSTRAINT [PK_CommandLog] PRIMARY KEY CLUSTERED ([ID] ASC)
);
GO