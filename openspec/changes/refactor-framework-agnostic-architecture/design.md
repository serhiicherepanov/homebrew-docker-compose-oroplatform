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

## Practical Reality Check

### Go Disadvantages (Real World)

**Compilation Complexity:**
```bash
# Current (Bash):
brew install dcx       # Instant - just copy script
dcx up                 # Works immediately

# With Go:
brew install dcx       # Must compile from source OR
                       # Maintain bottles for every platform:
                       # - macOS x86_64
                       # - macOS arm64 (M1/M2/M3)
                       # - Linux x86_64
                       # - Linux arm64
```

**Homebrew Formula Complexity:**
```ruby
# Bash (simple):
class Dcx < Formula
  desc "Docker Compose eXtended"
  url "https://github.com/.../dcx-1.0.0.tar.gz"
  
  def install
    bin.install "dcx"
    (share/"dcx").install Dir["compose", "plugins"]
  end
end

# Go (complex):
class Dcx < Formula
  desc "Docker Compose eXtended"
  url "https://github.com/.../dcx-1.0.0.tar.gz"
  
  depends_on "go" => :build  # Build dependency
  
  def install
    # Must compile for this platform
    system "go", "build", "-o", "dcx"
    bin.install "dcx"
    
    # Still need compose files
    (share/"dcx").install Dir["compose", "plugins"]
  end
  
  # Need bottles for fast installation
  bottle do
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "..."
    sha256 cellar: :any_skip_relocation, arm64_ventura: "..."
    sha256 cellar: :any_skip_relocation, sonoma: "..."
    sha256 cellar: :any_skip_relocation, ventura: "..."
    sha256 cellar: :any_skip_relocation, x86_64_linux: "..."
  end
end
```

**Distribution:**
- Bash: Works everywhere Docker works (100% of target platforms)
- Go: Need to compile for each platform, or users compile on install (slow)
- Node.js: Requires Node runtime (extra dependency)

**Development Speed:**
```bash
# Bash development cycle:
1. Edit dcx.d/database.sh
2. dcx importdb test.sql
   # Works immediately

# Go development cycle:
1. Edit pkg/database/import.go
2. go build -o dcx
3. ./dcx importdb test.sql
   # Extra compilation step every time
```

**Contributor Barrier:**
- Everyone doing Docker knows bash
- Not everyone knows Go
- Node.js is known but runtime dependency sucks

---

## Revised Recommendation: **Modularized Bash with Engineering Rigor**

### Why Bash Actually Wins for This Use Case

**1. Perfect for Docker Orchestration**
```bash
# This is literally our main job:
docker compose -f file1.yml -f file2.yml up -d

# Bash is PERFECT for this - just exec
exec docker compose "${compose_files[@]}" up -d
```

**2. Zero Installation Friction**
```bash
brew install dcx    # Instant, works on all platforms
dcx up             # Just works, no compilation
```

**3. Universal Compatibility**
- ✅ macOS (Intel and Apple Silicon) - same script
- ✅ Linux (x86_64 and ARM) - same script
- ✅ No cross-compilation needed
- ✅ No bottles to maintain

**4. Rapid Development**
- Edit script → test immediately
- No build step
- Faster iteration

**5. Lower Contributor Barrier**
- Everyone knows bash
- Easy to contribute
- No language to learn

---

### Making Modular Bash Production-Ready

**Use bats for Testing:**
```bash
# Install
brew install bats-core

# test/database-import.bats
@test "detects PostgreSQL schema" {
  export DC_DATABASE_SCHEMA="pgsql"
  run dcx importdb test.sql
  [ "$status" -eq 0 ]
  [[ "$output" =~ "PostgreSQL" ]]
}

@test "handles compressed files" {
  run dcx importdb test.sql.gz
  [ "$status" -eq 0 ]
}

# Run tests
bats test/
```

**Use shellcheck for Static Analysis:**
```bash
# Install
brew install shellcheck

# CI/CD validation
shellcheck bin/dcx bin/dcx.d/*.sh plugins/**/*.sh

# Catches common bugs:
# - Undefined variables
# - Syntax errors
# - Quoting issues
# - Logic errors
```

**Use strict mode:**
```bash
#!/bin/bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures
IFS=$'\n\t'        # Sane IFS

# Modern bash practices
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

**Modular Architecture:**
```bash
dcx/
├── bin/dcx                      # ~100 lines entry point
└── dcx.d/
    ├── 00-core.sh               # ~200 lines
    ├── 10-utils.sh              # ~150 lines
    ├── 20-env.sh                # ~200 lines
    ├── 30-cli.sh                # ~200 lines
    ├── 40-database.sh           # ~200 lines
    └── 50-plugin-loader.sh      # ~150 lines

