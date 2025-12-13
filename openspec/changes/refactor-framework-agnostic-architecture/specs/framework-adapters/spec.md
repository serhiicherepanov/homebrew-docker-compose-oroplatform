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
- **THEN** it SHALL construct adapter file path: ${WEBSTACK_FRAMEWORKS_DIR}/{framework}.sh
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
The system SHALL provide Oro Platform framework adapter maintaining 100% backward compatibility.

#### Scenario: Oro framework detection
- **WHEN** detecting Oro framework
- **THEN** it SHALL check for "oro/" packages in composer.json
- **AND** it SHALL check for "oroinc/" packages
- **AND** it SHALL check for bin/console with Oro-specific commands

#### Scenario: Oro-specific commands
- **WHEN** Oro adapter is active
- **THEN** it SHALL provide commands:
  - install: Full Oro installation
  - platformupdate/updateplatform: Oro platform update
  - updateurl/seturl: Update application URLs
  - cache:clear, cache:warmup: Symfony cache commands
  - importdb/exportdb: Database management
  - composer install integration
- **AND** all SHALL work exactly as current orodc implementation

#### Scenario: Oro environment variables
- **WHEN** Oro adapter initializes
- **THEN** it SHALL set:
  - ORO_DB_URL, ORO_DB_DSN: Database connection
  - ORO_SEARCH_URL, ORO_SEARCH_DSN: Elasticsearch connection
  - ORO_MQ_DSN: RabbitMQ connection
  - ORO_REDIS_URL, ORO_REDIS_*_DSN: Redis connections
  - ORO_WEBSOCKET_*_DSN: WebSocket configuration
  - ORO_SECRET: Application secret
- **AND** it SHALL maintain DC_ORO_* variable compatibility

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
- **AND** it SHALL check user plugin directory: ~/.webstack/plugins/
- **AND** it SHALL check project plugin directory: .webstack/plugins/

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
  - Magento: ghcr.io/digitalspacestdio/webstack-magento
  - Generic: ghcr.io/digitalspacestdio/webstack-php
- **AND** images SHALL be versioned by PHP/Node versions

#### Scenario: Custom image builds
- **WHEN** project requires custom Docker image
- **THEN** framework adapter SHALL support Dockerfile.project
- **AND** it SHALL build from framework-specific base image
- **AND** it SHALL include project-specific dependencies

### Requirement: Backward Compatibility Layer
The system SHALL maintain 100% backward compatibility with existing orodc installations during transition.

#### Scenario: Command name compatibility
- **WHEN** user invokes "orodc" command
- **THEN** it SHALL work identically to current implementation
- **AND** it SHALL automatically use Oro framework adapter
- **AND** it SHALL support all existing commands and flags

#### Scenario: Environment variable compatibility
- **WHEN** user uses DC_ORO_* variables
- **THEN** they SHALL continue working without changes
- **AND** they SHALL be mapped to new DC_* variables internally
- **AND** no deprecation warnings SHALL appear initially

#### Scenario: Configuration file compatibility
- **WHEN** user has existing .env.orodc file
- **THEN** it SHALL continue working
- **AND** it SHALL be loaded and parsed correctly
- **AND** variables SHALL be available in containers

#### Scenario: Docker Compose compatibility
- **WHEN** using existing docker-compose.yml files
- **THEN** they SHALL continue working
- **AND** all services SHALL start correctly
- **AND** all volumes and networks SHALL remain compatible

### Requirement: Migration Support
The system SHALL provide tools and documentation for migrating from orodc to framework-agnostic webstack.

#### Scenario: Migration detection
- **WHEN** user has existing orodc installation
- **THEN** system SHALL detect old configuration
- **AND** it SHALL offer to migrate to new structure
- **AND** migration SHALL be optional, not forced

#### Scenario: Variable migration warnings
- **WHEN** migration mode is enabled
- **THEN** it SHALL show deprecation warnings for DC_ORO_* variables
- **AND** warnings SHALL include new variable names
- **AND** warnings SHALL be suppressible via flag

#### Scenario: Migration guide
- **WHEN** user accesses migration documentation
- **THEN** it SHALL provide step-by-step migration instructions
- **AND** it SHALL include examples for common scenarios
- **AND** it SHALL document breaking changes
- **AND** it SHALL provide rollback instructions

