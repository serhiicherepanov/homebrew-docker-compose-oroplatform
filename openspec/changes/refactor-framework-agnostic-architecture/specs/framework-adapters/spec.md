## ADDED Requirements

### Requirement: Framework Detection System
The system SHALL automatically detect the framework being used and load the appropriate adapter.

#### Scenario: Detect framework from composer.json
- **WHEN** project has composer.json file
- **THEN** it SHALL read composer.json
- **AND** if composer.json contains "oro/" packages, it SHALL detect "oro" framework
- **AND** if composer.json contains "magento/" packages, it SHALL detect "magento" framework
- **AND** if neither matched, it SHALL detect "symfony" or "generic" framework

#### Scenario: Explicit framework configuration
- **WHEN** DC_FRAMEWORK environment variable is set
- **THEN** it SHALL use the specified framework
- **AND** it SHALL override auto-detection
- **AND** it SHALL validate framework adapter exists

#### Scenario: Fallback to generic framework
- **WHEN** framework cannot be detected
- **THEN** it SHALL use generic framework adapter
- **AND** it SHALL provide basic PHP/Symfony functionality
- **AND** it SHALL log warning about using generic mode

### Requirement: Framework Adapter Loading
The system SHALL dynamically load framework adapters and integrate them with the core system.

#### Scenario: Load framework adapter file
- **WHEN** framework is detected
- **THEN** it SHALL construct adapter file path: ${DCX_FRAMEWORKS_DIR}/{framework}.sh
- **AND** it SHALL source the adapter file if it exists
- **AND** if adapter file doesn't exist, it SHALL fall back to generic.sh

#### Scenario: Adapter override mechanism
- **WHEN** framework adapter is loaded
- **THEN** adapter functions SHALL override core functions with same name
- **AND** adapter SHALL have access to all core functions
- **AND** adapter SHALL be able to call core functions before/after override

#### Scenario: Multiple adapter loading
- **WHEN** complex project requires multiple adapters
- **THEN** it SHALL support loading multiple adapters in order
- **AND** later adapters SHALL override earlier adapters
- **AND** this SHALL enable framework composition

### Requirement: Framework Adapter Interface
The system SHALL define standard interface that framework adapters must implement.

#### Scenario: Required adapter functions
- **WHEN** framework adapter is created
- **THEN** it MUST implement:
  - framework_detect: Detect if this framework is present
  - framework_init: Initialize framework-specific environment
  - framework_commands: List framework-specific commands
- **AND** it MAY implement additional framework-specific functions

#### Scenario: Command handling interface
- **WHEN** framework adapter handles commands
- **THEN** it SHALL implement:
  - framework_handle_command: Route framework-specific commands
  - framework_is_special_command: Detect framework-specific commands
- **AND** it SHALL return appropriate exit codes

#### Scenario: Environment variable interface
- **WHEN** framework adapter initializes
- **THEN** it SHALL set framework-specific environment variables
- **AND** it SHALL maintain backward compatibility with existing variables
- **AND** it SHALL document all framework-specific variables

### Requirement: Oro Framework Adapter
The system SHALL provide Oro Platform framework adapter with full support for OroPlatform, OroCommerce, and OroCRM.

#### Scenario: Oro framework detection
- **WHEN** detecting Oro framework
- **THEN** it SHALL check for "oro/" packages in composer.json
- **AND** it SHALL check for "oroinc/" packages
- **AND** it SHALL check for bin/console with oro:* commands

#### Scenario: Oro-specific commands
- **WHEN** Oro adapter is active
- **THEN** it SHALL provide commands:
  - install: Full Oro installation workflow
  - platformupdate: Oro platform update (oro:platform:update)
  - updateurl: Update application URLs for local development
  - cache:clear, cache:warmup: Symfony cache management
  - importdb/exportdb: Oro database dump management with DEFINER cleanup
- **AND** all commands SHALL work with Oro 5.x and 6.x versions

#### Scenario: Oro environment variables
- **WHEN** Oro adapter initializes
- **THEN** it SHALL set Oro-specific environment variables:
  - ORO_DB_URL, ORO_DB_DSN: Database connection strings
  - ORO_SEARCH_ENGINE_DSN: Elasticsearch with oro_search prefix
  - ORO_WEBSITE_SEARCH_ENGINE_DSN: Elasticsearch with oro_website_search prefix
  - ORO_MQ_DSN: RabbitMQ AMQP connection
  - ORO_SESSION_DSN, ORO_REDIS_*_DSN: Redis databases (0-3)
  - ORO_WEBSOCKET_*_DSN: WebSocket server configuration
  - ORO_SECRET: Application secret key
- **AND** these SHALL be derived from DC_* infrastructure variables