Total: ~1200 lines (vs 2386 monolithic)
Each module: testable, focused, understandable
```

**Modern Bash Features:**
```bash
# Arrays (not just strings)
compose_files=(
    "compose/base.yml"
    "compose/modes/${DC_MODE}.yml"
)

# Associative arrays (hash maps)
declare -A service_ports=(
    [nginx]=80
    [database]=5432
    [redis]=6379
)

# Functions with return values
get_database_schema() {
    local schema="${DC_DATABASE_SCHEMA:-}"
    if [[ -z "$schema" ]]; then
        # Auto-detect
        schema=$(detect_from_compose)
    fi
    echo "$schema"
}

# Proper error handling
import_database() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        error "File not found: $file"
        return 1
    fi
    
    # ... import logic
}
```

---

## Final Recommendation: **Bash + Good Engineering**

### Implementation Strategy

**Phase 1: Modular Bash Core (Weeks 1-3)**
```bash
dcx (bash)
├── Core modules
├── Compose management
├── Config handling
├── Plugin loader
└── Database ops
```

**Phase 2: Testing Infrastructure (Week 4)**
```bash
- bats tests (unit-style)
- shellcheck in CI/CD
- Integration tests with Docker
- Coverage reporting
```

**Phase 3: Plugins (Weeks 5-7)**
```bash
plugins/oro/
├── plugin.sh          # Bash
├── commands/          # Bash scripts
└── compose/           # YAML files
```

**Phase 4: Documentation & Release (Week 8)**
```bash
- Complete docs
- Migration guide
- CI/CD polish
- v1.0 release
```

---

### When to Consider Go (Future)

**If/when we need:**
1. **Performance critical operations** (current: Docker is bottleneck, not bash)
2. **Complex algorithms** (current: just orchestration)
3. **Type-heavy APIs** (current: just CLI and env vars)
4. **gRPC/protobuf** (current: not needed)
5. **Heavy concurrent operations** (current: Docker handles this)

**Reality for v1.0:**
- We're orchestrating Docker Compose (bash excels at this)
- We're parsing YAML (docker compose does this)
- We're executing commands (bash excels at this)
- We're managing files (bash excels at this)

---

### Testing Strategy (Bash)

**Unit-Style Tests with bats:**
```bash
# test/core/compose-loader.bats
@test "loads base compose file" {
  run load_compose_files
  [[ "$output" =~ "compose/base.yml" ]]
}

@test "loads mode-specific file" {
  DC_MODE=mutagen run load_compose_files
  [[ "$output" =~ "compose/modes/mutagen.yml" ]]
}

# test/database/import.bats
@test "detects gzip files" {
  run detect_compression "test.sql.gz"
  [ "$status" -eq 0 ]
  [ "$output" = "gzip" ]
}
```

**Integration Tests:**
```bash
# test/integration/full-install.bats
@test "full Oro installation" {
  run dcx install
  [ "$status" -eq 0 ]
  
  # Check services are running
  run dcx ps
  [[ "$output" =~ "database" ]]
  [[ "$output" =~ "nginx" ]]
}
```

**CI/CD with GitHub Actions:**
```yaml
name: Test
on: [push, pull_request]

jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, macos-14]  # Intel + ARM
    
    runs-on: ${{ matrix.os }}
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Install dependencies
        run: |
          brew install bats-core shellcheck
      
      - name: Shellcheck
        run: shellcheck bin/dcx bin/dcx.d/*.sh
      
      - name: Unit tests
        run: bats test/
      
      - name: Integration tests
        run: bats test/integration/
```

---

## Conclusion: Bash is the Right Choice

**For dcx v1.0, Bash wins because:**

1. ✅ **Zero friction installation** - works everywhere instantly
2. ✅ **No cross-compilation** - same script on all platforms
3. ✅ **Perfect for the job** - orchestrating Docker Compose
4. ✅ **Fast development** - no compilation step
5. ✅ **Lower barrier** - everyone knows bash
6. ✅ **Testable** - bats provides proper testing
7. ✅ **Maintainable** - shellcheck catches bugs
8. ✅ **Proven** - current OroDC works well

**We accept these limitations:**
- No type safety (mitigated by shellcheck + tests)
- No fancy features (we don't need them)
- Bash quirks (mitigated by strict mode + modern practices)

**Future:** If we truly need Go features, we can rewrite core while keeping plugins in bash. But for v1.0, overengineering with Go adds complexity without solving real problems.

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

**6. Smart Argument Parsing & Command Routing**
```
Critical Feature: Intelligent argument parsing

Problem:
  dcx --profile=test run --rm cli php bin/console cache:clear --env=prod
  
  Which flags go where?
  - --profile=test → docker compose (left)
  - run --rm → docker compose command
  - cli → service name
  - php bin/console cache:clear --env=prod → command in container (right)

Solution: Parse into buckets
  left_flags: [--profile=test]
  left_options: []
  command: run
  args: [--rm, cli, php, bin/console, cache:clear]
  right_flags: [--env=prod]
  right_options: []

Build:
  docker compose --profile=test run --rm cli php bin/console cache:clear --env=prod
```

**7. Transparent Command Redirection**
```
Current OroDC feature (must preserve):
  
  # orodc without args = PHP binary
  ln -s /path/to/orodc /usr/local/bin/php
  php --version              # Works!
  php bin/console cache:clear # Works!

How it works:
  1. Detect if called as different name (php, node, etc.)
  2. OR detect PHP-specific flags (-v, --version, -r)
  3. OR detect .php file as first arg
  4. Redirect to appropriate container + binary

Must be configurable per project:
  - Oro/Symfony: php binary (default)
  - Node.js projects: node binary
  - Make-based: make
  - Python: python
  - Ruby: ruby
```

**8. Container Execution**
```
Command types:
  - docker compose run (one-off)
  - docker compose exec (running container)
  - SSH into container
  - Execute commands via transparent redirection

Must handle:
  - TTY allocation
  - Stdin/stdout/stderr
  - Environment variables
  - Working directory
  - User/permissions
  - Argument preservation (quoting, spacing)
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

### Decision 0: Smart Argument Parsing (Critical Feature)

**Current OroDC Magic - Must Preserve:**

OroDC has intelligent argument parsing that makes it incredibly convenient to use. This is NOT optional - it's core to the user experience.

**Example 1: Transparent PHP execution**
```bash
# Current behavior (must keep):
orodc --version              # → php --version in container
orodc -r "phpinfo();"        # → php -r "phpinfo();" in container
orodc bin/console cache:clear  # → php bin/console cache:clear in container

# Can even symlink:
ln -s /path/to/orodc /usr/local/bin/php
php --version                # Works as PHP!
```

**Example 2: Complex Docker Compose + container arguments**
```bash
# User types:
dcx --profile=test run --rm cli php bin/console cache:clear --env=prod

# System must understand:
docker compose \
  --profile=test \          # ← Docker Compose flag (left)
  run --rm \                # ← Docker Compose command + flag
  cli \                     # ← Service name
  php bin/console cache:clear --env=prod  # ← Container command (right)

# Parsing result:
left_flags: [--profile=test]
command: run
right_flags: [--rm]
service: cli
container_cmd: [php, bin/console, cache:clear, --env=prod]
```

**Implementation Strategy (Bash):**

```bash
# Function: parse_arguments
parse_arguments() {
    local -a left_flags=()
    local -a left_options=()
    local -a right_flags=()
    local -a right_options=()
    local -a args=()
    local command=""
    local in_command=false
    
    # State machine: before command → command → after command
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --*=*)  # Long option with value (--profile=test)
                if [[ "$in_command" == false ]]; then
                    left_flags+=("$1")
                else
                    right_flags+=("$1")
                fi
                shift
                ;;
            --*)    # Long option
                if [[ "$in_command" == false ]]; then
                    left_flags+=("$1")
                    # Check if next arg is value
                    if [[ -n "${2:-}" ]] && [[ ! "$2" =~ ^- ]]; then
                        left_options+=("$1" "$2")
                        shift
                    fi
                else
                    right_flags+=("$1")
                fi
                shift
                ;;
            -*)     # Short option
                if [[ "$in_command" == false ]]; then
                    left_flags+=("$1")
                else
                    right_flags+=("$1")
                fi
                shift
                ;;
            *)      # Non-option argument
                if [[ -z "$command" ]] && is_compose_command "$1"; then
                    command="$1"
                    in_command=true
                else
                    args+=("$1")
                fi
                shift
                ;;
        esac
    done
    
    # Export for use in other functions
    export PARSED_LEFT_FLAGS="${left_flags[@]}"
    export PARSED_COMMAND="$command"
    export PARSED_ARGS="${args[@]}"
    export PARSED_RIGHT_FLAGS="${right_flags[@]}"
}

# Function: is_compose_command
is_compose_command() {
    local cmd="$1"
    case "$cmd" in
        up|down|start|stop|restart|ps|logs|exec|run|build|pull|push|config|version|ls)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}
```

**Transparent Redirection (Bash):**

```bash
# Function: detect_transparent_redirect
detect_transparent_redirect() {
    local binary_name
    binary_name=$(basename "$0")
    
    # Method 1: Called as different binary (symlink)
    if [[ "$binary_name" != "dcx" ]]; then
        case "$binary_name" in
            php)   REDIRECT_TO="php" ;;
            node)  REDIRECT_TO="node" ;;
            python) REDIRECT_TO="python" ;;
            ruby)  REDIRECT_TO="ruby" ;;
        esac
        return 0
    fi
    
    # Method 2: Detect by first argument
    local first_arg="${1:-}"
    
    # PHP flags
    if [[ "$first_arg" =~ ^(-v|--version|-r|-l|-m|-i|--ini)$ ]]; then
        REDIRECT_TO="${DC_DEFAULT_BINARY:-php}"
        return 0
    fi
    
    # PHP file
    if [[ "$first_arg" =~ \.php$ ]]; then
        REDIRECT_TO="${DC_DEFAULT_BINARY:-php}"
        return 0
    fi
    
    # Symfony console
    if [[ "$first_arg" == "bin/console" ]] || [[ "$first_arg" =~ ^(cache:|oro:|doctrine:) ]]; then
        REDIRECT_TO="${DC_DEFAULT_BINARY:-php}"
        return 0
    fi
    
    # Node files
    if [[ "$first_arg" =~ \.(js|mjs|cjs)$ ]]; then
        REDIRECT_TO="${DC_DEFAULT_BINARY:-node}"
        return 0
    fi
    
    # Python files
    if [[ "$first_arg" =~ \.py$ ]]; then
        REDIRECT_TO="${DC_DEFAULT_BINARY:-python}"
        return 0
    fi
    
    return 1
}

# Function: execute_with_redirect
execute_with_redirect() {
    local redirect_binary="$1"
    shift  # Remove binary from args
    
    if [[ "$DEBUG" ]]; then
        echo "[DEBUG] Transparent redirect: $redirect_binary $*" >&2
    fi
    
    # Check if container is running
    if is_container_running "cli"; then
        # Use exec (fast)
        exec docker compose exec cli "$redirect_binary" "$@"
    else
        # Use run (slower but works)
        exec docker compose run --rm cli "$redirect_binary" "$@"
    fi
}
```

**Configuration per Project:**

```bash
# .env.dcx
DC_DEFAULT_BINARY=php        # Default for PHP/Symfony projects
# DC_DEFAULT_BINARY=node     # For Node.js projects
# DC_DEFAULT_BINARY=python   # For Python projects
# DC_DEFAULT_BINARY=none     # Disable transparent redirect

# Plugin can set default
# plugins/oro/env.sh:
export DC_DEFAULT_BINARY="${DC_DEFAULT_BINARY:-php}"
```

**Why This is Critical:**

1. **User Experience**: `dcx bin/console cache:clear` is much better than `dcx run cli php bin/console cache:clear`
2. **Drop-in Replacement**: Can symlink as `php` for seamless integration
3. **Framework Flexibility**: Works with PHP, Node.js, Python, Ruby, anything
4. **Power User Features**: Complex Docker Compose flags just work

---

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

**CRITICAL: Fixed Plugin Structure Convention**

All plugins MUST follow this exact structure for consistency and maintainability:

```bash
plugins/oro/
├── README.md                    # Plugin overview and usage
├── plugin.sh                    # Plugin entry point (detection + registration)
├── commands/                    # Framework-specific commands (actions)
│   ├── install/
│   │   ├── README.md           # When called, available variables, examples
│   │   └── run.sh              # Installation script
│   ├── platformupdate/
│   │   ├── README.md           # Documentation for this command
│   │   └── run.sh              # Platform update script
│   ├── updateurl/
│   │   ├── README.md           # Documentation for this command
│   │   └── run.sh              # URL update script
│   └── tests/
│       ├── README.md           # Test environment documentation
│       └── run.sh              # Test setup/execution
├── services/                    # Additional Docker Compose services
│   ├── elasticsearch.yml       # Search service
│   ├── websocket.yml           # WebSocket service
│   └── consumer.yml            # Message queue consumer
└── env/
    └── defaults.sh             # Framework-specific environment variables
```

**Key Conventions:**
1. **One directory per command** - `commands/{command-name}/`
2. **Fixed script name** - Always `run.sh` inside command directory
3. **Required README.md** - Every command MUST document:
   - When it's called (trigger conditions)
   - Available environment variables
   - Expected behavior
   - Usage examples
4. **Environment variable communication** - All data passed via `DC_*` variables
5. **Self-contained services** - Additional Docker services in `services/`

**Plugin Interface (plugin.sh must implement):**
```bash
# plugins/oro/plugin.sh

plugin_detect() {
  # Return 0 if this framework is detected, 1 otherwise
  [[ -f "composer.json" ]] && grep -q '"oro/' composer.json 2>/dev/null
}

plugin_name() {
  echo "oro"
}

plugin_init() {
  # Load framework-specific environment variables
  source "${PLUGIN_DIR}/env/defaults.sh"
  
  # Auto-register all commands from commands/ directory
  # Each command directory contains run.sh and README.md
  for cmd_dir in "${PLUGIN_DIR}/commands"/*/; do
    cmd_name=$(basename "${cmd_dir}")
    cmd_script="${cmd_dir}/run.sh"
    
    if [[ -f "${cmd_script}" ]]; then
      register_command "${cmd_name}" "${cmd_script}"
    fi
  done
}

