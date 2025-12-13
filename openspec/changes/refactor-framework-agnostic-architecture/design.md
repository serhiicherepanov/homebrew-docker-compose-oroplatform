# Design: Framework-Agnostic Architecture

## Context

OroDC was originally built as a CLI tool specifically for Oro Platform products. The tool has proven valuable for Docker-based development, but its tight coupling to Oro limits reusability. The monolithic architecture makes it difficult to:

**New Tool Name: dcx (Docker Compose eXtended)**
- **3 characters** - super fast to type
- **DC** = Docker Compose - clear purpose
- **X** = eXtended/eXtensible - universal applicability
- **Environment agnostic** - dev, staging, production
- **Language agnostic** - PHP, Ruby, Node.js, Python, any stack
- **No framework assumptions** - works with or without plugins

The monolithic OroDC architecture makes it difficult to:

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
- **Evaluate Technology Stack**: Bash vs Go vs Hybrid - choose optimal solution

### Non-Goals
- **Not changing Docker Compose approach**: Continue using Docker Compose as orchestration
- **Not removing Oro support**: Oro remains supported through dedicated plugin
- **Not maintaining backward compatibility**: This is a clean break redesign (v0.x → v1.0)
- **Not adding all frameworks immediately**: Start with Oro + Generic, add others incrementally
- **Not over-engineering**: Choose simplest solution that meets requirements

## Critical Decision: Bash vs Go vs Hybrid

### Current State: Bash (2386 lines)
OroDC is currently implemented in Bash, which has served well but shows limitations:

**Bash Pros:**
- ✅ No compilation needed - instant execution
- ✅ No dependencies - works everywhere Docker is installed
- ✅ Perfect for Docker Compose orchestration (just shell out to `docker compose`)
- ✅ Easy to debug - just read the script
- ✅ Contributors know bash (lower barrier to entry)
- ✅ Homebrew installation is trivial (just copy script)

