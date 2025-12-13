# Proposal Review Checklist - What We Might Have Missed

## ✅ Already Covered in Proposal

### Core Features
- ✅ Smart argument parsing (specs/argument-parsing/)
- ✅ Transparent binary redirection (specs/argument-parsing/)
- ✅ Docker Compose orchestration (specs/core-system/)
- ✅ Database import/export (specs/infrastructure-modules/)
- ✅ Plugin system (specs/framework-adapters/)
- ✅ One service = one compose file (design.md)
- ✅ Environment variables (design.md)
- ✅ Configuration management (specs/core-system/)

### UX Features from README
- ✅ Smart PHP detection (argument-parsing spec)
- ✅ Smart database access (infrastructure-modules spec)
- ✅ Debug mode (mentioned in design.md)

---

## ⚠️ Features from README That Need Discussion

### 1. Sync Modes (default/mutagen/ssh)

**Current README:**
```bash
DC_ORO_MODE=default   # Linux/WSL2
DC_ORO_MODE=mutagen   # macOS
DC_ORO_MODE=ssh       # Remote
```

**Status in Proposal:**
- ✅ Mentioned in compose file structure (compose/modes/)
- ⚠️ Need to clarify: Is this CORE or PLUGIN feature?

**Recommendation:** **CORE** - sync modes are infrastructure, not framework-specific
- All frameworks need file sync
- Should be in core-system spec

---

### 2. Proxy Management (orodc proxy up/down/install-certs)

**Current README:**
```bash
orodc proxy up -d           # Start Traefik
orodc proxy install-certs   # Install certificates
orodc proxy down            # Stop proxy
orodc proxy purge           # Remove proxy
```

**Status in Proposal:**
- ✅ Mentioned in existing specs (socks5-proxy, ssl-certificate-management)
- ⚠️ Need to clarify: Is this CORE or PLUGIN feature?

**Recommendation:** **CORE** - proxy is infrastructure
- Not Oro-specific
- Needed for any web development
- Should remain in core with modifications for dcx

---

### 3. Tests Prefix (orodc tests)

**Current README:**
```bash
orodc tests install                       # Setup test env
orodc tests bin/phpunit --testsuite=unit # Run tests
```

**Status in Proposal:**
- ✅ Mentioned in pipeline-management spec
- ⚠️ Need to clarify: Is this ORO-SPECIFIC or GENERIC?

**Recommendation:** **PLUGIN (ORO-SPECIFIC)** 
- Test environment is Oro-specific (bin/phpunit, bin/behat)
- Generic projects don't have this pattern
- Move to plugins/oro/commands/tests.sh

---

### 4. Multiple Hosts Configuration

**Current README:**
```bash
DC_ORO_EXTRA_HOSTS=api,admin,shop
# Access: myproject.docker.local + api.docker.local + admin.docker.local
```

**Status in Proposal:**
- ❌ **NOT mentioned in proposal!**
- This is important feature

**Recommendation:** **CORE** - multiple hosts is infrastructure
- Add to core-system or infrastructure-modules spec
- Rename DC_ORO_EXTRA_HOSTS → DC_EXTRA_HOSTS

---

### 5. XDEBUG Configuration

**Current README:**
```bash
XDEBUG_MODE=debug orodc up -d
XDEBUG_MODE_FPM=debug orodc up -d
XDEBUG_MODE_CLI=debug orodc up -d
```

**Status in Proposal:**
- ❌ **NOT mentioned in proposal!**
- Critical for development

**Recommendation:** **CORE** - debugging is universal
- Add XDEBUG configuration spec
- Works for any PHP framework
- Should be in core-system spec

---

### 6. Custom Docker Images

**Current README:**
```bash
DC_ORO_PGSQL_IMAGE=mypgsql
DC_ORO_PGSQL_VERSION=17
DC_ORO_ELASTICSEARCH_IMAGE=myelastic
```

**Status in Proposal:**
- ⚠️ Partially mentioned (Docker image strategy in tasks)
- Need to clarify how this works with new architecture

**Recommendation:** **CORE + PLUGIN**
- Core services (database, redis, nginx): DC_PGSQL_IMAGE, DC_REDIS_IMAGE
- Plugin services (search, websocket): managed by plugin

---

### 7. Profile Caching

**Current README:**
Not explicitly documented but present in code:
```bash
# Profiles are cached after 'up' command
orodc --profile=consumer up -d
# Later commands automatically include cached profiles
orodc down  # Knows about consumer profile
```

**Status in Proposal:**
- ✅ Mentioned in pipeline-management spec
- Should be preserved in new architecture

**Recommendation:** **CORE** - profile management is infrastructure

---

### 8. Platform-Specific Commands (Oro)

**Current README:**
```bash
orodc install          # Oro installation
orodc platformupdate   # Oro platform update  
orodc updateurl        # Update Oro URLs
orodc importdb         # Import database (generic or Oro-specific?)
orodc exportdb         # Export database (generic or Oro-specific?)
```

**Status in Proposal:**
- ⚠️ Need to clarify: importdb/exportdb generic or Oro-specific?

**Recommendation:**
- **importdb/exportdb**: **CORE** (generic database operations)
- **install**: **PLUGIN (Oro)** (Oro-specific installation)
- **platformupdate**: **PLUGIN (Oro)** (Oro-specific)
- **updateurl**: **PLUGIN (Oro)** (Oro-specific)

