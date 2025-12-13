## ADDED Requirements

### Requirement: Command Routing System
The pipeline management system SHALL route commands to appropriate handlers based on command type, arguments, and framework context.

#### Scenario: Detect command type
- **WHEN** processing user input
- **THEN** it SHALL determine if command is:
  - Docker Compose native command (up, down, ps, logs, etc.)
  - Framework-specific command (install, platformupdate, cache:clear, etc.)
  - Infrastructure command (psql, mysql, database-cli, ssh, cli, bash)
  - PHP command (php script.php, bin/console, composer, etc.)
- **AND** it SHALL route to appropriate handler

#### Scenario: Route Docker Compose commands
- **WHEN** command is a Docker Compose native command
- **THEN** it SHALL pass through to Docker Compose with all arguments
- **AND** it SHALL include appropriate profile flags
- **AND** it SHALL include all compose files in correct order

#### Scenario: Route framework-specific commands
- **WHEN** command is framework-specific
- **THEN** it SHALL delegate to framework adapter
- **AND** framework adapter SHALL handle command execution
- **AND** if adapter doesn't implement command, it SHALL show error

#### Scenario: Route infrastructure commands
- **WHEN** command is infrastructure-related (psql, mysql, ssh, etc.)
- **THEN** it SHALL delegate to infrastructure module
- **AND** infrastructure module SHALL execute appropriate Docker command
- **AND** it SHALL pass through all user arguments

### Requirement: Argument Parsing
The pipeline SHALL parse command-line arguments into structured data for proper command execution.

#### Scenario: Parse Docker Compose flags and options
- **WHEN** arguments contain Docker Compose flags
- **THEN** it SHALL separate flags into:
  - left_flags: flags before the command (docker compose --profile=test up)
  - right_flags: flags after the command (docker compose up -d)
  - left_options: options with values before command (--file compose.yml)
  - right_options: options with values after command
- **AND** it SHALL preserve argument order within each category

#### Scenario: Detect first non-flag argument
- **WHEN** parsing arguments
- **THEN** it SHALL identify the first non-flag argument
- **AND** this SHALL be used for command detection
- **AND** it SHALL handle empty argument lists correctly

#### Scenario: Preserve original arguments
- **WHEN** processing arguments
- **THEN** it SHALL save original arguments before any processing
- **AND** these SHALL be available for logging and debugging
- **AND** they SHALL be used for commands requiring exact argument preservation

### Requirement: Command Execution Flow
The pipeline SHALL execute commands with appropriate environment, containers, and error handling.

#### Scenario: Execute in correct container
- **WHEN** command requires container execution
- **THEN** it SHALL determine correct container (cli, fpm, ssh, database-cli)
- **AND** it SHALL check if container is running before execution
- **AND** it SHALL use "docker compose run" for one-off commands
- **AND** it SHALL use "docker compose exec" for running containers

#### Scenario: Build Docker Compose run command
- **WHEN** executing one-off commands
- **THEN** it SHALL build docker compose run command with:
  - Appropriate service name
  - All left flags and options
  - Command to execute
  - All right flags and options
- **AND** flag order SHALL be preserved correctly

#### Scenario: Handle command exit codes
- **WHEN** command execution completes
- **THEN** it SHALL preserve the command's exit code
- **AND** it SHALL exit with the same code
- **AND** error messages SHALL be visible to user

### Requirement: PHP Command Detection
The pipeline SHALL automatically detect and route PHP-related commands to appropriate containers.

#### Scenario: Detect PHP flags
- **WHEN** command starts with PHP flags (-v, --version, -r, -l, -m, -i)
- **THEN** it SHALL route to PHP CLI in container
- **AND** it SHALL execute as "php {flags} {args}"
- **AND** it SHALL NOT require explicit "php" prefix

#### Scenario: Detect PHP files
- **WHEN** first argument ends with .php
- **THEN** it SHALL route to PHP CLI in container
- **AND** it SHALL execute as "php {file} {args}"
- **AND** it SHALL handle external PHP files via volume mounting

#### Scenario: Detect bin/console commands
- **WHEN** command starts with "bin/console"
- **THEN** it SHALL route to CLI container
- **AND** it SHALL execute with appropriate working directory
- **AND** it SHALL pass all arguments through

#### Scenario: Detect composer commands
- **WHEN** command contains "composer"
- **THEN** it SHALL route to CLI container
- **AND** it SHALL execute with composer binary
- **AND** it SHALL handle composer options correctly

### Requirement: Profile Management
The pipeline SHALL manage Docker Compose profiles for optional services and different execution modes.

#### Scenario: Save profiles during up command
- **WHEN** executing "up" command with --profile flags
- **THEN** it SHALL extract and save regular profiles
- **AND** it SHALL extract and save CLI profiles separately
- **AND** profiles SHALL be cached to ${DC_ORO_CONFIG_DIR}/.cached_profiles
- **AND** CLI profiles SHALL be cached to ${DC_ORO_CONFIG_DIR}/.cached_cli_profiles

#### Scenario: Load cached profiles for subsequent commands
- **WHEN** executing commands after "up"
- **THEN** it SHALL load cached regular profiles
- **AND** it SHALL load cached CLI profiles for cleanup commands (down, purge)
- **AND** it SHALL apply profiles to docker compose command
- **AND** this SHALL ensure profile-specific services are managed correctly

#### Scenario: Separate CLI and regular profiles
- **WHEN** caching profiles
- **THEN** it SHALL identify CLI profiles (database-cli, php-cli)
- **AND** it SHALL store CLI profiles separately
- **AND** regular profiles SHALL be used for normal operations
- **AND** CLI profiles SHALL only be used for cleanup operations

### Requirement: Special Command Handling
The pipeline SHALL handle special commands that don't fit standard routing patterns.

#### Scenario: Proxy command passthrough
- **WHEN** command is a proxy command (proxyup, proxydown, etc.)
- **THEN** it SHALL handle before project initialization
- **AND** it SHALL execute without requiring project context
- **AND** it SHALL work from any directory

#### Scenario: Help and version commands
- **WHEN** command is "help", "man", or "version"
- **THEN** it SHALL display appropriate information
- **AND** it SHALL NOT require Docker or project setup
- **AND** it SHALL exit cleanly after displaying information

#### Scenario: Config refresh command
- **WHEN** command is "config-refresh" or "refresh-config"
- **THEN** it SHALL clear cached compose files
- **AND** it SHALL force resync from source
- **AND** it SHALL rebuild configuration
- **AND** it SHALL notify user of completion

### Requirement: Test Environment Support
The pipeline SHALL support special test environment with merged compose files including test services.

#### Scenario: Detect tests command
- **WHEN** command is "tests" or "test"
- **THEN** it SHALL enter test mode
- **AND** it SHALL load docker-compose-test.yml
- **AND** it SHALL merge test services with regular services

#### Scenario: Execute test commands
- **WHEN** in test mode
- **THEN** it SHALL execute remaining arguments in test container
- **AND** it SHALL use appropriate test environment variables
- **AND** it SHALL support PHPUnit and Behat commands

#### Scenario: Test install command
- **WHEN** command is "tests install"
- **THEN** it SHALL set up test environment
- **AND** it SHALL install test dependencies
- **AND** it SHALL prepare test database

