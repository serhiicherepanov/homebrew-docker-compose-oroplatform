## ADDED Requirements

### Requirement: Docker Compose Orchestration
The core system SHALL provide Docker Compose orchestration capabilities that are framework-agnostic and reusable across different web application frameworks.

#### Scenario: Initialize Docker Compose command
- **WHEN** the system initializes
- **THEN** it SHALL detect the docker compose binary
- **AND** it SHALL build the base Docker Compose command
- **AND** it SHALL validate Docker Compose is available and working

#### Scenario: Load compose files in correct order
- **WHEN** building the final Docker Compose configuration
- **THEN** it SHALL load compose files in the following order:
  1. Base compose file (docker-compose.yml)
  2. Sync mode compose file (default/mutagen/ssh)
  3. Database compose file (pgsql/mysql)
  4. Proxy compose file (if enabled)
  5. Test compose file (if in test mode)
  6. User override compose file (docker-compose.override.yml if exists)
- **AND** each file SHALL be validated before inclusion

#### Scenario: Resolve compose file locations
- **WHEN** searching for compose files
- **THEN** it SHALL check locations in order:
  1. Development tap directory (${BREW_PREFIX}/Homebrew/Library/Taps/.../compose)
  2. Installed pkgshare (${BREW_PREFIX}/share/docker-compose-oroplatform/compose)
  3. Relative to script (${SCRIPT_DIR}/../compose)
- **AND** it SHALL use dynamic Homebrew prefix detection via `brew --prefix`

### Requirement: Environment Initialization
The core system SHALL initialize the environment with appropriate defaults and configuration for the current project.

#### Scenario: Detect project name
- **WHEN** no project name is explicitly configured
- **THEN** it SHALL derive project name from current directory basename
- **AND** it SHALL sanitize the project name to be Docker-compatible

#### Scenario: Set COMPOSE_PROJECT_NAME
- **WHEN** environment is initialized
- **THEN** it SHALL set COMPOSE_PROJECT_NAME equal to the project name
- **AND** this SHALL ensure consistent volume and network naming

#### Scenario: Initialize configuration directory
- **WHEN** configuration directory does not exist
- **THEN** it SHALL create the configuration directory
- **AND** it SHALL set appropriate permissions
- **AND** it SHALL respect DC_ORO_CONFIG_DIR environment variable override

### Requirement: Configuration Directory Management
The core system SHALL manage project-specific configuration directories for storing generated compose files, cached data, and certificates.

#### Scenario: Default configuration directory location
- **WHEN** DC_ORO_CONFIG_DIR is not set
- **THEN** it SHALL use $HOME/.orodc/${PROJECT_NAME} as default
- **AND** it SHALL create the directory if it doesn't exist

#### Scenario: Custom configuration directory location
- **WHEN** DC_ORO_CONFIG_DIR environment variable is set
- **THEN** it SHALL use the specified directory
- **AND** it SHALL create the directory if it doesn't exist
- **AND** this SHALL enable project-local configurations for CI/CD

#### Scenario: Sync compose files to configuration directory
- **WHEN** preparing the environment
- **THEN** it SHALL sync compose files from source to config directory
- **AND** it SHALL use rsync with --delete flag
- **AND** it SHALL exclude SSH keys, cached profiles, and generated compose.yml

### Requirement: Certificate Management
The core system SHALL support custom SSL certificates for building Docker images with enterprise CA certificates.

#### Scenario: Detect project certificates
- **WHEN** project has a .crt directory with certificate files
- **THEN** it SHALL prepare build context with certificates
- **AND** it SHALL copy certificates to ${DC_ORO_CONFIG_DIR}/docker/project-php-node-symfony/.crt
- **AND** it SHALL log the number of certificates found

#### Scenario: Build images with custom certificates
- **WHEN** Docker images are built with certificates present
- **THEN** it SHALL include certificates in build context
- **AND** certificates SHALL be available to Docker during build
- **AND** this SHALL enable working behind corporate proxies

#### Scenario: Clean certificate preparation
- **WHEN** preparing certificates for build
- **THEN** it SHALL remove old certificate directory first
- **AND** it SHALL only copy if certificates actually exist
- **AND** it SHALL skip silently if no certificates present

### Requirement: Dependency Resolution
The core system SHALL resolve and validate critical dependencies with helpful error messages.

#### Scenario: Validate docker command availability
- **WHEN** checking for docker
- **THEN** it SHALL check docker command in PATH
- **AND** it SHALL check common locations (/usr/bin/docker, /usr/local/bin/docker, /snap/bin/docker)
- **AND** if not found, it SHALL display installation instructions
- **AND** it SHALL exit with error code 1

#### Scenario: Validate docker compose availability
- **WHEN** checking for docker compose
- **THEN** it SHALL verify "docker compose" subcommand works
- **AND** if not found, it SHALL display docker compose installation instructions
- **AND** it SHALL exit with error code 1

#### Scenario: Resolve homebrew with fallback
- **WHEN** checking for brew
- **THEN** it SHALL check PATH first
- **AND** if not in PATH, it SHALL check common locations:
  - /opt/homebrew/bin/brew (macOS Apple Silicon)
  - /usr/local/bin/brew (macOS Intel)
  - /home/linuxbrew/.linuxbrew/bin/brew (Linux)
- **AND** if found outside PATH, it SHALL warn user to add to PATH
- **AND** if not found, it SHALL show installation instructions

### Requirement: Cross-Platform Path Handling
The core system SHALL work correctly on Linux, macOS Intel, and macOS Apple Silicon with dynamic path resolution.

#### Scenario: Dynamic Homebrew prefix detection
- **WHEN** resolving Homebrew paths
- **THEN** it SHALL use `brew --prefix` command dynamically
- **AND** it SHALL NOT hardcode platform-specific paths
- **AND** this SHALL work on all supported platforms automatically

#### Scenario: Compose file path resolution order
- **WHEN** searching for compose files
- **THEN** it SHALL try paths in order:
  1. ${BREW_PREFIX}/Homebrew/Library/Taps/.../compose (development)
  2. ${BREW_PREFIX}/share/docker-compose-oroplatform/compose (installed)
  3. ${SCRIPT_DIR}/../compose (relative fallback)
- **AND** it SHALL use the first path that exists

### Requirement: Modular Architecture Support
The core system SHALL support loading additional modules and framework adapters without tight coupling.

#### Scenario: Module loading interface
- **WHEN** core system initializes
- **THEN** it SHALL provide hooks for loading additional modules
- **AND** it SHALL define a consistent module interface
- **AND** modules SHALL be loaded in numbered order (00-*, 10-*, 20-*, etc.)

#### Scenario: Framework adapter integration
- **WHEN** core system is initialized
- **THEN** it SHALL provide integration points for framework adapters
- **AND** it SHALL allow framework adapters to override core functions
- **AND** it SHALL maintain isolation between core and framework-specific code

