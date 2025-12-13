# Design: Framework-Agnostic Architecture

## Context

OroDC was originally built as a CLI tool specifically for Oro Platform products. The tool has proven valuable for Docker-based PHP development, but its tight coupling to Oro limits reusability. The monolithic architecture makes it difficult to:

- Add support for other PHP frameworks (Magento, Laravel, Symfony)
- Maintain and test individual components
- Enable community contributions through plugins
- Reuse infrastructure modules (database, webserver, cache) across frameworks

### Current Architecture Analysis

**Monolithic Script Structure (bin/orodc - 2386 lines):**

1. **Utility Functions (lines 1-270)** - ~270 lines
   - Message formatting (msg_info, msg_error, msg_ok, etc.)
   - Binary resolution (resolve_bin)
   - Version and help command handlers

2. **Environment Initialization (lines 270-800)** - ~530 lines
   - Argument parsing (left_flags, right_flags, left_options, right_options)
   - Docker Compose command detection
   - Environment variable management (DC_ORO_*)
   - Dependency resolution (docker, brew, rsync, jq)
   - Homebrew prefix detection and compose file syncing

3. **Compose File Management (lines 800-1200)** - ~400 lines
   - Certificate setup
   - Profile caching (save_profiles, load_cached_profiles)
   - Environment file loading (load_env_safe)
   - DSN URI parsing (parse_dsn_uri)
   - Traefik rule building (build_traefik_rule)
   - Docker network management

4. **PHP/Node Version Detection (lines 1200-1500)** - ~300 lines
   - PHP version auto-detection from composer.json
   - Node version compatibility mapping
   - Version environment variable initialization

5. **Container Execution (lines 1500-1700)** - ~200 lines
   - build_docker_compose_run_cmd
   - is_container_running
   - execute_in_container
   - External PHP file mounting

6. **Oro-Specific Commands (lines 1700-2100)** - ~400 lines
   - cache:* commands (clear, warmup)
   - platformupdate / updateplatform
   - importdb / exportdb / databaseimport / databaseexport
   - updateurl / seturl
   - composer install integration

7. **Docker Compose Command Routing (lines 2100-2386)** - ~286 lines
   - php / cli / ssh / bash command handling
   - mysql / psql / database-cli commands
   - tests command with merged test compose files
   - Docker Compose passthrough for native commands

**Compose File Structure:**
```
compose/
├── docker-compose.yml                    # Main base services (Oro-specific env vars)
├── docker-compose-default.yml            # Default sync mode
├── docker-compose-mysql.yml              # MySQL database
├── docker-compose-pgsql.yml              # PostgreSQL database
├── docker-compose-proxy.yml              # Traefik proxy
├── docker-compose-test.yml               # Test environment
├── docker-compose-dummy.yml              # Placeholder
└── docker/
    ├── php-node-symfony/                 # PHP/Node base images (Oro-optimized)
    ├── project-php-node-symfony/         # Project-specific PHP containers
    ├── nginx/                            # Nginx configuration (Oro-optimized)
    ├── pgsql/                            # PostgreSQL configuration
    ├── mysql/                            # MySQL configuration
    ├── mongo/                            # MongoDB for XHProf
    └── proxy/                            # Traefik proxy configuration
```

## Goals / Non-Goals

### Goals
- **Modular Architecture**: Split monolithic script into logical, testable modules
- **Framework Agnostic**: Extract Oro-specific logic into replaceable adapters
- **Backward Compatible**: Existing Oro installations continue working without changes
- **Plugin System**: Enable framework-specific extensions through plugins
- **Reusable Infrastructure**: Share database, webserver, cache modules across frameworks
- **Easy Migration**: Clear upgrade path from `orodc` to framework-agnostic tool

### Non-Goals
- **Not rewriting in another language**: Keep bash for simplicity and portability
- **Not changing Docker Compose approach**: Continue using Docker Compose as orchestration
- **Not removing Oro support**: Oro remains first-class citizen, just modular
- **Not breaking existing workflows**: All current commands continue working
- **Not adding new frameworks in this change**: Focus on architecture, add Magento later

## Decisions

### Decision 1: Module Organization