#### Scenario: Oro WebSocket support
- **WHEN** Oro adapter manages services
- **THEN** it SHALL include WebSocket container
- **AND** it SHALL configure WebSocket environment
- **AND** it SHALL set up Traefik routing for WebSocket

#### Scenario: Oro consumer support
- **WHEN** Oro adapter manages services
- **THEN** it SHALL include message consumer container
- **AND** consumer SHALL run oro:message-queue:consume
- **AND** consumer SHALL auto-restart on failure

### Requirement: Generic Framework Adapter
The system SHALL provide generic framework adapter for Symfony and other PHP projects.

#### Scenario: Generic framework detection
- **WHEN** no specific framework is detected
- **THEN** generic adapter SHALL activate as fallback
- **AND** it SHALL work with any Symfony-based project
- **AND** it SHALL work with basic PHP projects

#### Scenario: Generic commands
- **WHEN** generic adapter is active
- **THEN** it SHALL provide commands:
  - composer: Composer package management
  - php: PHP script execution
  - bash/ssh: Shell access
  - Database commands (psql/mysql)
- **AND** it SHALL NOT provide framework-specific commands

#### Scenario: Generic environment variables
- **WHEN** generic adapter initializes
- **THEN** it SHALL set only infrastructure variables:
  - DATABASE_URL: Standard database connection
  - REDIS_URL: Standard Redis connection
- **AND** it SHALL NOT set framework-specific variables

### Requirement: Framework Plugin System
The system SHALL support third-party framework adapters through plugin mechanism.

#### Scenario: Plugin directory discovery
- **WHEN** looking for framework adapters
- **THEN** it SHALL check official adapter directory first
- **AND** it SHALL check user plugin directory: ~/.dcx/plugins/
- **AND** it SHALL check project plugin directory: .dcx/plugins/

#### Scenario: Plugin security
- **WHEN** loading third-party plugins
- **THEN** it SHALL require explicit user opt-in
- **AND** it SHALL warn about unofficial plugins
- **AND** it SHALL document plugin security best practices

#### Scenario: Plugin interface compliance
- **WHEN** loading plugin
- **THEN** it SHALL validate plugin implements required interface
- **AND** it SHALL fail gracefully if plugin is incompatible
- **AND** it SHALL report plugin version compatibility

### Requirement: Framework-Specific Docker Images
The system SHALL support framework-specific Docker base images while maintaining reusable infrastructure.

#### Scenario: Base image selection
- **WHEN** framework adapter specifies base image
- **THEN** it SHALL use framework-specific image:
  - Oro: ghcr.io/digitalspacestdio/orodc-php-node-symfony
  - Magento: ghcr.io/digitalspacestdio/dcx-magento
  - Generic: ghcr.io/digitalspacestdio/dcx-php
- **AND** images SHALL be versioned by PHP/Node versions

#### Scenario: Custom image builds
- **WHEN** project requires custom Docker image
- **THEN** framework adapter SHALL support Dockerfile.project
- **AND** it SHALL build from framework-specific base image
- **AND** it SHALL include project-specific dependencies

### Requirement: Fixed Plugin Directory Structure
The system SHALL enforce a standardized directory structure for all plugins to ensure consistency and maintainability.

#### Scenario: Plugin root structure
- **WHEN** plugin is created or loaded
- **THEN** it SHALL have this exact structure:
  - README.md: Plugin overview and usage
  - plugin.sh: Plugin entry point with detection logic
  - commands/: Directory containing all commands
  - services/: Directory containing Docker Compose service files
  - env/: Directory containing environment variable definitions
- **AND** structure SHALL be validated during plugin loading

#### Scenario: Commands directory structure
- **WHEN** plugin provides commands
- **THEN** each command SHALL have its own directory under commands/
- **AND** command directory name SHALL match command name
- **AND** command directory SHALL contain:
  - run.sh: Executable script (required)
  - README.md: Documentation (required)
- **AND** run.sh SHALL be executable (chmod +x)

#### Scenario: Services directory structure
- **WHEN** plugin provides Docker services
- **THEN** services/ directory SHALL contain Docker Compose YAML files
- **AND** each service SHALL be in separate YAML file
- **AND** YAML files SHALL follow naming: {service-name}.yml
- **AND** services SHALL be framework-specific only (not core infrastructure)

#### Scenario: Environment directory structure
- **WHEN** plugin provides environment variables
- **THEN** env/ directory SHALL contain defaults.sh
- **AND** defaults.sh SHALL define all plugin-specific DC_* variables
- **AND** defaults.sh SHALL NOT override core DC_* variables
- **AND** defaults.sh SHALL be sourced before command execution

### Requirement: Command Documentation Standard
The system SHALL require comprehensive documentation for every plugin command through standardized README.md files.

