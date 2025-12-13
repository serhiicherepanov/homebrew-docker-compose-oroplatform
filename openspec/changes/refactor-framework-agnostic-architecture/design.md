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

### Decision 1: Module Organization - Minimalist Core + Plugins

**Structure:**
```
bin/
├── webstack                              # Minimal entry point (~100 lines)
├── webstack.d/                           # Core modules (no framework logic)
│   ├── 00-core.sh                        # Docker Compose orchestration
│   ├── 10-utils.sh                       # Logging, binary resolution
│   ├── 20-env.sh                         # Core environment only
│   ├── 30-cli.sh                         # Generic CLI commands
│   ├── 40-database.sh                    # Database import/export
│   └── 50-plugin-loader.sh               # Plugin discovery and loading
│
├── plugins/                              # Framework plugins (opt-in)
│   ├── oro/
│   │   ├── plugin.sh                     # Oro commands and detection
│   │   ├── env.sh                        # Oro-specific environment
│   │   └── compose/                      # Oro-specific services
│   │       ├── websocket.yml
│   │       ├── consumer.yml
│   │       └── search.yml
│   │
│   └── magento/
│       ├── plugin.sh
│       ├── env.sh
│       └── compose/
│
└── compose/                              # Core services only
    ├── services/                         # One file per service
    │   ├── nginx.yml                     # Webserver
    │   ├── php-cli.yml                   # PHP CLI container
    │   ├── php-fpm.yml                   # PHP FPM container
    │   ├── database-pgsql.yml            # PostgreSQL
    │   ├── database-mysql.yml            # MySQL
    │   ├── redis.yml                     # Cache
    │   ├── rabbitmq.yml                  # Message broker
    │   ├── mail.yml                      # MailHog (dev only)
    │   └── ssh.yml                       # SSH access
    │
    ├── modes/                            # Sync modes
    │   ├── default.yml
    │   ├── mutagen.yml
    │   └── ssh.yml
    │
    └── base.yml                          # Base networks and volumes
```

**Rationale:**
- **Radical simplicity**: Core has ZERO framework knowledge
- **One service = one file**: Easy to understand, test, enable/disable
- **Plugin isolation**: Framework code completely separate
- **Clear boundaries**: Can't accidentally mix core and framework logic
- **Easy testing**: Test each service independently
- **User choice**: Install only plugins you need

**Alternatives Considered:**
1. **Monolithic compose files**: Hard to maintain, can't cherry-pick services
2. **Framework logic in core**: Defeats the purpose, creates coupling
3. **Plugin discovery from ~/.webstack/**: Too complex, prefer explicit structure

### Decision 2: Compose File Loading Strategy

**One Service = One File:**
```bash
# Core services (always available)
COMPOSE_FILES=(
  "compose/base.yml"                      # Networks, volumes
  "compose/modes/${DC_MODE:-default}.yml" # Sync mode
  "compose/services/php-fpm.yml"          # PHP FPM
  "compose/services/php-cli.yml"          # PHP CLI
  "compose/services/nginx.yml"            # Webserver
  "compose/services/redis.yml"            # Cache
  "compose/services/rabbitmq.yml"         # Message broker
  "compose/services/mail.yml"             # MailHog
  "compose/services/ssh.yml"              # SSH access
)

# Database selection (user chooses)
if [[ "${DC_DATABASE_SCHEMA}" == "pgsql" ]]; then
  COMPOSE_FILES+=("compose/services/database-pgsql.yml")
elif [[ "${DC_DATABASE_SCHEMA}" == "mysql" ]]; then
  COMPOSE_FILES+=("compose/services/database-mysql.yml")
fi

# Plugin services (loaded by plugins)
if [[ -n "${WEBSTACK_PLUGIN}" ]]; then
  plugin_compose_dir="plugins/${WEBSTACK_PLUGIN}/compose"
  if [[ -d "${plugin_compose_dir}" ]]; then
    for compose_file in "${plugin_compose_dir}"/*.yml; do
      COMPOSE_FILES+=("${compose_file}")
    done
  fi
fi

# Build final docker compose command
DOCKER_COMPOSE_CMD="docker compose"
for file in "${COMPOSE_FILES[@]}"; do
  DOCKER_COMPOSE_CMD+=" -f ${file}"
done
```

**Benefits:**
- ✅ Each service is independently testable
- ✅ Can enable/disable services by commenting one line
- ✅ Clear service dependencies in separate files
- ✅ Easy to override specific services
- ✅ Plugin services don't pollute core

**Rationale:**
- Microservices philosophy applied to compose files
- Explicit is better than implicit
- Easy to understand what's running
- No magic - just file inclusion

**Alternatives Considered:**
1. **Monolithic compose.yml**: Hard to maintain, everything coupled
2. **Include directives**: Docker Compose doesn't support well
3. **Template generation**: Too complex, harder to debug

### Decision 3: Plugin System and Framework Detection

**Plugin Structure:**
```bash
# Plugin layout
plugins/oro/
├── plugin.sh                 # Plugin entry point
├── env.sh                    # Framework-specific environment
├── compose/                  # Framework-specific services
│   ├── websocket.yml
│   ├── consumer.yml
│   └── search.yml
└── commands/                 # Framework-specific commands
    ├── install.sh
    ├── platformupdate.sh
    └── updateurl.sh

# Plugin interface (plugin.sh must implement)
plugin_detect() {
  # Return 0 if this framework is detected, 1 otherwise
  grep -q '"oro/' composer.json 2>/dev/null
}

plugin_name() {
  echo "oro"
}

plugin_init() {
  # Load environment and commands
  source "${PLUGIN_DIR}/env.sh"
  
  # Register commands
  register_command "install" "${PLUGIN_DIR}/commands/install.sh"
  register_command "platformupdate" "${PLUGIN_DIR}/commands/platformupdate.sh"
  register_command "updateurl" "${PLUGIN_DIR}/commands/updateurl.sh"
}

plugin_compose_files() {
  # Return list of additional compose files
  echo "${PLUGIN_DIR}/compose/websocket.yml"
  echo "${PLUGIN_DIR}/compose/consumer.yml"
  echo "${PLUGIN_DIR}/compose/search.yml"
}
```

**Plugin Discovery:**
```bash
# Auto-detect and load plugins
for plugin_dir in plugins/*/; do
  plugin_file="${plugin_dir}/plugin.sh"
  if [[ -f "${plugin_file}" ]]; then
    source "${plugin_file}"
    if plugin_detect; then
      WEBSTACK_PLUGIN=$(plugin_name)
      plugin_init
      break
    fi
  fi
