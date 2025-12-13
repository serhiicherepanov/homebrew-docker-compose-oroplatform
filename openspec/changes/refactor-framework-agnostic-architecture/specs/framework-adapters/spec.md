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

### Requirement: Migration Documentation
The system SHALL provide comprehensive documentation for users migrating from legacy OroDC v0.x.

#### Scenario: Migration guide availability
- **WHEN** user needs to migrate from OroDC v0.x to WebStack v1.0
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