---

## 🔍 Missing from Proposal

### 1. Sync Modes Specification
**Missing:** Detailed spec for default/mutagen/ssh sync modes

**Need to add:**
```
compose/modes/
├── default.yml      # Direct volume mount
├── mutagen.yml      # Mutagen sync (macOS)
└── ssh.yml          # SSH remote sync
```

### 2. Multiple Hosts/Extra Hosts Feature
**Missing:** Specification for DC_EXTRA_HOSTS

**Need to add:**
- Environment variable: DC_EXTRA_HOSTS (was DC_ORO_EXTRA_HOSTS)
- Traefik rule generation for multiple hosts
- Hostname processing (short names get .docker.local suffix)

### 3. XDEBUG Configuration
**Missing:** XDEBUG mode configuration for different containers

**Need to add:**
- XDEBUG_MODE (global)
- XDEBUG_MODE_FPM (web requests)
- XDEBUG_MODE_CLI (console commands)
- XDEBUG_MODE_CONSUMER (background workers)
- Persistence mechanism

### 4. Custom Docker Image Configuration
**Missing:** How custom images work with new compose structure

**Need to add:**
- Per-service image override
- Version override
- How this works with compose/services/*.yml files

### 5. Port Binding Configuration
**Current:**
```bash
DC_ORO_NGINX_BIND_HOST=127.0.0.1
DC_ORO_PORT_NGINX=30280
DC_ORO_PORT_PREFIX=302  # Auto-calculates all ports
```

**Status:** Partially mentioned, need detailed spec

---

## 🎯 Recommended Additions to Proposal

### Add to specs/core-system/spec.md

**Sync Modes:**
```markdown
### Requirement: Sync Mode Selection
The system SHALL support multiple file synchronization modes for different platforms.

#### Scenario: Default sync mode (Linux/WSL2)
- **WHEN** DC_MODE=default
- **THEN** it SHALL use direct Docker volume mounts
- **AND** this SHALL provide excellent performance on Linux

#### Scenario: Mutagen sync mode (macOS)
- **WHEN** DC_MODE=mutagen
- **THEN** it SHALL use Mutagen for file synchronization
- **AND** this SHALL avoid slow Docker filesystem on macOS
- **AND** it SHALL require mutagen binary installed

#### Scenario: SSH sync mode (Remote)
- **WHEN** DC_MODE=ssh
- **THEN** it SHALL use SSH-based remote sync
- **AND** this SHALL work with remote Docker hosts
```

**XDEBUG Configuration:**
```markdown
### Requirement: XDEBUG Debugging Support
The system SHALL support flexible XDEBUG configuration for different containers.

#### Scenario: Global XDEBUG mode
- **WHEN** XDEBUG_MODE environment variable is set
- **THEN** it SHALL apply to all PHP containers
- **AND** mode SHALL persist across container recreations

#### Scenario: Per-container XDEBUG mode
- **WHEN** XDEBUG_MODE_FPM is set
- **THEN** it SHALL apply only to FPM container
- **AND** other containers SHALL use XDEBUG_MODE or off
```

**Multiple Hosts:**
```markdown
### Requirement: Multiple Hostname Support
The system SHALL support multiple hostnames for a single application.

#### Scenario: Configure extra hosts
- **WHEN** DC_EXTRA_HOSTS="api,admin,shop"
- **THEN** it SHALL create Traefik rules for all hosts
- **AND** short names SHALL get .docker.local suffix
- **AND** full hostnames SHALL be used as-is
```

---

## 📝 Action Items

### High Priority (Add to Proposal)
1. ⚠️ **Sync modes** - Add detailed spec to core-system
2. ⚠️ **Multiple hosts** - Add to core-system or infrastructure-modules
3. ⚠️ **XDEBUG** - Add to core-system
4. ⚠️ **Custom images** - Clarify how this works with new architecture

### Medium Priority (Clarify)
1. ⚠️ **Proxy commands** - Confirm they stay in core
2. ⚠️ **Tests prefix** - Confirm this moves to Oro plugin
3. ⚠️ **Port configuration** - Detail port management strategy

### Low Priority (Documentation)
1. ℹ️ Update README examples to use `dcx` instead of `orodc`
2. ℹ️ Update environment variable names in examples
3. ℹ️ Add migration guide section

---

## 🤔 Questions to Resolve

1. **importdb/exportdb**: Core (generic) or Plugin (Oro-specific)?
   - **Recommendation:** CORE - database operations are universal

2. **Tests environment**: Core or Plugin?
   - **Recommendation:** PLUGIN - bin/phpunit is Oro/Symfony specific

3. **Proxy management**: Core or Plugin?
   - **Recommendation:** CORE - Traefik proxy is infrastructure

4. **Custom image overrides**: How do they work with compose/services/*.yml?
   - Need to design override mechanism

5. **Profile caching**: Preserve current behavior?
   - **Recommendation:** YES - very useful feature

---

## 📊 Summary

**Good news:** Most key features are covered!

**Need to add:**
1. Sync modes spec (3 modes: default/mutagen/ssh)
2. Multiple hosts spec (DC_EXTRA_HOSTS)
3. XDEBUG configuration spec
4. Custom image override mechanism

**Need to clarify:**
1. Which commands are Core vs Plugin
2. How custom images work with new compose structure
3. Profile caching implementation in new architecture