**Bash Cons:**
- ❌ Hard to test (no proper unit testing framework)
- ❌ No type safety - runtime errors only
- ❌ Complex argument parsing (2386 lines is unwieldy)
- ❌ No proper module system (sourcing files isn't great)
- ❌ Error handling is verbose (`set -e` is blunt instrument)
- ❌ Performance (bash is slow, though Docker is slower so doesn't matter much)

### Option 1: Stay with Bash (Modularized)

**Implementation:**
```bash
dcx/
├── bin/dcx                    # ~100 lines entry point
└── dcx.d/
    ├── 00-core.sh            # ~200 lines
    ├── 10-utils.sh           # ~150 lines
    ├── 20-env.sh             # ~200 lines
    ├── 30-cli.sh             # ~200 lines
    ├── 40-database.sh        # ~200 lines
    └── 50-plugin-loader.sh   # ~150 lines
```

**Pros:**
- ✅ Simplest migration from current code
- ✅ No new dependencies
- ✅ Instant startup (no compilation)
- ✅ Easy to contribute (everyone knows bash)
- ✅ Perfect for Docker orchestration

**Cons:**
- ❌ Still hard to test properly
- ❌ No type safety
- ❌ Complex logic remains complex
- ❌ Plugin system will be hacky (sourcing files)

**Verdict:** Good for v1.0, but will hit limits as project grows.

---

### Option 2: Rewrite in Go

**Implementation:**
```go
dcx/
├── cmd/dcx/
│   └── main.go                # CLI entry point
├── pkg/
│   ├── core/                  # Docker Compose orchestration
│   ├── compose/               # Compose file management
│   ├── database/              # Database import/export
│   ├── plugin/                # Plugin system
│   └── config/                # Configuration management
├── plugins/
│   └── oro/                   # Oro plugin (could be Go or bash)
└── compose/                   # Docker Compose YAML files
```

**Pros:**
- ✅ **Proper testing** - Go has excellent testing framework
- ✅ **Type safety** - catch errors at compile time
- ✅ **Better performance** - though Docker is bottleneck anyway
- ✅ **Proper module system** - clean imports
- ✅ **Better error handling** - explicit error returns
- ✅ **Plugin system** - Go plugins or gRPC for plugins
- ✅ **Cross-compilation** - single binary for all platforms
- ✅ **Structured logging** - proper logging framework
- ✅ **Future features** - easier to add rolling updates, scaling, etc.

**Cons:**
- ❌ **Higher barrier to entry** - fewer contributors know Go
- ❌ **Compilation required** - adds build step
- ❌ **Binary size** - ~10MB vs 50KB bash script
- ❌ **More complex Homebrew formula** - need to compile
- ❌ **Longer startup time** - ~10ms vs instant (negligible)
- ❌ **Complete rewrite** - can't reuse bash code

**Verdict:** Better long-term architecture, but higher upfront cost.

---

### Option 3: Hybrid (Go Core + Bash/Any Plugins)

**Implementation:**
```
dcx/
├── cmd/dcx/main.go            # Go CLI
├── pkg/
│   ├── core/                  # Go core
│   ├── compose/               # Go compose management
│   └── plugin/                # Plugin interface (exec plugins)
├── plugins/
│   └── oro/
│       ├── plugin.sh          # Bash plugin (or Go binary)
│       └── commands/          # Individual commands
└── compose/                   # Docker Compose YAML
```

**How it works:**
1. **Go core** handles:
   - CLI parsing
   - Docker Compose orchestration
   - Configuration management
   - Plugin discovery and execution
   - Database import/export core logic

2. **Plugins** can be:
   - Bash scripts (easy to write)
   - Go binaries (compiled)
   - Python scripts
   - Any executable

3. **Plugin interface:**
   ```go
   // Go calls plugin via exec
   cmd := exec.Command("plugins/oro/plugin.sh", "detect")
   output, _ := cmd.Output()
   
   // Plugin implements standard interface
   // detect, init, commands, compose-files
   ```

**Pros:**
- ✅ **Best of both worlds** - Go core strength, plugin flexibility
- ✅ **Easy plugin development** - use bash, Go, or anything
- ✅ **Testable core** - Go testing for core logic
- ✅ **Gradual migration** - can reuse some bash code in plugins
- ✅ **Performance where it matters** - Go for heavy lifting
- ✅ **Flexibility** - plugins in any language

**Cons:**
- ❌ **More complex** - two languages to maintain in core team
- ❌ **IPC overhead** - exec calls for plugins (minimal)
- ❌ **Two build systems** - Go compilation + bash distribution

**Verdict:** Most flexible, but adds complexity.

---

## Recommendation Analysis

### For v1.0: **Go Core + Plugin Interface**

**Rationale:**

1. **Testing is Critical**
   - Database import/export needs unit tests
   - Compose file merging needs tests
   - Configuration parsing needs tests
   - Bash makes this very hard

2. **Future Features Require Structure**
   - Rolling updates
   - Container scaling
   - Health monitoring
   - Metrics collection
   - These are much easier in Go

3. **Plugin System Benefits**
   - Oro plugin can start as bash
   - Community can write plugins in any language
   - Core remains clean and tested

4. **Production Usage**
   - Type safety prevents bugs
   - Better error messages
   - Structured logging
   - Easier to debug production issues

5. **Performance** (minor but nice)
   - Config parsing faster
   - File operations faster
   - Startup time negligible difference

### Migration Path

**Phase 1: Core in Go**
```
dcx (Go binary)
├── CLI parsing (cobra)
├── Docker Compose exec
├── Config management
├── Plugin discovery
└── Basic commands
```

**Phase 2: Oro Plugin (Bash initially)**
```
plugins/oro/
├── plugin.sh          # Bash implementation
├── commands/
│   ├── install.sh
│   ├── platformupdate.sh
│   └── updateurl.sh
└── compose/
    ├── websocket.yml
    └── consumer.yml
```

**Phase 3: Optimize plugins as needed**
- Critical plugins can be rewritten in Go
- Most can stay in bash
- Community decides based on needs

### Technology Stack (Go Implementation)

**Core Libraries:**
```go
github.com/spf13/cobra              // CLI framework
github.com/spf13/viper              // Configuration
github.com/docker/compose/v2        // Compose parsing (maybe)
gopkg.in/yaml.v3                    // YAML handling
github.com/joho/godotenv            // .env files
```

**Project Structure:**
```go
dcx/
├── cmd/dcx/main.go
├── pkg/
│   ├── compose/       // Compose file management
│   │   ├── loader.go
│   │   ├── merger.go
│   │   └── writer.go
│   ├── database/      // Database operations
│   │   ├── import.go
│   │   └── export.go
│   ├── plugin/        // Plugin system
│   │   ├── loader.go
│   │   ├── executor.go
│   │   └── interface.go
│   └── docker/        // Docker/Compose exec
│       ├── compose.go
│       └── container.go
├── internal/
│   └── config/        // Internal config
└── plugins/
```

---

## Alternative: Stay Bash with Testing Framework

**If we want to stay bash**, use:
```bash
# Testing with bats (Bash Automated Testing System)
brew install bats-core

# Example test
@test "database import detects PostgreSQL" {
  export DC_DATABASE_SCHEMA="pgsql"
  run dcx importdb test.sql
  [ "$status" -eq 0 ]
  [[ "$output" =~ "PostgreSQL" ]]
}
```

**Pros:**
- ✅ Can test bash code
- ✅ Stay in bash ecosystem

**Cons:**
- ❌ Still no type safety
- ❌ Tests slower than Go
- ❌ Still complex for large codebase

---

## Final Recommendation: **Go Core**

**Why Go wins:**
1. ✅ **Testing is mandatory** - v1.0 needs solid test coverage
2. ✅ **Production ready** - type safety prevents entire class of bugs
3. ✅ **Future proof** - rolling updates, scaling, monitoring all easier
4. ✅ **Better error handling** - explicit errors, stack traces
5. ✅ **Plugin flexibility** - exec interface supports any language
6. ✅ **Performance** - bonus, not main reason
7. ✅ **Single binary** - easier distribution than multi-file bash

**Trade-offs accepted:**
- ❌ Higher initial development cost (worth it for v1.0)
- ❌ Compilation required (Homebrew handles this)
- ❌ Fewer bash contributors (but attract Go community)

**Implementation timeline:**
- Weeks 1-2: Core architecture in Go
- Weeks 3-4: Docker Compose integration
- Weeks 5-6: Plugin system
- Weeks 7-8: Oro plugin (bash initially)
- Week 9+: Testing, refinement

## Core Architecture (Language Agnostic)

### Core Responsibilities

**1. Compose File Management**
```
Input: Multiple YAML files
Process:
  - Load base.yml (networks, volumes)
  - Load mode/*.yml (based on DC_MODE)
  - Load services/*.yml (enabled services)
  - Load plugin compose files
  - Merge all files
Output: docker compose -f file1.yml -f file2.yml ...
```

**2. Configuration Management**
```
Sources (priority order):
  1. Environment variables (DC_*)
  2. .env.dcx file
  3. ~/.dcx/PROJECT/config
  4. Defaults

Validation:
  - Required variables set
  - Valid values (e.g., DC_DATABASE_SCHEMA in [pgsql, mysql])
  - Path existence
  - Port conflicts
```

**3. Plugin Discovery & Loading**
```
Discovery:
  1. Scan plugins/ directory
  2. For each plugin: call detect()
  3. If detected, call init()
  4. Register commands
  5. Collect compose files

Interface:
  - detect() → bool
  - init() → void
  - commands() → []Command
  - compose_files() → []string
  - env_vars() → map[string]string
```

**4. Docker Compose Execution**
```
Responsibilities:
  - Build docker compose command with all -f flags
  - Execute docker compose with proper flags
  - Stream output to user
  - Capture exit code
  - Handle interrupts (Ctrl+C)

Must NOT:
  - Parse Docker Compose YAML (docker compose does this)
  - Implement Docker logic (delegate to docker compose)
```

**5. Database Operations**
```
Import:
  - Detect file format (.sql, .sql.gz)
  - Decompress if needed
  - Detect database schema (pgsql/mysql)
  - Execute in database container
  - Show progress

Export:
  - Detect database schema
  - Choose appropriate dump command
  - Compress output
  - Save with timestamp
  - Clean problematic SQL (DEFINER, etc.)
```

**6. Container Execution**
```
Command types:
  - docker compose run (one-off)
  - docker compose exec (running container)
  - SSH into container
  - Execute PHP commands
  - Execute database CLIs

Must handle:
  - TTY allocation
  - Stdin/stdout/stderr
  - Environment variables
  - Working directory
  - User/permissions
```

---

### Core Modules (Detailed)

**Module: Compose Loader**
```
Responsibilities:
  - Discover compose files
  - Validate YAML syntax
  - Build file list in correct order
  - Handle missing files gracefully

Interface:
  LoadBase() → ComposeFile
  LoadMode(mode string) → ComposeFile
  LoadServices(enabled []string) → []ComposeFile
  LoadPluginFiles(plugin Plugin) → []ComposeFile
  BuildCommand() → []string
```

**Module: Configuration**
```
Responsibilities:
  - Load environment variables
  - Parse .env.dcx
  - Validate configuration
  - Provide defaults
  - Merge configurations

Interface:
  Load() → Config
  Validate() → []Error
  Get(key string) → string
  Set(key, value string)
  Save() → error
```

**Module: Plugin Manager**
```
Responsibilities:
  - Discover plugins
  - Load plugin metadata
  - Execute plugin interface methods
  - Register plugin commands
  - Isolate plugin failures

Interface:
  Discover() → []Plugin
  Load(name string) → Plugin
  Execute(plugin Plugin, method string) → Result
  RegisterCommand(plugin Plugin, cmd Command)
```

**Module: Docker Client**
```
Responsibilities:
  - Execute docker compose commands
  - Execute docker commands
  - Stream output
  - Handle errors
  - Check daemon availability

Interface:
  ComposeUp(services []string) → error
  ComposeDown() → error
  ComposeExec(service, cmd string) → error
  ComposeRun(service, cmd string) → error
  IsRunning(service string) → bool
```

**Module: Database Manager**
```
Responsibilities:
  - Import database dumps
  - Export database dumps
  - Detect database type
  - Clean problematic SQL
  - Show progress

Interface:
  Import(file string, schema string) → error
  Export(schema string) → (file string, error)
  DetectSchema() → string
  CleanSQL(sql string, schema string) → string
```

---

### Error Handling Strategy

**Principle: Fail Fast, Fail Clear**

```
Error Types:
  1. Configuration errors (missing DC_DATABASE_SCHEMA)
     → Show error, suggest fix, exit code 1
  
  2. Dependency errors (docker not found)
     → Show error, show install instructions, exit code 1
  
  3. Runtime errors (database import failed)
     → Show error, show logs, exit code from docker
  
  4. User errors (unknown command)
     → Show help, suggest similar commands, exit code 2

Error Messages:
  - Clear description
  - Context (what was being done)
  - Suggestion (how to fix)
  - Exit code (scriptable)
```

**Example (Go):**
```go
func ImportDatabase(file string) error {
    if !fileExists(file) {
        return fmt.Errorf(
            "database import failed: file not found: %s\n"+
            "  Suggestion: check file path or use absolute path\n"+
            "  Example: dcx importdb /path/to/dump.sql",
            file,
        )
    }
    
    schema := detectSchema()
    if schema == "" {
        return fmt.Errorf(
            "database import failed: cannot detect database schema\n"+
            "  Suggestion: set DC_DATABASE_SCHEMA environment variable\n"+
            "  Example: export DC_DATABASE_SCHEMA=pgsql",
        )
    }
    
    // ... import logic
}
```

---

### Testing Strategy

**Unit Tests (Fast, Isolated)**
```
Test coverage target: >80%

What to test:
  - Configuration parsing
  - Compose file loading
  - Plugin discovery
  - Error handling
  - Database SQL cleaning

Mock:
  - File system
  - Docker client
  - Plugin execution
```

**Integration Tests (Slower, Real Docker)**
```
Test scenarios:
  - Full installation flow
  - Database import/export
  - Service startup
  - Plugin loading
  - Command execution

Use:
  - Real Docker
  - Test compose files
  - Temporary directories
```

**E2E Tests (Slowest, Complete)**
```
Test scenarios:
  - Install Oro
  - Run Oro tests
  - Import production dump
  - Export database
  - Plugin system

CI/CD:
  - GitHub Actions
  - Test matrix (PHP 8.3, 8.4)
  - Test matrix (MySQL, PostgreSQL)
```

---

### Performance Considerations

**Startup Time:**
```
Target: <100ms from command to action

Optimization:
  - Lazy load modules
  - Cache plugin discovery
  - Parallel file operations
  - No unnecessary validation
```

**Docker Compose:**
```
Bottleneck: Docker, not dcx

Don't optimize:
  - Compose file merging (docker compose does this)
  - Container startup (Docker's job)
  - Network creation (Docker's job)

Do optimize:
  - File discovery (cache paths)
  - Configuration loading (parse once)
  - Plugin discovery (cache results)
```

**Database Operations:**
```
Import/Export can be slow (multi-GB dumps)

Optimization:
  - Stream processing (don't load entire file)
  - Compression (gzip)
  - Progress indicators
  - Parallel operations where safe
```

---

## Decisions

### Decision 1: Module Organization - Minimalist Core + Plugins

**Structure:**
```
bin/
├── dcx                              # Minimal entry point (~100 lines)
├── dcx.d/                           # Core modules (no framework logic)
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
3. **Plugin discovery from ~/.dcx/**: Too complex, prefer explicit structure

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
if [[ -n "${DCX_PLUGIN}" ]]; then
  plugin_compose_dir="plugins/${DCX_PLUGIN}/compose"
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
      DCX_PLUGIN=$(plugin_name)
      plugin_init
      break
    fi
  fi
done

# Or explicit plugin selection
export DCX_PLUGIN=oro  # Force Oro plugin
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

**Core variables (managed by dcx core):**
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
DC_CONFIG_DIR=${DC_CONFIG_DIR:-$HOME/.dcx/${DC_PROJECT_NAME}}
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
- **Command**: `dcx` (framework-agnostic, universal)
- **No aliases**: Clean break from old naming
- **Framework detection**: Automatic based on project context

```bash
# dcx automatically detects and adapts to framework
cd ~/orocommerce && dcx up    # Auto-detects Oro, uses Oro adapter
cd ~/magento && dcx up        # Auto-detects Magento, uses Magento adapter  
cd ~/symfony && dcx up        # Auto-detects Symfony, uses generic adapter

# Explicit framework override when needed
DC_FRAMEWORK=oro dcx up       # Force Oro adapter
DC_FRAMEWORK=magento dcx up   # Force Magento adapter
```

**Rationale:**
- Clean, professional naming
- Framework-agnostic brand identity
- Auto-detection provides excellent UX
- No legacy confusion
- One command to learn

**Alternatives Considered:**
1. **Keep orodc name**: Misleading and limits adoption for non-Oro users
2. **Require framework in command**: Too verbose (dcx-oro, dcx-magento)
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
- Brand new tool: **dcx** v1.0 (Docker Compose eXtended)
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
orodc up -d

# New version (v1.0, universal, 3 chars!)
brew install digitalspacestdio/tap/dcx
dcx up -d
```

**User Migration Path:**
- **No forced upgrades**: Users choose when to migrate
- **Migration guide**: Step-by-step documentation
- **Side-by-side installation**: Both tools can coexist
- **Different config directories**: 
  - Old: `~/.orodc/`
  - New: `~/.dcx/`

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

3. **Configuration File**: Should we introduce a .dcxrc or .dcx.yml configuration file?
   - **Proposal**: Environment variables sufficient for v1.0, consider config file for v1.1

4. **Multi-Framework Projects**: How to handle projects using multiple frameworks (e.g., Symfony + Laravel)?
   - **Proposal**: Explicit DC_FRAMEWORK variable required, document common patterns

5. **Docker Image Strategy**: Should we rebrand images from "orodc-*" to "dcx-*"?
   - **Proposal**: 
     - New images: `ghcr.io/digitalspacestdio/dcx-php:8.4-node22`
     - Framework-specific: `ghcr.io/digitalspacestdio/dcx-oro:8.4-node22`
     - Old images remain for legacy OroDC v0.x

6. **Testing Strategy**: How to test all framework adapters without slowing CI/CD?
   - **Proposal**: Matrix strategy with parallel jobs per framework adapter

7. **Project Naming**: ✅ **DECIDED: dcx**
   - **DC** = Docker Compose (clear identity)
   - **X** = eXtended/eXtensible (universal)
   - **3 chars** = minimal typing
   - **Not dev-specific** = can be used in production
   - **Not language-specific** = works with any stack
   - **Available** = free on GitHub, Homebrew, npm, etc.

8. **Framework Adapter API Stability**: Should we freeze adapter API in v1.0?
   - **Proposal**: Mark adapter API as "stable" in v1.0, use semantic versioning for changes