done

# Or explicit plugin selection
export WEBSTACK_PLUGIN=oro  # Force Oro plugin
```

**Rationale:**
- Plugins are completely self-contained
- Core never imports framework code
- Plugins register their commands dynamically
- Easy to add new plugins without core changes
- Plugins can be versioned independently

**Alternatives Considered:**
1. **Framework code in core**: Defeats modularity purpose
2. **Separate binaries per framework**: Installation complexity
3. **Configuration file registration**: Less flexible than code-based

### Decision 4: Environment Variable Separation (Core vs Plugin)

**Strategy: Minimal core variables + plugin-managed framework variables**

**Core variables (managed by webstack core):**
```bash
# Project configuration
DC_PROJECT_NAME=${DC_PROJECT_NAME:-$(basename $(pwd))}
DC_MODE=${DC_MODE:-default}  # default, mutagen, ssh

# PHP/Node versions
DC_PHP_VERSION=${DC_PHP_VERSION:-8.4}
DC_NODE_VERSION=${DC_NODE_VERSION:-22}
DC_COMPOSER_VERSION=${DC_COMPOSER_VERSION:-2}

# Database (generic)
DC_DATABASE_SCHEMA=${DC_DATABASE_SCHEMA:-pgsql}  # pgsql, mysql
DC_DATABASE_HOST=${DC_DATABASE_HOST:-database}
DC_DATABASE_PORT=${DC_DATABASE_PORT:-5432}
DC_DATABASE_USER=${DC_DATABASE_USER:-app}
DC_DATABASE_PASSWORD=${DC_DATABASE_PASSWORD:-app}
DC_DATABASE_DBNAME=${DC_DATABASE_DBNAME:-app}

# Infrastructure services (generic)
DC_REDIS_HOST=${DC_REDIS_HOST:-redis}
DC_MQ_HOST=${DC_MQ_HOST:-mq}
DC_MQ_USER=${DC_MQ_USER:-app}
DC_MQ_PASSWORD=${DC_MQ_PASSWORD:-app}

# Paths
DC_CONFIG_DIR=${DC_CONFIG_DIR:-$HOME/.webstack/${DC_PROJECT_NAME}}
DC_APP_DIR=${DC_APP_DIR:-/var/www}

# Ports
DC_PORT_PREFIX=${DC_PORT_PREFIX:-302}
```

**Plugin variables (managed by plugin env.sh):**
```bash
# Example: plugins/oro/env.sh

# Oro-specific environment (derived from core variables)
export ORO_DB_URL="pgsql://${DC_DATABASE_USER}:${DC_DATABASE_PASSWORD}@${DC_DATABASE_HOST}:${DC_DATABASE_PORT}/${DC_DATABASE_DBNAME}"
export ORO_DB_DSN="${ORO_DB_URL}"

# Oro-specific Redis DSNs
export ORO_SESSION_DSN="redis://${DC_REDIS_HOST}:6379/0"
export ORO_REDIS_CACHE_DSN="redis://${DC_REDIS_HOST}:6379/1"
export ORO_REDIS_DOCTRINE_DSN="redis://${DC_REDIS_HOST}:6379/2"

# Oro-specific search (if plugin includes search service)
export ORO_SEARCH_ENGINE_DSN="elastic-search://search:9200?prefix=oro_search"
export ORO_WEBSITE_SEARCH_ENGINE_DSN="elastic-search://search:9200?prefix=oro_website_search"

# Oro-specific MQ
export ORO_MQ_DSN="amqp://${DC_MQ_USER}:${DC_MQ_PASSWORD}@${DC_MQ_HOST}:5672/%2f"

# Oro-specific WebSocket
export ORO_WEBSOCKET_SERVER_DSN="//0.0.0.0:8080"
export ORO_WEBSOCKET_FRONTEND_DSN="//${DC_PROJECT_NAME}.docker.local/ws"

# Oro secret
export ORO_SECRET=${ORO_SECRET:-ThisTokenIsNotSoSecretChangeIt}
```

**Clear Separation:**
- ✅ Core knows NOTHING about Oro, Magento, or any framework
- ✅ Core provides generic infrastructure (database, redis, mq)
- ✅ Plugins transform core variables into framework-specific format
- ✅ Plugins can add their own framework-specific variables
- ✅ No variable pollution in core environment

**Rationale:**
- Radical separation of concerns
- Core is truly framework-agnostic
- Plugins fully control their environment
- Easy to test core without frameworks
- Framework variables don't leak into core

**Alternatives Considered:**
1. **All variables in core**: Defeats modularity, creates coupling
2. **No core variables**: Too generic, every plugin duplicates basics
3. **Framework detection in core**: Core shouldn't know about frameworks

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

