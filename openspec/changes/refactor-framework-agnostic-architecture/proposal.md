# Change: Refactor OroDC into Framework-Agnostic DCX

## Why

OroDC is currently tightly coupled to Oro Platform products (OroCRM, OroCommerce, OroPlatform), making it impossible to reuse for other frameworks and CMS platforms like Magento, Laravel, Symfony, or WordPress. The monolithic 2386-line bash script combines core Docker Compose orchestration, infrastructure management, and Oro-specific business logic into a single file, creating maintenance challenges and preventing extensibility.

This is a **clean break redesign** - we're building DCX (Docker Compose eXtended), a universal tool for any language stack and any environment (dev, staging, production). Users wanting Oro-specific features can continue using the old version while we build something better and more universal.

## What Changes

- **BREAKING** Complete rewrite as minimalist core + plugin system:
  - **Core system (~500 lines)**: Docker Compose orchestration, environment initialization
  - **Infrastructure modules (~50-100 lines each)**: One file per service
  - **CLI tools (~200 lines)**: Database import/export, SSH, basic PHP commands
  - **Framework plugins (~200-300 lines each)**: Completely separate from core

- **Radical modularization approach:**
  - Each Docker service = separate compose file (nginx.yml, database.yml, redis.yml, etc.)
  - Each function = separate file (no monolithic scripts)
  - Framework-specific logic = completely isolated plugins
  - Zero framework assumptions in core

- **Clean minimalist core includes ONLY:**
  - PHP container (generic)
  - Nginx webserver
  - Database (PostgreSQL/MySQL)
  - Redis cache
  - Message broker (RabbitMQ)
  - SSH access
  - CLI functionality
  - Database import/export

- **Core does NOT include:**
  - ❌ Oro-specific commands (install, platformupdate, updateurl)
  - ❌ Framework-specific environment variables
  - ❌ Framework-specific Docker configurations
  - ❌ Elasticsearch/search (moved to plugins)
  - ❌ WebSocket servers (framework-specific)

- **Framework plugins provide:**
  - Framework detection
  - Framework-specific commands
  - Framework-specific environment variables
  - Framework-specific Docker services
  - Framework-specific configurations

- **BREAKING** Rename project to "dcx" (Docker Compose eXtended)
- **BREAKING** Rename binary from `orodc` to `dcx`
- **BREAKING** Replace `DC_ORO_*` with minimal `DC_*` core variables
- **BREAKING** Move all Oro functionality to oro-plugin
- **BREAKING** Configuration directory: `~/.orodc/` → `~/.dcx/`
- **BREAKING** Environment file: `.env.orodc` → `.env.dcx`

## Impact

### Affected Specs
- **NEW** `core-system` - Core Docker Compose orchestration and environment management
- **NEW** `pipeline-management` - Command routing and execution flow
- **NEW** `infrastructure-modules` - Reusable infrastructure components (DB, webserver, MQ, etc.)
- **NEW** `framework-adapters` - Plugin system for framework-specific functionality
- **MODIFIED** `dns-resolution` - Adapt to new modular architecture
- **MODIFIED** `socks5-proxy` - Adapt to new modular architecture  
- **MODIFIED** `ssl-certificate-management` - Adapt to new modular architecture

### Affected Code
- **NEW** `bin/dcx` - Main entry point (replaces orodc, 3 chars!)
- **NEW** `bin/dcx.d/*` - Modular core system
- **NEW** `plugins/*` - Framework plugins
- **REMOVED** `bin/orodc` - Old monolithic script removed
- **RENAMED** `Formula/docker-compose-oroplatform.rb` → `Formula/dcx.rb`
- **REORGANIZED** `compose/*.yml` - Clean framework-agnostic and framework-specific separation
- **REORGANIZED** `compose/docker/` - Framework-specific configurations in subdirectories
- **REWRITTEN** `.github/workflows/` - New CI/CD for modular architecture
- **REWRITTEN** `README.md`, `AGENTS.md` - Framework-agnostic documentation

### Breaking Changes
- **Command name**: `orodc` → `dcx` (3 chars!)
- **Environment variables**: `DC_ORO_*` → `DC_*` (clean naming)
- **Homebrew formula**: `docker-compose-oroplatform` → `dcx`
- **Configuration directory**: `~/.orodc/` → `~/.dcx/`
- **Environment file**: `.env.orodc` → `.env.dcx`
- **Project structure**: Complete reorganization

### Benefits
- ✅ Support for multiple frameworks (Oro, Magento, Laravel, Symfony, etc.)
- ✅ Clean architecture without legacy debt
- ✅ Easier maintenance through modular design
- ✅ Reduced code duplication across infrastructure
- ✅ Better testability through separation of concerns
- ✅ Community contributions enabled through plugin system
- ✅ Modern, maintainable codebase
- ✅ Better performance (no legacy compatibility overhead)

### Migration Strategy for Users
- Old version remains available as `orodc` v0.x in separate branch
- New version is `dcx` v1.0 - clean start
- Users choose when to migrate (no forced upgrades)
- Migration guide provides step-by-step instructions
- Both versions can coexist (different Homebrew formulas)

### Why "dcx"?
- **DC** = Docker Compose (clear purpose)
- **X** = eXtended/eXtensible (universal, not framework-specific)
- **3 chars** = super short to type (dcx vs orodc vs webstack)
- **Environment agnostic** = works in dev, staging, and production
- **Language agnostic** = works with PHP, Ruby, Node.js, any stack
- **No "dev" limitation** = can be used for production deployments
- **Future proof** = can add rolling updates, scaling, orchestration features

