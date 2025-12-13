# Implementation Tasks

## 1. Analysis and Preparation
- [ ] 1.1 Document all existing functions and categorize:
  - Core infrastructure functions
  - Oro-specific functions → move to plugin
  - Framework-agnostic CLI functions
- [ ] 1.2 Design minimal core variable scheme (DC_*)
- [ ] 1.3 Map each existing service to separate compose file:
  - Which services are core (PHP, nginx, DB, Redis, MQ)
  - Which services are framework-specific (Elasticsearch, WebSocket, Consumer)
- [ ] 1.4 Design plugin interface and discovery
- [ ] 1.5 Create test strategy for:
  - Core without plugins
  - Core + Oro plugin
  - Individual service compose files
- [ ] 1.6 Finalize project naming (dcx confirmed)

## 2. Core System Module (Bash)
- [ ] 2.1 Create bin/dcx entry point (~100 lines)
  - Strict mode: set -euo pipefail
  - Module loader
  - Command dispatcher
- [ ] 2.2 Create bin/dcx.d/00-core.sh
  - Docker Compose orchestration functions
  - Compose file loading logic
  - Command execution wrapper
- [ ] 2.3 Add bats test framework setup
  - Install instructions
  - Test directory structure
  - Example tests
- [ ] 2.4 Add shellcheck configuration
  - .shellcheckrc
  - CI/CD integration
  - Local validation script
- [ ] 2.5 Write bats tests for core functions
  - Test compose file loading
  - Test Docker Compose command building
  - Test error handling
- [ ] 2.6 Document bash coding standards
  - Modern bash features to use
  - Error handling patterns
  - Testing approach

## 3. Utilities Module
- [ ] 3.1 Create bin/dcx.d/10-utils.sh
- [ ] 3.2 Extract message formatting functions (msg_info, msg_error, etc.)
- [ ] 3.3 Extract binary resolution functions (resolve_bin)
- [ ] 3.4 Add utility function tests
- [ ] 3.5 Document utility function API

## 4. Environment Module
- [ ] 4.1 Create bin/dcx.d/20-env.sh
- [ ] 4.2 Implement clean environment variable initialization (DC_*)
- [ ] 4.3 Add framework-agnostic defaults
- [ ] 4.4 Extract .env file loading logic (.env.dcx)
- [ ] 4.5 Add environment validation functions
- [ ] 4.6 Add environment resolution tests

## 5. Smart Argument Parsing (CRITICAL - Core UX Feature)
- [ ] 5.1 Create bin/dcx.d/30-argument-parser.sh
  - Parse Docker Compose flags (left vs right)
  - Detect command boundary
  - Organize into buckets (left_flags, command, args, right_flags)
  - Handle --option=value and --option value forms
  - Preserve argument quoting and special chars
- [ ] 5.2 Implement is_compose_command() detection
  - Recognize all Docker Compose native commands
  - up, down, start, stop, restart
  - ps, logs, exec, run, build, pull, push
  - config, version, ls, etc.
- [ ] 5.3 Add argument preservation
  - Proper bash array handling: "${args[@]}"
  - Quote preservation
  - Special character escaping
  - Space handling in arguments
