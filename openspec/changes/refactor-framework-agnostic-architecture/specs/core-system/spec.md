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
- **AND** it SHALL respect DC_CONFIG_DIR environment variable override

### Requirement: Configuration Directory Management
The core system SHALL manage project-specific configuration directories for storing generated compose files, cached data, and certificates.

#### Scenario: Default configuration directory location
- **WHEN** DC_CONFIG_DIR is not set
- **THEN** it SHALL use $HOME/.dcx/${PROJECT_NAME} as default
- **AND** it SHALL create the directory if it doesn't exist

#### Scenario: Custom configuration directory location
- **WHEN** DC_CONFIG_DIR environment variable is set
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
- **AND** it SHALL copy certificates to ${DC_CONFIG_DIR}/docker/project-php-node-symfony/.crt
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
  2. ${BREW_PREFIX}/share/dcx/compose (installed)
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

### Requirement: Sync Mode Support
The core system SHALL support multiple file synchronization modes optimized for different platforms.

#### Scenario: Default sync mode (Linux/WSL2)
- **WHEN** DC_MODE=default or not set
- **THEN** it SHALL use compose/modes/default.yml
- **AND** it SHALL use direct Docker volume mounts
- **AND** this SHALL provide excellent performance on Linux and WSL2

#### Scenario: Mutagen sync mode (macOS)
- **WHEN** DC_MODE=mutagen
- **THEN** it SHALL use compose/modes/mutagen.yml
- **AND** it SHALL use Mutagen for file synchronization
- **AND** it SHALL require mutagen binary to be installed
- **AND** this SHALL avoid slow Docker filesystem on macOS

#### Scenario: SSH sync mode (Remote Docker)
- **WHEN** DC_MODE=ssh
- **THEN** it SHALL use compose/modes/ssh.yml
- **AND** it SHALL use SSH-based remote synchronization
- **AND** this SHALL work with remote Docker hosts
- **AND** this SHALL support Docker-in-Docker scenarios

#### Scenario: Invalid sync mode
- **WHEN** DC_MODE is set to invalid value
- **THEN** it SHALL show error message
- **AND** it SHALL list available modes
- **AND** it SHALL exit with error code 1

### Requirement: Multiple Hostname Support
The core system SHALL support configuring multiple hostnames for a single application instance.

#### Scenario: Configure additional hostnames
- **WHEN** DC_EXTRA_HOSTS="api,admin,shop" is set
- **THEN** it SHALL generate Traefik routing rules for all hostnames
- **AND** main hostname SHALL be ${DC_PROJECT_NAME}.docker.local
- **AND** additional hostnames SHALL include api.docker.local, admin.docker.local, shop.docker.local

#### Scenario: Process short hostname forms
- **WHEN** DC_EXTRA_HOSTS contains short names (single words)
- **THEN** it SHALL automatically append .docker.local suffix
- **AND** "api" SHALL become "api.docker.local"
- **AND** "admin" SHALL become "admin.docker.local"

#### Scenario: Process full hostname forms
- **WHEN** DC_EXTRA_HOSTS contains full hostnames (with dots)
- **THEN** it SHALL use hostnames as-is
- **AND** "api.myproject.local" SHALL remain "api.myproject.local"
- **AND** "external.example.com" SHALL remain "external.example.com"

#### Scenario: Handle mixed hostname formats
- **WHEN** DC_EXTRA_HOSTS="api,admin.myproject.local,external.example.com"
- **THEN** it SHALL process each correctly:
  - "api" → "api.docker.local"
  - "admin.myproject.local" → "admin.myproject.local"
  - "external.example.com" → "external.example.com"

#### Scenario: Generate Traefik routing rule
- **WHEN** building Traefik configuration
- **THEN** it SHALL create Host() rule with OR operator for all hostnames
- **AND** rule SHALL be: `Host(\`project.docker.local\`) || Host(\`api.docker.local\`) || ...`

### Requirement: XDEBUG Configuration Support
The core system SHALL support flexible XDEBUG configuration for debugging PHP applications.

#### Scenario: Global XDEBUG mode
- **WHEN** XDEBUG_MODE environment variable is set
- **THEN** it SHALL apply to all PHP containers (FPM, CLI, consumer)
- **AND** mode SHALL be passed to containers via environment
- **AND** settings SHALL persist until containers are recreated

#### Scenario: Per-container XDEBUG mode
- **WHEN** XDEBUG_MODE_FPM is set
- **THEN** it SHALL apply only to FPM container
- **AND** XDEBUG_MODE_CLI SHALL apply only to CLI container
- **AND** XDEBUG_MODE_CONSUMER SHALL apply only to consumer container
- **AND** per-container settings SHALL override global XDEBUG_MODE

#### Scenario: XDEBUG mode persistence
- **WHEN** XDEBUG mode is configured
- **THEN** it SHALL save configuration to ${DC_CONFIG_DIR}/.xdebug_env
- **AND** configuration SHALL persist across dcx invocations
- **AND** configuration SHALL load automatically on next dcx command

#### Scenario: Disable XDEBUG
- **WHEN** XDEBUG_MODE is not set
- **THEN** it SHALL default to "off"
- **AND** XDEBUG SHALL be disabled for optimal performance
- **AND** no debugging overhead SHALL be present

#### Scenario: Common XDEBUG modes
- **WHEN** setting XDEBUG_MODE
- **THEN** it SHALL support values:
  - "off": Disable XDEBUG
  - "debug": Step debugging
  - "coverage": Code coverage
  - "profile": Performance profiling
  - "trace": Function trace
- **AND** multiple modes SHALL be comma-separated

### Requirement: Custom Docker Image Configuration
The core system SHALL allow overriding Docker images for infrastructure services.

#### Scenario: Override database image
- **WHEN** DC_PGSQL_IMAGE and DC_PGSQL_VERSION are set
- **THEN** it SHALL use custom PostgreSQL image instead of default
- **AND** compose/services/database-pgsql.yml SHALL reference these variables
- **AND** custom image SHALL be used in service definition

#### Scenario: Override cache image
- **WHEN** DC_REDIS_IMAGE and DC_REDIS_VERSION are set
- **THEN** it SHALL use custom Redis image
- **AND** this SHALL allow using Redis alternatives or custom builds

#### Scenario: Override webserver image
- **WHEN** DC_NGINX_IMAGE and DC_NGINX_VERSION are set
- **THEN** it SHALL use custom nginx image
- **AND** custom configurations SHALL be possible

#### Scenario: Plugin services custom images
- **WHEN** plugin provides services (e.g., Elasticsearch)
- **THEN** plugin SHALL manage its own image configuration
- **AND** plugin environment variables SHALL control plugin service images
- **AND** core SHALL NOT know about plugin-specific images