#### Scenario: Command README.md required sections
- **WHEN** command is created
- **THEN** commands/{name}/README.md SHALL contain sections:
  1. "When Called": Trigger conditions and usage context
  2. "Input Schema": JSON structure with required/optional fields
  3. "Output Schema": JSON result structure
  4. "Expected Behavior": What the command does step-by-step
  5. "Logging": What gets logged to stderr
  6. "Usage Examples": At least 2 practical examples
  7. "Error Handling": Error conditions and result format
- **AND** all sections SHALL be present and non-empty

#### Scenario: Document input JSON schema
- **WHEN** command README documents input
- **THEN** it SHALL show example JSON structure
- **AND** it SHALL reference schema file path
- **AND** it SHALL list required fields with types
- **AND** it SHALL list optional fields with defaults
- **AND** it SHALL include field descriptions
- **AND** it SHALL show valid enum values where applicable

#### Scenario: Document output JSON schema
- **WHEN** command README documents output
- **THEN** it SHALL show example result JSON
- **AND** it SHALL reference schema file path
- **AND** it SHALL document status field values
- **AND** it SHALL document data structure contents
- **AND** it SHALL show success and error examples

#### Scenario: Document command behavior
- **WHEN** command README documents behavior
- **THEN** it SHALL describe:
  - Prerequisites (what must be running)
  - Step-by-step execution flow
  - Exit codes and their meanings
  - Error conditions and handling
- **AND** behavior SHALL match actual run.sh implementation

#### Scenario: Document logging strategy
- **WHEN** command README documents logging
- **THEN** it SHALL explain what goes to stderr:
  - Input JSON (for debugging)
  - Execution steps
  - Command outputs
  - Error details
- **AND** it SHALL note that stdout is reserved for JSON result

#### Scenario: Document usage examples
- **WHEN** command README provides examples
- **THEN** it SHALL include:
  - Basic usage (minimal JSON input)
  - Advanced usage (with all optional fields)
  - Result parsing with jq
  - Error handling
  - Testing examples
- **AND** examples SHALL be copy-paste ready
- **AND** examples SHALL include both input and expected output

### Requirement: JSON Communication Protocol (stdin/stdout)
The system SHALL use structured JSON for all communication between core and plugins, with logging via stderr.

#### Scenario: JSON input via stdin
- **WHEN** command script (run.sh) executes
- **THEN** it SHALL receive JSON data via stdin
- **AND** JSON SHALL contain all required configuration
- **AND** JSON SHALL follow documented schema for that command
- **AND** input SHALL be validated against JSON Schema before processing

#### Scenario: JSON output via stdout
- **WHEN** command script completes
- **THEN** it SHALL return JSON result via stdout
- **AND** JSON SHALL contain status, message, data fields
- **AND** JSON SHALL follow standard result schema
- **AND** output SHALL be validated against JSON Schema

#### Scenario: Logging via stderr
- **WHEN** command script executes
- **THEN** all debug logs SHALL go to stderr
- **AND** input JSON SHALL be logged to stderr for debugging
- **AND** execution steps SHALL be logged to stderr
- **AND** stderr logs SHALL NOT interfere with stdout JSON result

#### Scenario: Standard result format
- **WHEN** command returns result
- **THEN** JSON SHALL contain required fields:
  - status: "success" or "error"
  - message: human-readable message
  - data: command-specific result data
- **AND** JSON MAY contain optional fields:
  - exit_code: integer exit code (default 0)
  - warnings: array of warning messages
  - errors: array of error messages
  - metadata: additional metadata (duration, timestamp)

#### Scenario: Error result format
- **WHEN** command fails
- **THEN** it SHALL return error result via stdout
- **AND** status field SHALL be "error"
- **AND** exit_code field SHALL match script exit code
- **AND** errors array SHALL contain error descriptions
- **AND** script SHALL exit with non-zero code

### Requirement: JSON Schema Validation
The system SHALL validate all JSON input and output against documented JSON Schema files.

#### Scenario: Schema file structure
- **WHEN** plugin is created
- **THEN** it SHALL have schemas/ directory
- **AND** schemas SHALL be organized by command:
  - schemas/plugins/{plugin}/{ command}-input.schema.json
  - schemas/plugins/{plugin}/{command}-output.schema.json
- **AND** core SHALL provide common schemas:
  - schemas/core/command-result.schema.json
  - schemas/core/project-config.schema.json
  - schemas/core/database-config.schema.json

#### Scenario: Input validation before execution
- **WHEN** command script receives JSON input
- **THEN** it SHALL validate against input schema first
- **AND** if validation fails, it SHALL return error without executing
- **AND** error SHALL indicate which fields failed validation
- **AND** validation SHALL use ajv-cli or jq for checking