plugin_compose_files() {
  # Return list of additional compose files from services/
  for yml_file in "${PLUGIN_DIR}/services"/*.yml; do
    [[ -f "${yml_file}" ]] && echo "${yml_file}"
  done
}
```

**Command Script Template (commands/{name}/run.sh):**
```bash
#!/usr/bin/env bash
# commands/install/run.sh

set -euo pipefail

# Hybrid JSON communication protocol
# Context: JSON via $DCX_CONTEXT environment variable (shared, immutable)
# Input: JSON via stdin (command-specific data)
# Output: JSON via stdout
# Logs: stderr (for debugging)

# Helper: Log to stderr
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Helper: Log JSON to stderr for debugging
log_json() {
  local label="$1"
  local json="$2"
  echo "[DEBUG] ${label}:" >&2
  echo "${json}" | jq -C . >&2
}

# Helper: Return success result
success_result() {
  local message="$1"
  local data="${2:-{}}"
  jq -n \
    --arg msg "$message" \
    --argjson data "$data" \
    '{status: "success", message: $msg, data: $data}'
}

# Helper: Return error result
error_result() {
  local message="$1"
  local exit_code="${2:-1}"
  jq -n \
    --arg msg "$message" \
    --argjson code "$exit_code" \
    '{status: "error", message: $msg, exit_code: $code}'
}

main() {
  # 1. Read shared context from environment (optional)
  local context="${DCX_CONTEXT:-{}}"
  log_json "Context" "$context"
  
  # Extract context info
  local dcx_version config_dir
  dcx_version=$(echo "$context" | jq -r '.dcx.version // "unknown"')
  config_dir=$(echo "$context" | jq -r '.paths.config_dir // "~/.dcx"')
  
  log "DCX version: ${dcx_version}, Config dir: ${config_dir}"
  
  # 2. Read command-specific input from stdin
  local input
  input=$(cat)
  
  # Validate input exists
  if [[ -z "${input}" || "${input}" == "{}" ]]; then
    error_result "No input provided via stdin" 1
    exit 1
  fi
  
  log_json "Input received" "$input"
  
  # Validate JSON structure
  if ! validate_json "$input" "${SCHEMA_DIR}/oro/install-input.schema.json"; then
    error_result "Invalid input JSON" 1
    exit 1
  fi
  
  # 3. Extract command-specific data using jq
  local project database admin
  project=$(echo "$input" | jq -r '.project.name')
  database=$(echo "$input" | jq -r '.database.host')
  admin=$(echo "$input" | jq -r '.oro.admin.user')
  
  log "Installing Oro Platform for project: ${project}"
  
  # 4. Execute installation
  if docker compose exec -T cli composer install --no-interaction; then
    log "Composer install completed"
    
    if docker compose exec -T cli bin/console oro:install \
      --user-name="${admin}" \
      --application-url="http://${project}.docker.local"; then
      
      log "Oro installation completed successfully"
      
      # Return success with structured data
      success_result "Installation completed" '{
        "admin_user": "'"${admin}"'",
        "database_created": true,
        "services_started": ["fpm", "cli", "nginx"]
      }'
    else
      error_result "Oro installation failed" 1
      exit 1
    fi
  else
    error_result "Composer install failed" 1
    exit 1
  fi
}

main "$@"
```

**Command README Template (commands/{name}/README.md):**
```markdown
# Command: install

## When Called
- User runs: `dcx install`
- Triggered after: `dcx up -d` (first time setup)

## Context Schema (Optional)
JSON structure from DCX_CONTEXT environment variable:

```json
{
  "dcx": {
    "version": "1.0.0",
    "plugin": "oro",
    "mode": "default"
  },
  "paths": {
    "project_root": "/home/user/myproject",
    "config_dir": "/home/user/.dcx/myproject",
    "compose_dir": "/usr/local/share/dcx/compose"
  },
  "state": {
    "containers_running": true,
    "database_initialized": false
  }
}
```

**Schema file**: `schemas/core/context.schema.json`

**Purpose**: Shared context set once by dcx core, available to all commands.

**Usage in command**: Commands can access context but should work without it (use defaults).

## Input Schema
JSON structure passed via stdin:

```json
{
  "project": {
    "name": "myapp",
    "path": "/var/www/html"
  },
  "database": {
    "schema": "pgsql",
    "host": "database",
    "port": 5432,
    "user": "app",
    "password": "app",
    "dbname": "app"
  },
  "oro": {
    "admin": {
      "user": "admin",
      "email": "admin@example.com",
      "password": "secret"
    },
    "organization": "ACME Corp"
  }
}
```

**Schema file**: `schemas/plugins/oro/install-input.schema.json`

**Required fields**:
- `project.name` (string): Project name
- `project.path` (string): Project path
- `database.schema` (enum: pgsql, mysql): Database type
- `database.host` (string): Database host
- `database.port` (integer): Database port

**Optional fields**:
- `oro.admin.*`: Admin user configuration (defaults used if omitted)
- `oro.organization`: Organization name

## Output Schema
JSON structure returned via stdout:

```json
{
  "status": "success",
  "message": "Installation completed",
  "data": {
    "admin_user": "admin",
    "database_created": true,
    "services_started": ["fpm", "cli", "nginx"]
  },
  "warnings": [],
  "errors": []
}
```

**Schema file**: `schemas/core/command-result.schema.json`

## Expected Behavior
1. Validate input JSON against schema
2. Run composer install
3. Execute oro:install command
4. Set up admin user
5. Configure application URL
6. Return structured result with status

## Logging
All debug information goes to stderr:
- Input JSON (with colors via jq)
- Execution steps
- Command outputs
- Error details

## Usage Examples

### Basic installation
```bash
# Set context once (optional, dcx core sets it)
export DCX_CONTEXT='{
  "dcx": {"version": "1.0.0", "plugin": "oro"},
  "paths": {"config_dir": "/home/user/.dcx/myapp"}
}'

# Pipe command-specific data
echo '{
  "project": {"name": "myapp", "path": "/var/www/html"},
  "database": {"schema": "pgsql", "host": "db", "port": 5432}
}' | dcx install
```

### With custom admin credentials
```bash
# Context already set by dcx core
echo '{
  "project": {"name": "myapp", "path": "/var/www/html"},
  "database": {"schema": "pgsql", "host": "db", "port": 5432},
  "oro": {
    "admin": {
      "user": "superadmin",
      "email": "admin@example.com",
      "password": "secret123"
    }
  }
}' | dcx install 2>>install.log
```

### Using fixtures
```bash
# Load from file
cat fixtures/install-config.json | dcx install

# Or with context
export DCX_CONTEXT=$(cat fixtures/context.json)
cat fixtures/install-config.json | dcx install
```

### Testing with jq
```bash
export DCX_CONTEXT='{"dcx": {"version": "1.0.0"}}'

result=$(echo '{"project": {"name": "test"}, "database": {...}}' | dcx install)
status=$(echo "$result" | jq -r '.status')

if [ "$status" = "success" ]; then
  echo "Installation successful!"
  echo "$result" | jq '.data'
else
  echo "Installation failed!"
  echo "$result" | jq '.errors'
fi
```

### Chaining commands (pipes work!)
```bash
# Config generation feeds into install
dcx config generate | dcx install
```

## Error Handling
If validation or execution fails, returns error result:

```json
{
  "status": "error",
  "message": "Composer install failed",
  "exit_code": 1,
  "errors": ["Command failed: composer install"]
}
```

Exit code matches `exit_code` field in JSON result.
```
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
      PLUGIN_DIR="${plugin_dir}"
      plugin_init
      break
    fi
  fi
done

# Or explicit plugin selection
export DCX_PLUGIN=oro  # Force Oro plugin
```

**Why Fixed Structure:**
1. **Predictability** - Developers know exactly where to find things
2. **Documentation** - Every command is self-documenting with README.md
3. **Discoverability** - Auto-registration from directory structure
4. **Maintainability** - Consistent patterns across all plugins
5. **Extensibility** - Easy to add new commands (just create directory)

**Rationale:**
- Plugins are completely self-contained
- Core never imports framework code
- Commands auto-register from directory structure
- Documentation lives next to implementation
- All communication via environment variables (no tight coupling)
- Easy to add new plugins without core changes
- Plugins can be versioned independently

**Alternatives Considered:**
1. **Framework code in core**: Defeats modularity purpose
2. **Separate binaries per framework**: Installation complexity
3. **Configuration file registration**: Less flexible, requires parsing
4. **Flat command structure**: Hard to document, no organization

### Decision 4: JSON Communication Protocol (stdin/stdout)

**CRITICAL: All inter-module communication via JSON**

All communication between dcx core and plugins SHALL use structured JSON via stdin/stdout, with logs going to stderr.

**Why Hybrid Approach (stdin + ENV):**

**Primary: JSON via stdin**
1. **Clean Interface** - Standard Unix pipe pattern
2. **Command-Specific Data** - Each command gets its unique data
3. **No Duplication** - Don't repeat context in every command
4. **Easy Piping** - Can chain commands: `dcx config | dcx install`

**Secondary: JSON context via ENV**
5. **Shared Context** - Set once, used by all commands
6. **Performance** - No need to pass context JSON repeatedly
7. **Immutable State** - Context doesn't change during execution
8. **Debuggability** - Log both stdin JSON and context JSON to stderr

**Common Benefits:**
- ✅ **Structured Data** - Complex nested structures via JSON
- ✅ **Type Safety** - jq-based validation for both
- ✅ **No Dependencies** - jq only, no additional tools
- ✅ **Testability** - Easy to test with fixtures
- ✅ **Stdout Free** - stdout reserved for JSON result

**Communication Protocol:**

```bash
# 1. Core sets shared context (once per dcx invocation)
export DCX_CONTEXT='{
  "dcx": {
    "version": "1.0.0",
    "plugin": "oro",
    "mode": "default"
  },
  "paths": {
    "project_root": "/home/user/myproject",
    "config_dir": "/home/user/.dcx/myproject",
    "compose_dir": "/usr/local/share/dcx/compose"
  },
  "state": {
    "containers_running": true,
    "database_initialized": false
  }
}'

# 2. Core builds command-specific JSON input
echo '{
  "project": {
    "name": "myapp",
    "path": "/var/www/html"
  },
  "database": {
    "schema": "pgsql",
    "host": "database",
    "port": 5432,
    "user": "app",
    "password": "app",
    "dbname": "app"
  },
  "oro": {
    "admin": {
      "user": "admin",
      "email": "admin@example.com",
      "password": "secret"
    },
    "organization": "ACME Corp"
  }
}' | plugins/oro/commands/install/run.sh 2>>install.log

# Command returns structured result via stdout
{
  "status": "success",
  "message": "Installation completed",
  "data": {
    "admin_user": "admin",
    "database_created": true,
    "services_started": ["fpm", "cli", "nginx", "consumer"]
  },
  "warnings": [],
  "errors": []
}
```

**What goes where:**

**DCX_CONTEXT (ENV)** - Shared context, set once:
- dcx version, plugin name, mode
- File paths (project root, config dir, compose dir)
- Current state (containers running, database status)
- User info, system info

**stdin JSON** - Command-specific data:
- Command arguments and options
- Project configuration for this command
- Database credentials
- Framework-specific settings

**Standard Result Format:**
```json
{
  "status": "success|error",
  "message": "Human-readable message",
  "exit_code": 0,
  "data": {},
  "warnings": [],
  "errors": [],
  "metadata": {
    "duration_ms": 12345,
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

**Reading from ENV and Logging via stderr:**
```bash
#!/usr/bin/env bash
# Read JSON from environment variable
# All logs go to stderr, results to stdout

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

log_json() {
  local label="$1"
  local json="$2"
  echo "[DEBUG] ${label}:" >&2
  echo "${json}" | jq -C . >&2  # Color output for readability
}

# Usage
input="${DCX_INPUT}"
log "Starting installation..."
log_json "Input received" "$input"

# Parse JSON with jq
project=$(echo "$input" | jq -r '.project.name')

# Result goes to stdout only
jq -n '{status: "success", message: "Done"}'
```

**JSON Schema Validation:**

Every command SHALL have input/output JSON Schema files:

```
schemas/
├── core/
│   ├── project-config.schema.json
│   ├── database-config.schema.json
│   └── command-result.schema.json
└── plugins/
    └── oro/
        ├── install-input.schema.json
        ├── install-output.schema.json
        ├── platformupdate-input.schema.json
        └── platformupdate-output.schema.json
```

**Example Schema (install-input.schema.json):**
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://dcx.dev/schemas/oro/install-input.json",
  "type": "object",
  "required": ["project", "database"],
  "properties": {
    "project": {
      "type": "object",
      "required": ["name", "path"],
      "properties": {
        "name": {
          "type": "string",
          "pattern": "^[a-z0-9-]+$",
          "minLength": 1,
          "maxLength": 64
        },
        "path": {"type": "string"}
      }
    },
    "database": {
      "type": "object",
      "required": ["schema", "host", "port"],
      "properties": {
        "schema": {"enum": ["pgsql", "mysql"]},
        "host": {"type": "string"},
        "port": {"type": "integer", "minimum": 1, "maximum": 65535},
        "user": {"type": "string"},
        "password": {"type": "string"},
        "dbname": {"type": "string"}
      }
    },
    "oro": {
      "type": "object",
      "properties": {
        "admin": {
          "type": "object",
          "required": ["user", "email", "password"],
          "properties": {
            "user": {"type": "string"},
            "email": {"type": "string", "format": "email"},
            "password": {"type": "string", "minLength": 8}
          }
        }
      }
    }
  }
}
```

**Validation with jq (no additional dependencies):**
```bash
#!/usr/bin/env bash

# Validate JSON structure using jq
validate_json() {
  local json="$1"
  local schema_file="$2"
  
  # 1. Check JSON syntax is valid
  if ! echo "$json" | jq empty 2>/dev/null; then
    log "ERROR: Invalid JSON syntax"
    return 1
  fi
  
  # 2. Check required fields exist
  local required_fields=$(jq -r '.required[]? // empty' "$schema_file" 2>/dev/null)
  for field in $required_fields; do
    # Handle nested fields (e.g., "project.name")
    if ! echo "$json" | jq -e ".${field}" >/dev/null 2>&1; then
      log "ERROR: Missing required field: ${field}"
      return 1
    fi
  done
  
  # 3. Check field types (basic validation)
  # Extract property types from schema and validate
  local properties=$(jq -r '.properties | keys[]' "$schema_file" 2>/dev/null)
  for prop in $properties; do
    local expected_type=$(jq -r ".properties.${prop}.type // empty" "$schema_file")
    
    if [[ -n "$expected_type" ]] && echo "$json" | jq -e ".${prop}" >/dev/null 2>&1; then
      local actual_type=$(echo "$json" | jq -r ".${prop} | type")
      
      if [[ "$expected_type" != "$actual_type" ]]; then
        log "ERROR: Field '${prop}' expected type '${expected_type}', got '${actual_type}'"
        return 1
      fi
    fi
  done
  
  log "JSON validation passed"
  return 0
}

# Usage in command script
input="${DCX_INPUT}"
validate_json "$input" "${SCHEMA_DIR}/oro/install-input.schema.json" || {
  error_result "Schema validation failed" 1
  exit 1
}

# ... do work ...

result=$(success_result "Installation completed" '{...}')
validate_json "$result" "${SCHEMA_DIR}/core/command-result.schema.json"
echo "$result"
```

**Testing Benefits:**
```bash
# Unit test with bats
@test "install command succeeds with valid input" {
  # Set shared context
  export DCX_CONTEXT='{
    "dcx": {"version": "1.0.0", "plugin": "oro"},
    "paths": {"config_dir": "/tmp/test/.dcx"}
  }'
  
  # Pipe command-specific data
  result=$(echo '{
    "project": {"name": "test", "path": "/tmp/test"},
    "database": {"schema": "pgsql", "host": "db", "port": 5432}
  }' | plugins/oro/commands/install/run.sh)
  
  status=$(echo "$result" | jq -r '.status')
  [ "$status" = "success" ]
}

@test "install command fails with invalid input" {
  export DCX_CONTEXT='{"dcx": {"version": "1.0.0"}}'
  
  run bash -c 'echo "{}" | plugins/oro/commands/install/run.sh'
  [ "$status" -eq 1 ]
  
  error_status=$(echo "$output" | jq -r '.status')
  [ "$error_status" = "error" ]
}

@test "install command fails with empty stdin" {
  export DCX_CONTEXT='{"dcx": {"version": "1.0.0"}}'
  
  run bash -c 'echo "" | plugins/oro/commands/install/run.sh'
  [ "$status" -eq 1 ]
  
  error_msg=$(echo "$output" | jq -r '.message')
  [[ "$error_msg" == *"No input provided"* ]]
}

@test "install works without context" {
  unset DCX_CONTEXT
  
  result=$(echo '{
    "project": {"name": "test", "path": "/tmp/test"},
    "database": {"schema": "pgsql", "host": "db", "port": 5432}
  }' | plugins/oro/commands/install/run.sh)
  
  status=$(echo "$result" | jq -r '.status')
  [ "$status" = "success" ]
}

# Load fixtures from files
@test "install with fixture files" {
  export DCX_CONTEXT=$(cat test/fixtures/context.json)
  
  result=$(cat test/fixtures/install-valid.json | plugins/oro/commands/install/run.sh)
  status=$(echo "$result" | jq -r '.status')
  [ "$status" = "success" ]
}

# Test context usage
@test "command uses context config_dir" {
  export DCX_CONTEXT='{"paths": {"config_dir": "/custom/path"}}'
  
  result=$(echo '{"project": {...}}' | plugins/oro/commands/install/run.sh 2>&1)
  
  # Check stderr logs mention config dir
  [[ "$result" == *"/custom/path"* ]]
}
```

**Rationale:**
1. **Debuggability**: stderr logs show exact JSON being passed, easier to troubleshoot than ENV vars
2. **Testability**: Can mock inputs/outputs with JSON fixtures, perfect for bats tests
3. **Validation**: JSON Schema catches errors early, prevents invalid data propagation
4. **Structure**: Complex nested data (arrays, objects) handled naturally
5. **No new deps**: jq already required, ajv-cli optional for strict validation
6. **Separation**: stdout = result data, stderr = debug logs (clear separation)

**Alternatives Considered:**
1. **Environment Variables Only**: Hard to debug, no nested structures, no validation
2. **ENV in, JSON out**: Inconsistent, still hard to test input validation
3. **YAML**: Requires yq, less universal than JSON, harder to manipulate in bash
4. **MessagePack/Protocol Buffers**: Overkill for bash, requires compilation

### Decision 5: Environment Variable Separation (Core vs Plugin)

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

### Decision 6: Command Naming

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

