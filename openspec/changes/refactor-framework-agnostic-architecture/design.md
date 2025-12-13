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
- **Framework Agnostic**: Clean separation of infrastructure and framework-specific code
- **Clean Design**: No legacy compatibility code, modern architecture from scratch
- **Plugin System**: Enable framework-specific extensions through plugins
- **Reusable Infrastructure**: Share database, webserver, cache modules across frameworks
- **Production Ready**: Build v1.0 with solid foundations for future growth

### Non-Goals
- **Not rewriting in another language**: Keep bash for simplicity and portability
- **Not changing Docker Compose approach**: Continue using Docker Compose as orchestration
- **Not removing Oro support**: Oro remains supported through dedicated adapter
- **Not maintaining backward compatibility**: This is a clean break redesign (v0.x → v1.0)
- **Not adding all frameworks immediately**: Start with Oro + Generic, add others incrementally

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

**Strategy: Clean framework-agnostic naming from day one**

**New clean naming scheme:**
```bash
# Project configuration
DC_PROJECT_NAME=${DC_PROJECT_NAME:-$(basename $(pwd))}
DC_FRAMEWORK=${DC_FRAMEWORK:-auto}

# PHP/Node versions
DC_PHP_VERSION=${DC_PHP_VERSION:-8.4}
DC_NODE_VERSION=${DC_NODE_VERSION:-22}
DC_COMPOSER_VERSION=${DC_COMPOSER_VERSION:-2}

# Database configuration
DC_DATABASE_HOST=${DC_DATABASE_HOST:-database}
DC_DATABASE_PORT=${DC_DATABASE_PORT:-5432}
DC_DATABASE_USER=${DC_DATABASE_USER:-app}
DC_DATABASE_PASSWORD=${DC_DATABASE_PASSWORD:-app}
DC_DATABASE_DBNAME=${DC_DATABASE_DBNAME:-app}
DC_DATABASE_SCHEMA=${DC_DATABASE_SCHEMA:-pgsql}  # pgsql, mysql

# Infrastructure services
DC_REDIS_HOST=${DC_REDIS_HOST:-redis}
DC_SEARCH_HOST=${DC_SEARCH_HOST:-search}
DC_MQ_HOST=${DC_MQ_HOST:-mq}

# Configuration paths
DC_CONFIG_DIR=${DC_CONFIG_DIR:-$HOME/.webstack/${DC_PROJECT_NAME}}
DC_APP_DIR=${DC_APP_DIR:-/var/www}
```

**Rationale:**
- Clean, self-explanatory names
- No legacy prefixes (ORO)
- Framework-agnostic from start
- Consistent naming pattern
- Easy to remember and document

**Alternatives Considered:**
1. **Keep DC_ORO_* naming**: Misleading for non-Oro projects, legacy baggage
2. **Remove DC_ prefix entirely**: Conflicts with other Docker tools
3. **Use WEBSTACK_ prefix**: Too long, DC_ is established pattern

### Decision 5: Command Naming

**Strategy: Single clean command name**
- **Command**: `webstack` (framework-agnostic, universal)
- **No aliases**: Clean break from old naming
- **Framework detection**: Automatic based on project context

```bash
# webstack automatically detects and adapts to framework
cd ~/orocommerce && webstack up    # Auto-detects Oro, uses Oro adapter
cd ~/magento && webstack up        # Auto-detects Magento, uses Magento adapter  
cd ~/symfony && webstack up        # Auto-detects Symfony, uses generic adapter

# Explicit framework override when needed
DC_FRAMEWORK=oro webstack up       # Force Oro adapter
DC_FRAMEWORK=magento webstack up   # Force Magento adapter
```

**Rationale:**
- Clean, professional naming
- Framework-agnostic brand identity
- Auto-detection provides excellent UX
- No legacy confusion
- One command to learn

**Alternatives Considered:**
1. **Keep orodc name**: Misleading and limits adoption for non-Oro users
2. **Require framework in command**: Too verbose (webstack-oro, webstack-magento)
3. **Multiple binaries**: Installation complexity, user confusion
4. **Generic name like "devstack"**: Already taken by OpenStack project

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

## Release Plan

### v1.0.0: Clean Break Release

**Release Strategy:**
- Brand new tool: WebStack v1.0
- Old tool continues as OroDC v0.x (maintenance mode)
- Both available via different Homebrew formulas

**Development Approach:**
1. Build complete v1.0 in new branch
2. Comprehensive testing with all supported frameworks
3. Complete documentation rewrite
4. Beta testing period with early adopters
5. Official v1.0 release

**Homebrew Formula Strategy:**
```bash
# Old version (maintenance mode, Oro-only)
brew install digitalspacestdio/tap/docker-compose-oroplatform

# New version (v1.0, all frameworks)
brew install digitalspacestdio/tap/webstack
```

**User Migration Path:**
- **No forced upgrades**: Users choose when to migrate
- **Migration guide**: Step-by-step documentation
- **Side-by-side installation**: Both tools can coexist
- **Different config directories**: 
  - Old: `~/.orodc/`
  - New: `~/.webstack/`

**Legacy OroDC Maintenance:**
- Critical bug fixes only
- Security updates
- No new features
- Documented end-of-life timeline (e.g., 12 months)

**Benefits of Clean Break:**
- ✅ No legacy code bloat
- ✅ Optimal architecture without constraints
- ✅ Clear versioning (v0.x = old, v1.x = new)
- ✅ Better performance
- ✅ Easier maintenance
- ✅ Modern codebase

## Open Questions

1. **Module Loading Performance**: Should we implement lazy loading for unused modules?
   - **Proposal**: Profile first, optimize only if needed (likely not necessary for bash)

2. **Plugin Distribution**: How should third-party framework adapters be distributed?
   - **Proposal**: Start with official adapters only, add plugin marketplace in v2.0

3. **Configuration File**: Should we introduce a .webstackrc or .webstack.yml configuration file?
   - **Proposal**: Environment variables sufficient for v1.0, consider config file for v1.1

4. **Multi-Framework Projects**: How to handle projects using multiple frameworks (e.g., Symfony + Laravel)?
   - **Proposal**: Explicit DC_FRAMEWORK variable required, document common patterns

5. **Docker Image Strategy**: Should we rebrand images from "orodc-*" to "webstack-*"?
   - **Proposal**: 
     - New images: `ghcr.io/digitalspacestdio/webstack-php:8.4-node22`
     - Framework-specific: `ghcr.io/digitalspacestdio/webstack-oro:8.4-node22`
     - Old images remain for legacy OroDC v0.x

6. **Testing Strategy**: How to test all framework adapters without slowing CI/CD?
   - **Proposal**: Matrix strategy with parallel jobs per framework adapter

7. **Project Naming**: Final decision on tool name?
   - **Options**: webstack, phpstack, devstack (taken), dockerstack
   - **Proposal**: "WebStack" - professional, clear, available

8. **Framework Adapter API Stability**: Should we freeze adapter API in v1.0?
   - **Proposal**: Mark adapter API as "stable" in v1.0, use semantic versioning for changes