#### Scenario: Output validation before returning
- **WHEN** command prepares result JSON
- **THEN** it SHOULD validate against output schema
- **AND** if validation fails, it SHOULD log warning to stderr
- **AND** it SHALL still return result (validation is advisory)
- **AND** validation helps catch schema drift during development

#### Scenario: Schema documentation in README
- **WHEN** command README.md is written
- **THEN** it SHALL document input schema with example
- **AND** it SHALL document output schema with example
- **AND** it SHALL list required vs optional fields
- **AND** it SHALL reference schema file path

#### Scenario: JSON Schema format
- **WHEN** writing schema files
- **THEN** they SHALL use JSON Schema Draft 7 format
- **AND** they SHALL include $schema and $id fields
- **AND** they SHALL define types, required fields, constraints
- **AND** they SHALL include human-readable descriptions
- **AND** they SHALL include examples where helpful

### Requirement: Plugin Auto-Registration from Directory Structure
The system SHALL automatically discover and register plugin commands from the commands/ directory structure.

#### Scenario: Automatic command discovery
- **WHEN** plugin_init() is called
- **THEN** it SHALL scan plugins/{name}/commands/ directory
- **AND** for each subdirectory with run.sh, it SHALL register a command
- **AND** command name SHALL match directory name
- **AND** registration SHALL be automatic (no manual list required)

#### Scenario: Command validation during registration
- **WHEN** registering command from directory
- **THEN** it SHALL verify run.sh exists and is executable
- **AND** it SHALL verify README.md exists and is non-empty
- **AND** if validation fails, it SHALL skip command with warning
- **AND** it SHALL log which commands were successfully registered

#### Scenario: Command execution routing
- **WHEN** user runs dcx {command}
- **THEN** system SHALL lookup registered command
- **AND** if command belongs to plugin, it SHALL execute commands/{name}/run.sh
- **AND** it SHALL set working directory to project root
- **AND** it SHALL pass all environment variables
- **AND** it SHALL capture and return exit code

### Requirement: Plugin README.md Documentation Standard
The system SHALL require top-level README.md in every plugin to document plugin overview and integration.

#### Scenario: Plugin README required sections
- **WHEN** plugin is created
- **THEN** plugins/{name}/README.md SHALL contain:
  1. "Plugin Overview": What framework this supports
  2. "Detection Logic": How auto-detection works
  3. "Commands": List of all available commands
  4. "Services": List of additional Docker services
  5. "Environment Variables": Plugin-specific variables
- **AND** README SHALL link to individual command documentation

#### Scenario: Document framework detection
- **WHEN** plugin README documents detection
- **THEN** it SHALL explain:
  - What files are checked (composer.json, etc.)
  - What patterns trigger detection (package names, etc.)
  - How to force plugin: export DCX_PLUGIN={name}
- **AND** examples SHALL be provided

#### Scenario: Document available commands
- **WHEN** plugin README documents commands
- **THEN** it SHALL list each command with:
  - Command name
  - Brief description
  - Link to commands/{name}/README.md
- **AND** list SHALL be kept in sync with commands/ directory

### Requirement: Migration Documentation
The system SHALL provide comprehensive documentation for users migrating from legacy OroDC v0.x.

#### Scenario: Migration guide availability
- **WHEN** user needs to migrate from OroDC v0.x to DCX v1.0
- **THEN** migration guide SHALL be available in documentation
- **AND** guide SHALL explain all breaking changes
- **AND** guide SHALL provide step-by-step migration instructions

#### Scenario: Environment variable mapping
- **WHEN** migration guide documents variable changes
- **THEN** it SHALL provide clear mapping table:
  - DC_ORO_NAME → DC_PROJECT_NAME
  - DC_ORO_PHP_VERSION → DC_PHP_VERSION
  - DC_ORO_DATABASE_* → DC_DATABASE_*
  - .env.orodc → .env.dcx
  - ~/.orodc/ → ~/.dcx/
- **AND** it SHALL include examples for each variable

#### Scenario: Command equivalence table
- **WHEN** migration guide documents command changes
- **THEN** it SHALL show command equivalence:
  - orodc install → dcx install (with Oro adapter)
  - orodc up → dcx up
  - orodc platformupdate → dcx platformupdate
- **AND** it SHALL note that functionality remains identical

#### Scenario: Side-by-side installation support
- **WHEN** user wants both old and new versions
- **THEN** documentation SHALL explain:
  - Different Homebrew formulas can coexist
  - Different configuration directories (~/.orodc vs ~/.dcx)
  - How to use each version for different projects
- **AND** it SHALL provide troubleshooting for common issues

