# Change: Refactor OroDC into Framework-Agnostic Architecture

## Why

OroDC is currently tightly coupled to Oro Platform products (OroCRM, OroCommerce, OroPlatform), making it impossible to reuse for other PHP frameworks and CMS platforms like Magento, Laravel, Symfony, or WordPress. The monolithic 2386-line bash script combines core Docker Compose orchestration, infrastructure management, and Oro-specific business logic into a single file, creating maintenance challenges and preventing extensibility.

This is a **clean break redesign** - we're building the next generation of the tool without legacy constraints. Users wanting Oro-specific features can continue using the old version while we build something better and more universal.

## What Changes

- **BREAKING** Complete rewrite of OroDC as framework-agnostic WebStack:
  - Core system (~500 lines): Docker Compose orchestration, environment initialization
  - Pipeline management (~300 lines): Command routing, argument parsing, execution flow
  - Infrastructure modules (~400 lines): Database, webserver, message queue, cache, search
  - Framework adapters (~200-300 lines each): Oro, Magento, Laravel, and extensible plugin system

- Extract 110+ functions into logical modules organized by responsibility
- Implement dynamic framework detection and adapter loading mechanism
- Create standardized infrastructure module interface for reusable components
- Establish plugin architecture for framework-specific commands and configurations
- **BREAKING** Rename project to "docker-compose-webstack" or "webstack-cli"
- **BREAKING** Rename binary from `orodc` to `webstack`
- **BREAKING** Replace `DC_ORO_*` environment variables with clean `DC_*` naming
- **BREAKING** Simplify Homebrew formula and remove Oro-specific assumptions

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
- **NEW** `bin/webstack` - Main entry point (replaces orodc)
- **NEW** `bin/webstack.d/*` - Modular core system
- **NEW** `bin/webstack-frameworks.d/*` - Framework adapters
- **REMOVED** `bin/orodc` - Old monolithic script removed
- **RENAMED** `Formula/docker-compose-oroplatform.rb` → `Formula/webstack.rb`
- **REORGANIZED** `compose/*.yml` - Clean framework-agnostic and framework-specific separation
- **REORGANIZED** `compose/docker/` - Framework-specific configurations in subdirectories
- **REWRITTEN** `.github/workflows/` - New CI/CD for modular architecture
- **REWRITTEN** `README.md`, `AGENTS.md` - Framework-agnostic documentation

### Breaking Changes
- **Command name**: `orodc` → `webstack`
- **Environment variables**: `DC_ORO_*` → `DC_*` (clean naming)
- **Homebrew formula**: `docker-compose-oroplatform` → `webstack`
- **Configuration directory**: `~/.orodc/` → `~/.webstack/`
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
- New version is `webstack` v1.0 - clean start
- Users choose when to migrate (no forced upgrades)
- Migration guide provides step-by-step instructions
- Both versions can coexist (different Homebrew formulas)