**Structure:**
```
bin/
├── webstack                              # Main entry point (replaces orodc)
├── webstack.d/
│   ├── 00-core.sh                        # Core Docker Compose functions
│   ├── 10-utils.sh                       # Utility functions (logging, binary resolution)
│   ├── 20-env.sh                         # Environment initialization
│   ├── 30-pipeline.sh                    # Command routing and execution
│   ├── 40-compose.sh                     # Compose file management
│   ├── 50-infrastructure.sh              # Infrastructure module interface
│   └── 60-framework.sh                   # Framework adapter loader
└── webstack-frameworks.d/
    ├── oro.sh                            # Oro Platform adapter
    ├── magento.sh                        # Magento adapter (future)
    └── symfony.sh                        # Symfony adapter (future)
```

**Rationale:**
- Numbered prefixes ensure correct loading order
- Clear separation of concerns by module
- Framework adapters separate from core system
- Easy to add new frameworks without modifying core

**Alternatives Considered:**
1. **Python rewrite**: More powerful but loses bash portability and increases dependencies
2. **Single file with functions**: Doesn't solve maintenance or testing issues
3. **Git submodules**: Adds complexity for users and deployment

### Decision 2: Framework Detection and Loading

**Mechanism:**
```bash
# Auto-detect framework from project files
detect_framework() {
  if [[ -f "composer.json" ]]; then
    if grep -q '"oro/' composer.json 2>/dev/null; then
      echo "oro"
      return 0
    elif grep -q '"magento/' composer.json 2>/dev/null; then
      echo "magento"
      return 0
    fi
  fi
  
  # Fallback to environment variable or default
  echo "${DC_FRAMEWORK:-generic}"
}

# Load framework adapter dynamically
load_framework_adapter() {
  local framework="$1"
  local adapter_file="${WEBSTACK_FRAMEWORKS_DIR}/${framework}.sh"
  
  if [[ -f "$adapter_file" ]]; then
    source "$adapter_file"
  else
    msg_warning "Framework adapter '$framework' not found, using generic mode"
    source "${WEBSTACK_FRAMEWORKS_DIR}/generic.sh"
  fi
}
```

**Rationale:**
- Automatic detection provides good UX
- Explicit configuration allows overrides
- Graceful fallback to generic mode if adapter missing
- Framework adapters can override core functions

**Alternatives Considered:**
1. **Configuration file required**: More explicit but worse UX
2. **Command-line flag required**: Too verbose for daily use
3. **Docker image inspection**: Slower and less reliable

### Decision 3: Infrastructure Module Interface

**Standard Interface:**
```bash
# Each infrastructure module implements these functions:
module_database_setup()      # Initialize database environment
module_database_cli()        # Database CLI access
module_database_import()     # Import database dump
module_database_export()     # Export database dump
module_database_healthcheck() # Check database health

# Similar for other modules:
# - module_webserver_*
# - module_cache_*
# - module_search_*
# - module_mq_*
```

**Rationale:**
- Consistent interface across all infrastructure modules
- Framework adapters can override specific functions
- Easy to test individual modules in isolation
- Clear contract for adding new infrastructure types

**Alternatives Considered:**
1. **Object-oriented approach**: Requires advanced bash or language change
2. **Configuration-only**: Not flexible enough for complex logic
3. **Docker Compose only**: Doesn't handle CLI commands and workflows

### Decision 4: Environment Variable Naming

**Strategy: Dual naming with migration period**

**Phase 1: Support both old and new names**
```bash
# New generic names (preferred)
DC_PROJECT_NAME=${DC_PROJECT_NAME:-}
DC_PHP_VERSION=${DC_PHP_VERSION:-}
DC_DATABASE_HOST=${DC_DATABASE_HOST:-}

# Old Oro names (backward compatibility)
DC_ORO_NAME=${DC_ORO_NAME:-}
DC_ORO_PHP_VERSION=${DC_ORO_PHP_VERSION:-}
DC_ORO_DATABASE_HOST=${DC_ORO_DATABASE_HOST:-}

# Resolution: old names take precedence if set
DC_PROJECT_NAME=${DC_ORO_NAME:-${DC_PROJECT_NAME:-$(basename $(pwd))}}
DC_PHP_VERSION=${DC_ORO_PHP_VERSION:-${DC_PHP_VERSION:-8.4}}
```

**Phase 2: Deprecation warnings**
```bash
if [[ -n "${DC_ORO_NAME:-}" ]]; then
  msg_warning "DC_ORO_NAME is deprecated, use DC_PROJECT_NAME instead"
fi
```

**Phase 3: Remove old names (future major version)**

