## ADDED Requirements

### Requirement: FILE-SYNC-006 - Disk Space Check Before Mutagen Sync

When `DC_ORO_MODE=mutagen` is set, the system SHALL check available disk space in the target Docker volume before starting mutagen sync operations.

#### Scenario: Sufficient Disk Space for Mutagen Sync
- **WHEN** `DC_ORO_MODE=mutagen` is set
- **AND** project directory size is calculated
- **AND** available space in Docker volume `${DC_ORO_NAME}_appcode` is sufficient (project size + 20% overhead)
- **AND** user runs `orodc compose up`
- **THEN** the system SHALL proceed with mutagen sync
- **AND** no error SHALL be displayed

#### Scenario: Insufficient Disk Space for Mutagen Sync
- **WHEN** `DC_ORO_MODE=mutagen` is set
- **AND** project directory size is calculated
- **AND** available space in Docker volume `${DC_ORO_NAME}_appcode` is insufficient (less than project size + 20% overhead)
- **AND** user runs `orodc compose up`
- **THEN** the system SHALL display an error message
- **AND** the error message SHALL show required space and available space in human-readable format
- **AND** the error message SHALL mention `DC_ORO_SKIP_DISK_CHECK=1` bypass option
- **AND** mutagen sync SHALL NOT start
- **AND** containers SHALL NOT start

#### Scenario: Disk Space Check Bypass for Mutagen Sync
- **WHEN** `DC_ORO_MODE=mutagen` is set
- **AND** `DC_ORO_SKIP_DISK_CHECK=1` is set
- **AND** user runs `orodc compose up`
- **THEN** the system SHALL skip disk space checking
- **AND** mutagen sync SHALL proceed normally

#### Scenario: Disk Space Check Timing for Mutagen Sync
- **WHEN** `DC_ORO_MODE=mutagen` is set
- **AND** user runs `orodc compose up`
- **THEN** disk space check SHALL occur after Docker volume creation
- **AND** disk space check SHALL occur before mutagen sync starts
- **AND** disk space check SHALL occur before containers start

### Requirement: FILE-SYNC-007 - Disk Space Check Before RSync Sync

When `DC_ORO_MODE=ssh` is set, the system SHALL check available disk space in the target container or volume before starting rsync sync operations.

#### Scenario: Sufficient Disk Space for RSync Sync
- **WHEN** `DC_ORO_MODE=ssh` is set
- **AND** project directory size is calculated
- **AND** available space in target container or volume is sufficient (project size + 20% overhead)
- **AND** user runs `orodc compose up`
- **THEN** the system SHALL proceed with rsync sync
- **AND** no error SHALL be displayed

#### Scenario: Insufficient Disk Space for RSync Sync
- **WHEN** `DC_ORO_MODE=ssh` is set
- **AND** project directory size is calculated
- **AND** available space in target container or volume is insufficient (less than project size + 20% overhead)
- **AND** user runs `orodc compose up`
- **THEN** the system SHALL display an error message
- **AND** the error message SHALL show required space and available space in human-readable format
- **AND** the error message SHALL mention `DC_ORO_SKIP_DISK_CHECK=1` bypass option
- **AND** rsync sync SHALL NOT start
- **AND** containers SHALL NOT start

#### Scenario: Disk Space Check Bypass for RSync Sync
- **WHEN** `DC_ORO_MODE=ssh` is set
- **AND** `DC_ORO_SKIP_DISK_CHECK=1` is set
- **AND** user runs `orodc compose up`
- **THEN** the system SHALL skip disk space checking
- **AND** rsync sync SHALL proceed normally

#### Scenario: Disk Space Check Timing for RSync Sync
- **WHEN** `DC_ORO_MODE=ssh` is set
- **AND** user runs `orodc compose up`
- **THEN** disk space check SHALL occur after Docker volume creation
- **AND** disk space check SHALL occur before rsync sync starts
- **AND** disk space check SHALL occur before containers start

#### Scenario: RSync Check with Container Not Running
- **WHEN** `DC_ORO_MODE=ssh` is set
- **AND** target container is not running
- **AND** user runs `orodc compose up`
- **THEN** the system SHALL check available space in Docker volume `${DC_ORO_NAME}_appcode` instead
- **AND** disk space check SHALL proceed normally

### Requirement: FILE-SYNC-008 - Project Size Calculation

The system SHALL calculate the size of the project directory before checking available disk space.

#### Scenario: Project Size Calculation
- **WHEN** disk space check is triggered
- **AND** project directory `${DC_ORO_APPDIR}` exists
- **THEN** the system SHALL calculate total size of all files in the directory
- **AND** calculation SHALL include all subdirectories and files
- **AND** calculation SHALL use accurate byte count (not estimated)
- **AND** calculation SHALL add 20% overhead for sync operations

#### Scenario: Empty Project Directory
- **WHEN** disk space check is triggered
- **AND** project directory `${DC_ORO_APPDIR}` is empty
- **THEN** the system SHALL calculate size as 0 bytes (plus overhead)
- **AND** disk space check SHALL pass (0 bytes always fits)

#### Scenario: Large Project Directory
- **WHEN** disk space check is triggered
- **AND** project directory `${DC_ORO_APPDIR}` is very large (> 10GB)
- **THEN** the system SHALL calculate size correctly
- **AND** calculation SHALL complete within reasonable time (< 30 seconds for typical projects)

### Requirement: FILE-SYNC-009 - Disk Space Check Error Messages

The system SHALL display clear, actionable error messages when disk space is insufficient.

#### Scenario: Error Message Format
- **WHEN** disk space check fails due to insufficient space
- **THEN** the system SHALL display error message using `msg_error()`
- **AND** error message SHALL include required space in human-readable format (GB, MB, KB)
- **AND** error message SHALL include available space in human-readable format
- **AND** error message SHALL mention `DC_ORO_SKIP_DISK_CHECK=1` bypass option
- **AND** error message SHALL be clear and actionable

#### Scenario: Error Message Example
- **WHEN** required space is 2.5GB and available space is 1.2GB
- **THEN** error message SHALL display: "Insufficient disk space for sync: Required: 2.5GB, Available: 1.2GB"
- **AND** error message SHALL include bypass instruction

### Requirement: FILE-SYNC-010 - Default Mode No Disk Check

When `DC_ORO_MODE=default` is set, the system SHALL NOT perform disk space checks.

#### Scenario: Default Mode No Check
- **WHEN** `DC_ORO_MODE=default` is set (or not set, defaulting to default)
- **AND** user runs `orodc compose up`
- **THEN** the system SHALL NOT perform disk space checks
- **AND** containers SHALL start normally
- **AND** no disk space check messages SHALL be displayed
