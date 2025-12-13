# Change: Refactor OroDC into Framework-Agnostic Architecture

## Why

OroDC is currently tightly coupled to Oro Platform products (OroCRM, OroCommerce, OroPlatform), making it impossible to reuse for other PHP frameworks and CMS platforms like Magento, Laravel, Symfony, or WordPress. The monolithic 2386-line bash script combines core Docker Compose orchestration, infrastructure management, and Oro-specific business logic into a single file, creating maintenance challenges and preventing extensibility.

To enable OroDC to support multiple frameworks while maintaining backward compatibility with existing Oro installations, we need to decompose the system into modular, reusable components with a plugin-based architecture for framework-specific functionality.

## What Changes

- **BREAKING** Split monolithic `bin/orodc` (2386 lines) into modular architecture:
  - Core system (~500 lines): Docker Compose orchestration, environment initialization
  - Pipeline management (~300 lines): Command routing, argument parsing, execution flow
  - Infrastructure modules (~400 lines): Database, webserver, message queue, cache, search
  - Framework adapters (~200-300 lines each): Oro, Magento, and extensible plugin system

- Extract 110+ functions into logical modules organized by responsibility
- Implement dynamic framework detection and adapter loading mechanism
- Create standardized infrastructure module interface for reusable components
- Establish plugin architecture for framework-specific commands and configurations
- Maintain 100% backward compatibility with existing Oro installations
- Rename project from "docker-compose-oroplatform" to "docker-compose-webstack" or similar
- Update environment variable naming from `DC_ORO_*` to framework-agnostic alternatives

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
- `bin/orodc` - Split into multiple modules
- `Formula/docker-compose-oroplatform.rb` - Update formula name and structure
- `compose/*.yml` - Reorganize into framework-agnostic and framework-specific files
- `compose/docker/` - Separate framework-specific Docker configurations
- `.github/workflows/` - Update CI/CD for new architecture
- `README.md`, `AGENTS.md` - Update documentation for framework-agnostic usage
- All existing Oro-specific commands (install, platformupdate, cache:clear, etc.)

### Migration Path
- Phase 1: Internal refactoring maintaining `orodc` command compatibility
- Phase 2: Introduce `webstack` command alongside `orodc` (both work)
- Phase 3: Deprecate `orodc` command with warnings
- Phase 4: Complete migration to `webstack` command

### Benefits
- Support for multiple frameworks (Oro, Magento, Laravel, Symfony, etc.)
- Easier maintenance through modular architecture
- Reduced code duplication across infrastructure components
- Improved testability through separation of concerns
- Community contributions enabled through plugin system
- Better documentation through smaller, focused modules

### Risks
- Breaking changes for users with custom scripts or integrations
- Learning curve for contributors familiar with monolithic architecture
- Potential performance overhead from module loading
- Need to maintain backward compatibility during transition