**Rationale:**
- Zero breakage for existing users
- Clear migration path
- Warnings educate users about new naming
- Can remove old names in next major version

**Alternatives Considered:**
1. **Break everything at once**: Unacceptable for production users
2. **Keep both forever**: Creates confusion and maintenance burden
3. **Automatic migration script**: Complex and error-prone

### Decision 5: Command Naming and Aliases

**Strategy:**
- New command: `webstack` (framework-agnostic)
- Old command: `orodc` (symlink to webstack, maintained for compatibility)
- Framework-specific behavior determined by adapter, not command name

```bash
# webstack determines behavior from project context
cd ~/orocommerce && webstack up    # Uses Oro adapter
cd ~/magento && webstack up        # Uses Magento adapter
cd ~/symfony && webstack up        # Uses Symfony adapter

# orodc forces Oro adapter (backward compatibility)
cd ~/magento && orodc up           # Still uses Oro adapter (legacy behavior)
```

**Rationale:**
- Clear branding for framework-agnostic tool
- Perfect backward compatibility
- No confusion about which command to use
- Future: deprecate orodc command

**Alternatives Considered:**
1. **Keep orodc name**: Misleading for non-Oro projects
2. **Require framework in command**: Too verbose (webstack-oro, webstack-magento)
3. **Multiple binaries**: Installation and maintenance complexity

## Risks / Trade-offs

### Risk 1: Performance Overhead from Module Loading
- **Mitigation**: Profile module loading time, optimize critical paths
- **Acceptable**: <100ms overhead for module loading is acceptable for developer tooling

### Risk 2: Breaking Custom User Scripts
- **Mitigation**: Support both old and new variable names during migration period
- **Documentation**: Clear migration guide with examples
- **Testing**: Comprehensive integration tests for backward compatibility

### Risk 3: Increased Complexity for Contributors
- **Mitigation**: Detailed contributor documentation
- **Benefits**: Modular architecture makes it easier to contribute to specific areas
- **Trade-off**: Short-term learning curve for long-term maintainability

### Risk 4: Plugin System Security
- **Mitigation**: Official adapters shipped with tool, third-party plugins require explicit opt-in
- **Documentation**: Security best practices for plugin development
- **Future**: Plugin signing and verification system

## Migration Plan

### Phase 1: Internal Refactoring (0.9.0)
- Split orodc into modules under bin/orodc.d/
- Maintain orodc command name
- All existing functionality works identically
- Add comprehensive test coverage

### Phase 2: Introduce webstack Command (1.0.0)
- Add bin/webstack as new entry point
- orodc becomes symlink to webstack
- Both commands work identically for Oro projects
- Documentation shows webstack as primary command

### Phase 3: Framework Detection (1.1.0)
- Implement automatic framework detection
- Add framework adapter loading system
- Extract Oro-specific code into oro.sh adapter
- Add basic Magento adapter support

### Phase 4: Deprecation Warnings (2.0.0)
- orodc command shows deprecation warning
- Old environment variables (DC_ORO_*) show warnings
- Documentation updated to use new names exclusively
- Migration guide published

### Phase 5: Full Migration (3.0.0)
- Remove orodc command
- Remove support for DC_ORO_* variables
- Framework adapters fully mature
- Plugin system documentation complete

### Rollback Strategy
- Each phase is non-breaking
- Users can stay on older versions indefinitely
- Symlink-based approach allows easy rollback
- Old variable names supported for at least 2 major versions

## Open Questions

1. **Module Loading Performance**: Should we implement lazy loading for unused modules?
   - **Proposal**: Profile first, optimize only if needed

2. **Plugin Distribution**: How should third-party framework adapters be distributed?
   - **Proposal**: Start with official adapters only, add plugin system in v2.0

3. **Configuration File**: Should we introduce a .webstackrc or similar configuration file?
   - **Proposal**: Environment variables sufficient for now, add config file if needed

4. **Multi-Framework Projects**: How to handle projects using multiple frameworks?
   - **Proposal**: Explicit DC_FRAMEWORK variable required for ambiguous cases

5. **Docker Image Naming**: Should we maintain oro-specific images or create generic ones?
   - **Proposal**: Keep existing images for backward compatibility, add generic variants

6. **Testing Strategy**: How to test all framework adapters without slowing CI/CD?
   - **Proposal**: Parallel testing, matrix strategy across framework adapters

