What the Maintenance Solution Includes
1. DatabaseBackup

Handles backups of your databases:

Full backups
Differential backups
Transaction log backups
Backup compression & cleanup

👉 Essential for disaster recovery.

2. DatabaseIntegrityCheck

Runs consistency checks using DBCC:

Detects corruption
Ensures database integrity
Can run on all or selected databases

👉 Critical for data reliability.

3. IndexOptimize

Maintains indexes and statistics:

Reorganizes or rebuilds indexes
Updates statistics
Reduces fragmentation

👉 Improves query performance.

4. CommandExecute
Core stored procedure used internally
Executes maintenance commands
Handles logging and error management

👉 Always required.

5. CommandLog
Table that stores execution history
Logs success/failure, duration, commands

👉 Optional but highly recommended for monitor
