## ADDED Requirements

### Requirement: Infrastructure Module Interface
The system SHALL define a standard interface for infrastructure modules that can be reused across different frameworks.

#### Scenario: Module interface definition
- **WHEN** an infrastructure module is created
- **THEN** it SHALL implement standard functions:
  - module_{type}_setup: Initialize module environment
  - module_{type}_cli: Provide CLI access
  - module_{type}_healthcheck: Check module health
- **AND** modules MAY implement additional functions for specific capabilities
- **AND** modules SHALL be framework-agnostic

#### Scenario: Module independence
- **WHEN** infrastructure modules are loaded
- **THEN** each module SHALL be independently testable
- **AND** modules SHALL NOT depend on framework-specific logic
- **AND** modules SHALL communicate through standard interfaces

### Requirement: Database Module
The system SHALL provide database infrastructure module supporting multiple database engines (PostgreSQL, MySQL, MariaDB).

#### Scenario: Database CLI access for PostgreSQL
- **WHEN** user executes "psql" command
- **THEN** it SHALL connect to PostgreSQL database container
- **AND** it SHALL use PGPASSWORD environment variable for authentication
- **AND** it SHALL connect to correct host, port, database, and user
- **AND** it SHALL support stdin for piping queries

#### Scenario: Database CLI access for MySQL
- **WHEN** user executes "mysql" command
- **THEN** it SHALL connect to MySQL database container
- **AND** it SHALL use MYSQL_PWD environment variable for authentication
- **AND** it SHALL connect to correct host, port, database, and user
- **AND** it SHALL support stdin for piping queries

#### Scenario: Generic database CLI access
- **WHEN** user executes "database-cli" command
- **THEN** it SHALL provide bash shell in database container
- **AND** it SHALL detect database schema automatically
- **AND** it SHALL provide access to appropriate database client tools

#### Scenario: Database export
- **WHEN** user requests database export
- **THEN** it SHALL detect database schema (PostgreSQL/MySQL)
- **AND** it SHALL use appropriate dump command (pg_dump/mysqldump)
- **AND** it SHALL compress output with gzip
- **AND** it SHALL save to timestamped file
- **AND** it SHALL clean MySQL dumps of DEFINER clauses

#### Scenario: Database import
- **WHEN** user imports database dump
- **THEN** it SHALL detect dump file format (.sql, .sql.gz)
- **AND** it SHALL decompress if needed
- **AND** it SHALL execute import in database container
- **AND** it SHALL report import progress and errors

### Requirement: Webserver Module
The system SHALL provide webserver infrastructure module supporting nginx with framework-specific configurations.

#### Scenario: Nginx container management
- **WHEN** webserver services start
- **THEN** it SHALL use nginx container
- **AND** it SHALL mount application code read-only
- **AND** it SHALL depend on FPM container health
- **AND** it SHALL expose configured port

#### Scenario: Nginx configuration
- **WHEN** nginx container builds
- **THEN** it SHALL copy framework-appropriate configuration
- **AND** it SHALL set APP_DIR build argument
- **AND** it SHALL configure FastCGI proxy to FPM container

#### Scenario: Health check
- **WHEN** checking webserver health
- **THEN** it SHALL verify nginx port is open
- **AND** it SHALL retry with configured intervals
- **AND** it SHALL report unhealthy status on failure

### Requirement: Cache Module (Redis)
The system SHALL provide Redis cache infrastructure module with multiple database support for different cache types.

#### Scenario: Redis service initialization
- **WHEN** Redis container starts
- **THEN** it SHALL use Redis 6.2 or newer
- **AND** it SHALL expose Redis port 6379
- **AND** it SHALL provide health check

#### Scenario: Multiple cache databases
- **WHEN** application uses Redis
- **THEN** it SHALL support multiple Redis databases:
  - Database 0: Session storage
  - Database 1: Cache storage
  - Database 2: Doctrine cache
  - Database 3: Layout cache
- **AND** environment variables SHALL specify correct database numbers

### Requirement: Search Module (Elasticsearch)
The system SHALL provide Elasticsearch search infrastructure module for full-text search capabilities.

#### Scenario: Elasticsearch service initialization
- **WHEN** Elasticsearch container starts
- **THEN** it SHALL use configured Elasticsearch version
- **AND** it SHALL run in single-node mode for development
- **AND** it SHALL disable xpack security for development
- **AND** it SHALL expose port 9200