- [ ] 5.4 Write comprehensive tests for argument parsing
  - Test: dcx --profile=test up -d
  - Test: dcx --profile=test run --rm cli php bin/console cache:clear --env=prod
  - Test: Arguments with spaces and quotes
  - Test: Special characters ($, `, !, etc.)
- [ ] 5.5 Add DEBUG mode output
  - Show parsed buckets
  - Show final command
  - Help troubleshoot argument issues
- [ ] 5.6 Performance optimize
  - Skip parsing for simple commands
  - Fast path for common cases
  - Maintain <100ms startup target

## 6. Transparent Binary Redirection (CRITICAL - Core UX Feature)
- [ ] 6.1 Create bin/dcx.d/35-redirect.sh
  - Detect calling name (symlink support)
  - Detect PHP flags (-v, --version, -r, etc.)
  - Detect file extensions (.php, .js, .py)
  - Detect framework patterns (bin/console, cache:*, oro:*)
- [ ] 6.2 Implement detect_transparent_redirect()
  - Check if called as symlink (php, node, python)
  - Check first argument for indicators
  - Return detected binary or false
- [ ] 6.3 Implement execute_with_redirect()
  - Check if container running (exec vs run)
  - Execute with proper binary
  - Pass all arguments through
  - Preserve stdin/stdout/stderr
- [ ] 6.4 Add DC_DEFAULT_BINARY configuration
  - Environment variable support
  - Plugin can set default
  - Values: php, node, python, ruby, make, none
  - Document per-project configuration
- [ ] 6.5 Test symlink functionality
  - ln -s dcx php
  - Test php --version
  - Test php bin/console
  - Test php script.php
- [ ] 6.6 Test transparent detection
  - dcx -v (PHP version)
  - dcx bin/console cache:clear
  - dcx script.php args
  - dcx node app.js (if DC_DEFAULT_BINARY=node)
- [ ] 6.7 Document transparent redirection
  - How it works
  - Configuration options
  - Framework-specific behavior
  - Troubleshooting

## 7. Pipeline & Command Routing
- [ ] 7.1 Create bin/dcx.d/40-pipeline.sh
  - Integrate argument parser
  - Integrate transparent redirect
  - Command routing logic
  - Error handling
- [ ] 7.2 Implement command dispatcher
  - Route Docker Compose commands
  - Route plugin commands
  - Route transparent redirects
  - Route core commands (ssh, cli, bash)
- [ ] 7.3 Add command execution wrapper
  - Build final docker compose command
  - Execute with proper flags
  - Stream output
  - Capture exit code
- [ ] 7.4 Write integration tests
  - Test full command flow
  - Test all routing paths
  - Test error scenarios

## 6. Compose Management Module
- [ ] 6.1 Create bin/dcx.d/40-compose.sh
- [ ] 6.2 Extract compose file management functions
- [ ] 6.3 Implement profile caching system
- [ ] 6.4 Add DSN parsing functions
- [ ] 6.5 Extract Traefik rule building
- [ ] 6.6 Add Docker network management
- [ ] 6.7 Test compose file merging logic

## 8. Core CLI Commands (Framework-Agnostic)
- [ ] 8.1 Create bin/dcx.d/50-cli.sh (generic CLI commands)
- [ ] 7.2 Implement database commands:
  - dcx psql (PostgreSQL CLI)
  - dcx mysql (MySQL CLI)
  - dcx database-cli (generic DB shell)
- [ ] 7.3 Create bin/dcx.d/40-database.sh (import/export)
- [ ] 7.4 Implement database import:
  - Support .sql and .sql.gz formats
  - Auto-detect database schema
  - Progress reporting
- [ ] 7.5 Implement database export:
  - Auto-detect database schema
  - Compress with gzip
  - Timestamped filenames
  - MySQL DEFINER cleanup
- [ ] 7.6 Implement container commands:
  - dcx ssh (SSH access)
  - dcx cli (CLI container bash)
  - dcx bash (alias for cli)
- [ ] 7.7 Test all CLI commands without plugins
- [ ] 7.8 Document core CLI command usage

## 9. Database Operations Module
- [ ] 9.1 Create bin/dcx.d/60-database.sh
- [ ] 9.2 Implement database import (from tasks 8.4-8.5)
- [ ] 9.3 Implement database export (from tasks 8.4-8.5)
- [ ] 9.4-9.8 (keep existing database tasks)

## 10. Plugin System
- [ ] 8.1 Create bin/dcx.d/50-plugin-loader.sh
- [ ] 8.2 Design plugin interface (plugin_detect, plugin_init, etc.)
- [ ] 8.3 Implement plugin discovery mechanism
- [ ] 8.4 Create command registration system
- [ ] 8.5 Implement plugin compose file loading
- [ ] 8.6 Add plugin environment variable loading
- [ ] 8.7 Test plugin isolation (core works without plugins)
- [ ] 8.8 Test plugin loading and unloading

## 9. Oro Plugin
- [ ] 9.1 Create plugins/oro directory structure
- [ ] 9.2 Create plugins/oro/plugin.sh (detection and init)
- [ ] 9.3 Create plugins/oro/env.sh (Oro environment variables)
- [ ] 9.4 Create Oro-specific compose files:
  - plugins/oro/compose/websocket.yml
  - plugins/oro/compose/consumer.yml
  - plugins/oro/compose/search.yml (Elasticsearch)
- [ ] 9.5 Implement Oro commands:
  - plugins/oro/commands/install.sh
  - plugins/oro/commands/platformupdate.sh
  - plugins/oro/commands/updateurl.sh
  - plugins/oro/commands/cache-clear.sh
  - plugins/oro/commands/cache-warmup.sh
- [ ] 9.6 Test Oro plugin with OroCommerce 6.1
- [ ] 9.7 Test Oro plugin with OroPlatform 6.1
- [ ] 9.8 Document Oro plugin features
- [ ] 9.9 Verify core works WITHOUT Oro plugin loaded

## 10. Core Functionality (No Plugin Required)
- [ ] 10.1 Verify core works standalone (no plugins)
- [ ] 10.2 Test basic commands:
  - dcx up -d
  - dcx down
  - dcx ps
  - dcx logs
- [ ] 10.3 Test database operations:
  - dcx importdb dump.sql
  - dcx exportdb
  - dcx psql / mysql
- [ ] 10.4 Test PHP commands:
  - dcx php -v
  - dcx composer install
  - dcx ssh
  - dcx cli bash
- [ ] 10.5 Test with plain Symfony projects (no plugin)
- [ ] 10.6 Test with plain Laravel projects (no plugin)
- [ ] 10.7 Document "core only" usage

## 11. Main Entry Point
- [ ] 11.1 Create bin/dcx main entry point
- [ ] 11.2 Implement module loading system
- [ ] 11.3 Add module initialization order
- [ ] 11.4 Implement framework adapter bootstrapping
- [ ] 11.5 Add version and help commands
- [ ] 11.6 Test complete execution flow

## 12. Configuration Management
- [ ] 12.1 Implement .env.dcx file loading
- [ ] 12.2 Add configuration directory management (~/.dcx/)
- [ ] 12.3 Support DC_CONFIG_DIR environment variable override
- [ ] 12.4 Add configuration validation
- [ ] 12.5 Document configuration best practices
- [ ] 12.6 Test configuration loading in various scenarios

## 13. Compose Files - Base and Modes
- [ ] 13.1 Create compose/base.yml (networks and volumes only):
  - dc_shared_net network
  - appcode volume
  - home-user volume
  - home-root volume
- [ ] 13.2 Create compose/modes/default.yml (direct volume mount)
- [ ] 13.3 Create compose/modes/mutagen.yml (Mutagen sync for macOS)
- [ ] 13.4 Create compose/modes/ssh.yml (SSH remote sync)
- [ ] 13.5 Test each mode independently
- [ ] 13.6 Document when to use each mode

## 14. Compose Files - Core Services (One Service Per File)
- [ ] 14.1 Create compose/services/php-fpm.yml:
  - PHP-FPM container
  - Generic PHP image (no Oro assumptions)
  - Health check
  - Resource limits
- [ ] 14.2 Create compose/services/php-cli.yml:
  - PHP CLI container
  - Same image as FPM
  - No command (sleep infinity or one-off runs)
- [ ] 14.3 Create compose/services/nginx.yml:
  - Generic nginx configuration
  - No framework-specific rules
  - Traefik labels
  - Depends on php-fpm
- [ ] 14.4 Create compose/services/database-pgsql.yml:
  - PostgreSQL 15+ container
  - Volume for data persistence
  - Health check
  - Environment variables from DC_DATABASE_*
- [ ] 14.5 Create compose/services/database-mysql.yml:
  - MySQL/MariaDB container
  - Volume for data persistence
  - Health check
  - Alternative to PostgreSQL
- [ ] 14.6 Create compose/services/redis.yml:
  - Redis 6.2+ container
  - Single database (plugins configure multiple)
  - Health check
- [ ] 14.7 Create compose/services/rabbitmq.yml:
  - RabbitMQ 3.9+ with management
  - Generic MQ configuration
  - Health check
  - Management UI port
- [ ] 14.8 Create compose/services/mail.yml:
  - MailHog for email testing
  - SMTP and web UI ports
  - Traefik labels
- [ ] 14.9 Create compose/services/ssh.yml:
  - SSH server container
  - Same image as CLI
  - Host key persistence
  - Port 2222

## 15. Test Individual Services
- [ ] 15.1 Test each service starts independently
- [ ] 15.2 Test service health checks
- [ ] 15.3 Test service dependencies
- [ ] 15.4 Test service networking
- [ ] 15.5 Test volume mounts for each service
- [ ] 15.6 Test resource limits
- [ ] 15.7 Document service-specific configuration

## 16. Oro Plugin Compose Files
- [ ] 16.1 Create plugins/oro/compose/search.yml:
  - Elasticsearch 8.10.3
  - Oro-specific configuration
  - Volume for data
  - Health check
- [ ] 16.2 Create plugins/oro/compose/websocket.yml:
  - WebSocket server container
  - Oro websocket command
  - Traefik routing for /ws
- [ ] 16.3 Create plugins/oro/compose/consumer.yml:
  - Message consumer container
  - oro:message-queue:consume command
  - Auto-restart
- [ ] 16.4 Test Oro plugin services load correctly
- [ ] 16.5 Test Oro services DON'T load without plugin
- [ ] 16.6 Verify core works without Oro services

## 17. Docker Image Strategy
- [ ] 14.1 Design new image naming: ghcr.io/digitalspacestdio/dcx-*
- [ ] 14.2 Create framework-agnostic base images:
  - dcx-php:8.3-node20
  - dcx-php:8.4-node22
- [ ] 14.3 Create framework-specific images:
  - dcx-oro:8.3-node20 (Oro-optimized)
  - dcx-magento:8.3-node20 (future)
- [ ] 14.4 Set up automated image builds in CI/CD
- [ ] 14.5 Test image building and caching
- [ ] 14.6 Publish images to GitHub Container Registry

## 15. Documentation Updates
- [ ] 15.1 Update README.md for framework-agnostic usage
- [ ] 15.2 Create migration guide from orodc to dcx
- [ ] 15.3 Document module architecture
- [ ] 15.4 Create framework adapter development guide
- [ ] 15.5 Update AGENTS.md with new conventions
- [ ] 15.6 Add architecture diagrams
- [ ] 15.7 Create troubleshooting guide for modular architecture

## 18. Homebrew Formula Creation
- [ ] 16.1 Create NEW Formula/dcx.rb (separate from old orodc)
- [ ] 16.2 Configure dcx binary installation
- [ ] 16.3 Set up formula dependencies (docker, docker-compose, etc.)
- [ ] 16.4 Add module directory installation (dcx.d/, dcx-frameworks.d/)
- [ ] 16.5 Create comprehensive formula test suite
- [ ] 16.6 Test formula installation from scratch
- [ ] 16.7 Document formula in README
- [ ] 16.8 Keep old docker-compose-oroplatform formula for legacy support

## 19. CI/CD Updates
- [ ] 17.1 Update GitHub Actions workflows
- [ ] 17.2 Add modular testing strategy
- [ ] 17.3 Test framework adapter matrix
- [ ] 17.4 Add integration tests for all modules
- [ ] 17.5 Update Goss tests for new architecture
- [ ] 17.6 Verify CI/CD passes for all scenarios

## 20. Integration Testing
- [ ] 18.1 Test with Oro Platform 6.1 projects
- [ ] 18.2 Test with OroCommerce 6.1 projects
- [ ] 18.3 Test with OroCRM projects
- [ ] 18.4 Test with generic Symfony 6.x/7.x projects
- [ ] 18.5 Test with Laravel projects (generic adapter)
- [ ] 18.6 Test all infrastructure services (database, Redis, Elasticsearch, RabbitMQ)
- [ ] 18.7 Test all special commands (install, purge, tests, ssh, etc.)
- [ ] 18.8 Performance testing vs legacy OroDC
- [ ] 18.9 Load testing with multiple projects

## 21. Performance Optimization
- [ ] 19.1 Profile module loading time
- [ ] 19.2 Optimize critical path functions
- [ ] 19.3 Implement lazy loading if needed
- [ ] 19.4 Benchmark against monolithic version
- [ ] 19.5 Ensure <100ms overhead target met

## 22. Release Preparation (v1.0.0)
- [ ] 20.1 Complete all documentation rewrite
- [ ] 20.2 Create comprehensive CHANGELOG.md
- [ ] 20.3 Write migration guide from OroDC v0.x to WebStack v1.0
- [ ] 20.4 Create release notes highlighting new features
- [ ] 20.5 Set up GitHub Releases page
- [ ] 20.6 Prepare announcement blog post/documentation
- [ ] 20.7 Beta testing period (2-4 weeks)
- [ ] 20.8 Address beta feedback
- [ ] 20.9 Tag v1.0.0 release
- [ ] 20.10 Publish Homebrew formula
- [ ] 20.11 Announce release to community

## 23. Post-v1.0 Roadmap
- [ ] 21.1 Magento 2 framework adapter (v1.1)
- [ ] 21.2 Laravel framework adapter (v1.2)
- [ ] 21.3 WordPress framework adapter (v1.3)
- [ ] 21.4 Drupal framework adapter (v1.4)
- [ ] 21.5 Plugin development guide and SDK
- [ ] 21.6 Plugin marketplace/registry (v2.0)
- [ ] 21.7 Web UI for project management (v2.0)
- [ ] 21.8 Cloud deployment integrations (v2.1)