#### Scenario: Elasticsearch configuration
- **WHEN** configuring Elasticsearch
- **THEN** it SHALL set cluster name based on project
- **AND** it SHALL configure Java heap size (ES_JAVA_OPTS)
- **AND** it SHALL persist data to Docker volume
- **AND** it SHALL provide health check on port 9200

### Requirement: Message Queue Module (RabbitMQ)
The system SHALL provide RabbitMQ message queue infrastructure module for asynchronous processing.

#### Scenario: RabbitMQ service initialization
- **WHEN** RabbitMQ container starts
- **THEN** it SHALL use RabbitMQ 3.9 with management plugin
- **AND** it SHALL configure default user and password
- **AND** it SHALL expose management UI port
- **AND** it SHALL expose AMQP port 5672

#### Scenario: RabbitMQ credentials
- **WHEN** configuring RabbitMQ
- **THEN** it SHALL read credentials from environment variables
- **AND** it SHALL default to app/app for development
- **AND** it SHALL provide connection string to application containers

### Requirement: Mail Server Module (MailHog)
The system SHALL provide MailHog mail server infrastructure module for email testing in development.

#### Scenario: MailHog service initialization
- **WHEN** MailHog container starts
- **THEN** it SHALL provide SMTP server on port 1025
- **AND** it SHALL provide web UI on port 8025
- **AND** it SHALL be accessible from application containers

#### Scenario: Email capture
- **WHEN** application sends email
- **THEN** MailHog SHALL capture all outgoing emails
- **AND** emails SHALL be viewable in web UI
- **AND** no emails SHALL be sent to real addresses

### Requirement: SSH Module
The system SHALL provide SSH access module for remote development and CI/CD scenarios.

#### Scenario: SSH service initialization
- **WHEN** SSH container starts
- **THEN** it SHALL provide SSH server on configured port
- **AND** it SHALL use same base image as CLI container
- **AND** it SHALL mount application code and home directories
- **AND** it SHALL run as root but support user switching

#### Scenario: SSH key management
- **WHEN** SSH service starts
- **THEN** it SHALL persist host keys across restarts
- **AND** it SHALL support public key authentication
- **AND** it SHALL allow ORO_SSH_PUBLIC_KEY environment variable

#### Scenario: SSH container capabilities
- **WHEN** user connects via SSH
- **THEN** it SHALL provide full shell access
- **AND** it SHALL have all PHP, Node, and Composer tools available
- **AND** it SHALL have access to all infrastructure services
- **AND** it SHALL support running long-lived processes

### Requirement: Infrastructure Environment Variables
The system SHALL provide standardized environment variables for infrastructure configuration.

#### Scenario: Database environment variables
- **WHEN** database infrastructure is configured
- **THEN** it SHALL provide:
  - DC_DATABASE_HOST (host name)
  - DC_DATABASE_PORT (port number)
  - DC_DATABASE_USER (username)
  - DC_DATABASE_PASSWORD (password)
  - DC_DATABASE_DBNAME (database name)
  - DC_DATABASE_SCHEMA (pgsql/mysql)
  - DC_DATABASE_URI (full connection string)

#### Scenario: Service discovery environment variables
- **WHEN** infrastructure services are configured
- **THEN** it SHALL provide:
  - DC_REDIS_URI (Redis connection string)
  - DC_SEARCH_URI (Elasticsearch connection string)
  - DC_MQ_URI (RabbitMQ connection string)
- **AND** these SHALL be usable by any framework

### Requirement: Port Management
The system SHALL manage port allocations for infrastructure services to avoid conflicts.

#### Scenario: Port prefix configuration
- **WHEN** user sets DC_ORO_PORT_PREFIX
- **THEN** it SHALL calculate all service ports from prefix:
  - Nginx: ${PREFIX}80
  - Search: ${PREFIX}00
  - MQ: ${PREFIX}72
  - Mail: ${PREFIX}25
  - SSH: 2222 (fixed)
- **AND** this SHALL allow multiple projects without conflicts

#### Scenario: Bind host configuration
- **WHEN** exposing service ports
- **THEN** it SHALL use bind host from environment:
  - DC_NGINX_BIND_HOST (default 127.0.0.1)
  - DC_SEARCH_BIND_HOST (default 127.0.0.1)
  - DC_MQ_BIND_HOST (default 127.0.0.1)
- **AND** this SHALL control external accessibility

