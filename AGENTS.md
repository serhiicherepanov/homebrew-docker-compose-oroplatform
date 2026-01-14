<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# AI Agents Guidelines

This document contains ONLY instructions for AI agents working with homebrew-docker-compose-oroplatform.

**For project documentation, workflows, and commands:** See [DEVELOPMENT.md](DEVELOPMENT.md)
**For project context and architecture:** See [openspec/project.md](openspec/project.md)

---

# 🔴🔴🔴 **CRITICAL: "NEW BRANCH" ALWAYS MEANS FROM UPSTREAM!**

## ⚠️ **AFTER CREATING ANY BRANCH - ALWAYS CHECK MERGE CONFLICTS!**

**After creating and pushing ANY new branch:**

1. **ALWAYS verify it can auto-merge into master:**
   ```bash
   git fetch origin
   # Check if branch needs rebase
   git merge-base origin/master HEAD
   ```

2. **If branch is NOT cleanly based on latest master:**
   ```bash
   # Immediately rebase on master
   git rebase origin/master
   # Resolve conflicts
   git push origin <branch-name> --force-with-lease
   ```

3. **WHY THIS MATTERS:**
   - User sees "Can't automatically merge" on GitHub
   - User has to manually ask to fix it EVERY TIME
   - Wastes time and creates friction
   - **PREVENT THIS** by ensuring clean rebase before final push

**RULE:** Never leave a branch with merge conflicts. Always test merge-ability.

---

## ⚡ **WHEN USER SAYS "CREATE NEW BRANCH" OR "NEW BRANCH":**

**THIS ALWAYS MEANS:**
- ✅ Sync with upstream (main repository) FIRST
- ✅ Create branch from LATEST upstream master
- ✅ NEVER continue existing work
- ✅ NEVER assume current branch is correct

**MANDATORY WORKFLOW:**
```bash
# ✅ ALWAYS DO THIS WHEN USER SAYS "NEW BRANCH":
git fetch --all
git checkout master
git pull main master
git push origin master
git checkout -b feature/new-task-name
```

**⛔ NEVER:**
- ❌ Continue working in current branch when user says "new branch"
- ❌ Create branch without syncing upstream first
- ❌ Assume user wants to continue existing work

**💡 USER EXPECTATION:**
- "New branch" = fresh start from upstream
- "New branch" = abandon current work context
- "New branch" = sync with latest changes first

---

# 🔴 **CRITICAL: NEW TASK = NEW BRANCH!**

## ⚡ **MANDATORY RULE: ALWAYS CREATE NEW BRANCH FOR NEW TASK!**

**🚨 BEFORE STARTING ANY NEW TASK:**
```bash
# ✅ MANDATORY WORKFLOW FOR EVERY NEW TASK:
git fetch --all
git checkout master
git pull main master
git push origin master
git checkout -b fix/descriptive-task-name
```

**🔥 THIS RULE APPLIES TO:**
- ✅ New features
- ✅ Bug fixes
- ✅ Configuration changes
- ✅ Documentation updates
- ✅ ANY code modifications

**⛔ NEVER:**
- ❌ Start working without creating a branch
- ❌ Continue in old branch when starting new task
- ❌ Make changes directly in master
- ❌ Assume you're in the right branch

**💡 WHY THIS IS CRITICAL:**
- Prevents mixing unrelated changes
- Allows independent code review per task
- Enables parallel work on multiple features
- Maintains clean git history
- Prevents broken Pull Requests

---

# 🔴 **CRITICAL: NEVER MODIFY USER FILES WITHOUT PERMISSION!**

## ⚡ **MANDATORY RULE: RESPECT USER ENVIRONMENT BOUNDARIES!**

**🚨 NEVER MODIFY FILES OUTSIDE PROJECT WITHOUT EXPLICIT USER PERMISSION:**

**⛔ FORBIDDEN WITHOUT PERMISSION:**
- ❌ User home directory files (~/.zshrc, ~/.bashrc, ~/.profile)
- ❌ User config files outside project (~/.config/*, ~/.env, etc.)
- ❌ Project-specific user files (project/.env.orodc, project/config.local.yml)
- ❌ System files (/etc/*)
- ❌ Any file outside current git repository

**✅ ALLOWED WITHOUT ASKING:**
- ✅ Files within current git repository (tracked by git)
- ✅ Temporary files in project directory for demonstration
- ✅ Files explicitly mentioned by user as targets

**💡 WHEN USER NEEDS EXTERNAL FILE CHANGES:**
- 🗣️ Show the commands user should run
- 📋 Provide instructions to copy-paste
- ⚠️ Explain what changes are needed and why
- 🚫 NEVER execute the changes yourself

**EXAMPLE - CORRECT APPROACH:**
```bash
# ❌ WRONG: Modifying user file directly
echo "export VAR=value" >> ~/.zshrc

# ✅ CORRECT: Show user what to add
# User should add to ~/.zshrc:
# export VAR=value
```

---

# 🚨 **CRITICAL: PRE-PUSH MANDATORY SYNC!**

## ⚡ **BEFORE ANY BRANCH CREATION - MANDATORY STEPS:**

```bash
# ✅ ALWAYS DO THIS FIRST! EVERY TIME! NO EXCEPTIONS!
git fetch --all
git checkout master  
git pull main master    # NOT origin master!
git push origin master  # Update your fork

# ❌ ONLY AFTER SYNC - create branch:
git checkout -b feature/your-branch-name
```

**🔥 FAILURE TO SYNC CAUSES:**
- Merge conflicts
- Divergent branches  
- Failed CI/CD
- Broken Pull Requests
- Wasted time debugging

**⛔ NEVER SKIP THIS STEP!**

---

# 🚫 **CRITICAL: NEVER PUSH DIRECTLY TO MASTER/MAIN!**

**⛔ ABSOLUTELY FORBIDDEN:**
```bash
# NEVER DO THIS! NEVER!
git checkout master
git merge some-branch
git push origin master     # ❌ FORBIDDEN!
```

**✅ ALWAYS USE PULL REQUESTS:**
```bash
# ✅ CORRECT: Push branch and create PR
git push -u origin feature/my-feature
# Then create Pull Request via GitHub interface
```

**Why this rule exists:**
- 🔍 **Code Review**: Every change must be reviewed
- 🛡️ **Quality Control**: Prevent breaking changes
- 📝 **Documentation**: Maintain clear change history  
- 🤝 **Collaboration**: Allow team discussion
- 🔄 **CI/CD**: Automated testing before merge

---

# 🔴 **CRITICAL: NEW CHANGES AFTER PUSH**

**⛔ NEVER add new changes to already pushed branches!**

If you've already pushed a branch and want to add MORE changes:

**✅ CORRECT:**
```bash
# 1. Update from upstream first
git fetch --all
git checkout master
git pull main master
git push origin master

# 2. Create NEW branch for additional changes
git checkout -b fix/additional-improvements
# Make new changes
git commit -m "Additional improvements"
git push -u origin fix/additional-improvements
```

**❌ WRONG:**
```bash
git checkout existing-pushed-branch
# make changes
git commit -m "more changes" 
git push  # ❌ This creates messy history!
```

**Exception:** Only add to pushed branches if explicitly fixing issues in the SAME Pull Request discussion.

---

# 🚨 **CRITICAL: WHEN USER SAYS "I MERGED"**

**⚡ IMMEDIATE ACTION REQUIRED:**
When user says **"я смерджил"** (I merged) or **"смерджил"** or **"merged"**:

**✅ CORRECT workflow:**
```bash
# 1. Sync with upstream
git fetch --all
git checkout master
git pull main master
git push origin master

# 2. Create NEW branch for new work
git checkout -b feature/next-improvements
```

**❌ WRONG: Continue in merged branch**
```bash
git commit -m "more changes"  # ❌ NEVER after merge!
```

---

# 🔴 **IMPORTANT: WHEN USER SAYS "VERSION"**

**💡 90% of the time this refers to the Homebrew Formula version!**

When the user mentions:
- "про версию" (about version)
- "обновляй версию" (update version)
- "версию" (version)
- "version"

**Default Action:** Update version in `Formula/docker-compose-oroplatform.rb`

**File location:** `Formula/docker-compose-oroplatform.rb`
**Line to update:** `version "X.Y.Z"`

**Only 10% of cases** might refer to:
- Docker image versions
- PHP/Node versions
- Dependency versions

**When in doubt, ASK:** "Do you mean the Homebrew formula version?"

---

## 🔴 **IMPORTANT: When User Says "Version" or "About Version"**

**💡 90% of the time this refers to the Homebrew Formula version!**

When the user mentions:
- "про версию" (about version)
- "обновляй версию" (update version)
- "версию" (version)
- "version"

**Default Action:** Update the version in `Formula/docker-compose-oroplatform.rb`

**File location:** `Formula/docker-compose-oroplatform.rb`
**Line to update:** `version "X.Y.Z"`

**Only 10% of cases** might refer to:
- Docker image versions
- PHP/Node versions
- Dependency versions

**When in doubt, ASK:** "Do you mean the Homebrew formula version?"

# 📦 **FORMULA VERSIONING**

```ruby
# Before (in Formula/docker-compose-oroplatform.rb)
version "0.8.6"

# After - Bug fix (patch)
version "0.8.7"

# After - New feature (minor)
version "0.9.0"

# After - Breaking change (major)
version "1.0.0"
```

### ⚠️ **CRITICAL: Version Update is Mandatory!**

- **ALWAYS** update version before committing changes to `compose/` or `bin/`
- **NEVER** commit without version increment when modifying core functionality
- Version updates ensure proper Homebrew package management

---

# 🎯 **BRANCH NAMING RULES**

- `feature/short-description` - new features
- `fix/issue-description` - bug fixes  
- `update/component-name` - version/config updates
- `docs/topic` - documentation
- `refactor/component` - refactoring

### 💡 Examples:
- `update/oro-workflow-versions`
- `fix/yaml-syntax-errors`  
- `feature/php-auto-detection`
- `docs/installation-guide`

---

## 🔴 **IMPORTANT: When User Says "Version" or "About Version"**

**💡 90% of the time this refers to the Homebrew Formula version!**

When the user mentions:
- "про версию" (about version)
- "обновляй версию" (update version)
- "версию" (version)
- "version"

**Default Action:** Update the version in `Formula/docker-compose-oroplatform.rb`

**File location:** `Formula/docker-compose-oroplatform.rb`
**Line to update:** `version "X.Y.Z"`

**Only 10% of cases** might refer to:
- Docker image versions
- PHP/Node versions
- Dependency versions

**When in doubt, ASK:** "Do you mean the Homebrew formula version?"

---

### 📦 **Formula Versioning Examples:**

```ruby
# Before (in Formula/docker-compose-oroplatform.rb)
version "0.8.6"

# After - Bug fix
version "0.8.7"

# After - New feature
version "0.9.0"

# After - Breaking change
version "1.0.0"
```

### ⚠️ **CRITICAL: Version Update is Mandatory!**

- **ALWAYS** update the version before committing changes to `compose/` or `bin/`
- **NEVER** commit without version increment when modifying core functionality
- Version updates ensure proper Homebrew package management

---
**Remember: Version first, branch first, commit later! 📦🌳**
---

# 📋 **AI AGENT RESPONSE GUIDELINES**

## Always Include:
- Complete workflows, not isolated commands
- OS-specific considerations
- Performance implications
- Error context when troubleshooting

## Never Suggest:
- `cli` prefix for PHP commands (OroDC auto-detects)
- `default` mode on macOS (extremely slow)
- Commands without setup context
- Incomplete workflows
- `[[ -n "${DEBUG:-}" ]]` syntax (breaks with `set -e`)
- Emojis in terminal commands or output
- Shell syntax that isn't zsh compatible

## 🔴 **CRITICAL: Fix Root Cause, Not Symptoms**

**⚡ MANDATORY: Solve the actual problem, not work around it!**

**⛔ NEVER:**
- ❌ Add fallbacks/workarounds without user request or confirmation
- ❌ Hide problems with default values or silent failures
- ❌ Create "safe" code paths that mask real issues
- ❌ Add error handling that swallows errors instead of fixing them

**✅ ALWAYS:**
- ✅ Fix the root cause of the problem
- ✅ Make code fail fast and clearly when something is wrong
- ✅ Investigate why something doesn't work, not just add a workaround
- ✅ Ask user for confirmation before adding fallbacks/workarounds
- ✅ Solve the specific problem the user reported

**Example - WRONG approach:**
```bash
# ❌ WRONG: Adding fallback that hides the real problem
if ! find_and_export_ports; then
  # Fallback to default ports
  export DC_ORO_PORT_MQ=15672
fi
```

**Example - CORRECT approach:**
```bash
# ✅ CORRECT: Fix why find_and_export_ports doesn't work
# Investigate: why is orodc-find_free_port not found?
# Fix: ensure it's in PATH or fix the calling code
find_and_export_ports
```

**Rule:** If something doesn't work, fix WHY it doesn't work, don't add code to work around it.

## Ask User For:
- Operating system
- Current sync mode
- Error messages
- Output of `orodc ps`

## When User Needs Help:
- **Commands/workflows**: Refer to [DEVELOPMENT.md](DEVELOPMENT.md)
- **Architecture/context**: Refer to [openspec/project.md](openspec/project.md)
- **Testing methods**: Refer to [LOCAL-TESTING.md](LOCAL-TESTING.md)
- **Test environment**: Suggest using `~/oroplatform` test project

## Repository Management (CRITICAL):
- **ALWAYS** merge/pull ONLY from remote repositories (origin, main, upstream)
- **NEVER** suggest merging local branches unless explicitly requested
- Default workflow: `git pull --rebase origin master` or `git rebase master` after updating from remote
- When updating branches: always sync with remote first, then rebase feature branches
- Exception: Only merge local branches if user explicitly asks

## Fork vs Upstream Remotes (CRITICAL):
- **origin = your fork** (where you push branches)
- **main = upstream repository** (where PR base branches live)
- **Upstream base branch name is `master`** (remote ref: `main/master`)

**If GitHub PR says "Can’t automatically merge":** you must test against **upstream base**, not your fork:

```bash
# Update remotes
git fetch origin
git fetch main

# On your PR branch:
git checkout <your-pr-branch>
git merge --no-ff --no-commit main/master   # reproduce real PR conflicts locally

# Resolve conflicts, then:
git add -A
git commit
git push origin <your-pr-branch>
```

**Rule:** Checking `origin/master` or `origin/main` is NOT sufficient for mergeability into upstream. Always check `main/master`.

---

# 🔧 **PROJECT-SPECIFIC RULES**

## 🔴 **CRITICAL: Always Start Analysis with Router**

**⚡ MANDATORY: Always Check Router First!**

When analyzing any command or feature, **ALWAYS start with the router** (`bin/orodc`):

1. **Check how command is routed** - see which script/module handles it
2. **Check initialization flow** - see if `initialize_environment` is called
3. **Check command flow** - understand the execution path before diving into specific scripts

**Why this matters:**
- Router handles initialization (`initialize_environment`) for all commands
- Router sets up environment variables, ports, and configuration
- Router routes commands to appropriate modules
- Many issues are solved at router level, not in individual scripts
- Prevents duplicate initialization or missing setup

**Router location:** `bin/orodc`
**Key sections to check:**
- Lines 122-139: Environment initialization logic
- Lines 192-527: Command routing (case statement)

**Example workflow:**
```bash
# 1. Check router first
read_file bin/orodc

# 2. Find command routing
grep "command_name" bin/orodc

# 3. Check initialization
grep "initialize_environment" bin/orodc

# 4. Then check specific script/module
read_file libexec/orodc/specific-script.sh
```

**⛔ NEVER:**
- ❌ Start analyzing individual scripts without checking router
- ❌ Add duplicate initialization without checking router
- ❌ Assume initialization happens without verifying

---

## 🔴 **CRITICAL: After Modifying libexec/ or compose/ Files**

**⚡ ALWAYS Reinstall Formula After Changes:**

When you modify files in `libexec/` or `compose/` directories, you **MUST** reinstall the Homebrew formula for changes to take effect:

```bash
brew reinstall digitalspacestdio/docker-compose-oroplatform/docker-compose-oroplatform
```

**Why:** Homebrew copies files to Cellar on install. Editing files in the tap directory doesn't affect the installed version.

**When to reinstall:**
- ✅ After ANY changes to `libexec/orodc/*.sh`
- ✅ After ANY changes to `libexec/orodc/lib/*.sh`
- ✅ After ANY changes to `compose/` YAML files
- ✅ After ANY changes to `bin/` scripts

**Exception:** Formula file (`Formula/*.rb`) changes apply immediately (no reinstall needed).

---

## OroDC Command Detection
OroDC **automatically detects** PHP commands:

```bash
# ✅ CORRECT - OroDC auto-detects
orodc --version          # → cli php --version
orodc bin/console cache:clear
orodc script.php

# ❌ WRONG - Redundant cli prefix
orodc cli php --version
```

## OroCommerce Search Reindex Commands (CRITICAL)

**OroCommerce has TWO separate search systems:**

### 1. Backend Search (Admin Panel)
- **Command:** `oro:search:reindex`
- **Purpose:** Indexes data for admin panel search
- **Entities:** All backend entities (Products, Orders, Customers, etc.)
- **Usage:** Admin users searching in back office

### 2. Website Search (Storefront)
- **Command:** `oro:website-search:reindex`
- **Purpose:** Indexes data for storefront search
- **Entities:** Customer-facing entities (Products, Categories, etc.)
- **Usage:** Customers searching on website

### 3. OroDC Implementation

**Command:** `orodc search reindex`

**Behavior:** Automatically runs BOTH reindex commands sequentially:

```bash
# User runs:
orodc search reindex

# Executes:
1. oro:search:reindex         (Backend/Admin)
2. oro:website-search:reindex (Storefront/Website)
```

**Implementation details:**
```bash
# libexec/orodc/search.sh
if [[ "$search_cmd" == "reindex" ]]; then
  # First reindex backend search (admin panel)
  backend_cmd="${DOCKER_COMPOSE_BIN_CMD} run --rm cli php ./bin/console oro:search:reindex $*"
  run_with_spinner "Reindexing backend search (admin panel)" "$backend_cmd" || exit $?
  
  # Then reindex website search (storefront)
  website_cmd="${DOCKER_COMPOSE_BIN_CMD} run --rm cli php ./bin/console oro:website-search:reindex $*"
  run_with_spinner "Reindexing website search (storefront)" "$website_cmd" || exit $?
fi
```

### 4. Key Points

**✅ ALWAYS:**
- Reindex BOTH systems when user requests "search reindex"
- Use separate spinner messages to show which system is being indexed
- Handle backend search first, then website search
- Allow passing additional parameters to both commands

**❌ NEVER:**
- Reindex only one system (users expect full reindex)
- Combine commands without clear progress indicators
- Skip website search reindex (critical for storefront)

**Why both are needed:**
- Backend search: Admin users need to find entities in admin panel
- Website search: Customers need to find products on storefront
- Different indexes, different purposes, both equally important

### 5. Additional Search Commands

Both search systems support additional commands:
```bash
# Backend search
oro:search:index <entity>        # Index specific entity
oro:search:optimize              # Optimize search index

# Website search  
oro:website-search:index <entity>
oro:website-search:optimize
```

**OroDC routing:** All commands use `oro:search:` prefix in routing.

## Shell Compatibility (CRITICAL)
**All commands MUST be zsh compatible:**

```bash
# ✅ CORRECT - Works in bash and zsh
echo "DC_ORO_MODE=mutagen" >> .env.orodc

# ❌ WRONG - Quote escaping issues in zsh
echo 'DC_ORO_MODE="mutagen"' >> .env.orodc
```

## Terminal Output Rules
- **NEVER use emojis** in commands/output
- **NEVER use Unicode symbols**
- Use plain ASCII: `[OK]`, `[ERROR]`, `[INFO]`

```bash
# ✅ CORRECT
echo "[OK] Installation completed"

# ❌ WRONG  
echo "✅ Installation completed"
```

## Sync Mode Recommendations
| OS | Mode | Never Suggest |
|----|------|--------------|
| Linux/WSL2 | `default` | - |
| macOS | `mutagen` | NEVER suggest `default` |
| Remote | `ssh` | - |

## When User Needs Test Environment
- Suggest `~/oroplatform` test project
- If doesn't exist, offer to clone community OroPlatform
- Always prefer `~/oroplatform` for consistent testing
- Refer to [LOCAL-TESTING.md](LOCAL-TESTING.md) for detailed methods

## Spinner Mechanism (CRITICAL)

**When implementing or modifying ANY long-running command:**

- **MUST** use `run_with_spinner` function from `lib/ui.sh`
- **MUST** use the same pattern as start containers (`libexec/orodc/lib/docker-utils.sh`, line 144)
- **MUST** NOT redirect stderr when using `run_with_spinner` (spinner writes to stderr)
- **MUST** handle errors appropriately:
  - **Critical operations**: `run_with_spinner "Message" "$cmd" || exit $?`
  - **Non-critical operations**: Check exit code, show warning instead of error

**Standard Pattern:**
```bash
# Critical operation (like start containers)
run_with_spinner "Operation message" "$command" || exit $?

# Non-critical operation (errors as warnings)
if ! run_with_spinner "Operation message" "$command"; then
  msg_warning "Operation completed with warnings (see log above for details)"
fi
```

**Key Rules:**
- ✅ ALWAYS use `run_with_spinner` for long-running operations
- ✅ Use same pattern as start containers everywhere
- ✅ Let `run_with_spinner` handle logging automatically
- ❌ NEVER redirect stderr from `run_with_spinner` (breaks spinner)
- ❌ NEVER use `show_spinner` directly (use `run_with_spinner` wrapper)
- ❌ NEVER capture stderr to suppress errors (spinner needs stderr)

**Implementation Reference:**
- Core function: `libexec/orodc/lib/ui.sh` (`run_with_spinner`, lines 123-190)
- Example (critical): `libexec/orodc/lib/docker-utils.sh` (line 144)
- Example (warnings): `libexec/orodc/cache.sh` (lines 26-30)

## Installation Command Behavior
**When implementing or modifying `orodc install` command:**

- **MUST** prompt user for confirmation before dropping existing database
- **MUST** use `confirm_yes_no` function from `lib/ui.sh`
- **MUST** show database name in confirmation prompt: `"Drop existing database '<name>' before installation?"`
- **MUST** use `database-cli` container for database operations
- **MUST** support both PostgreSQL and MySQL/MariaDB:
  - PostgreSQL: Connect to `postgres` system database, then `DROP DATABASE IF EXISTS`
  - MySQL: Execute `DROP DATABASE IF EXISTS` directly
- **MUST** use `IF EXISTS` clause to prevent errors if database doesn't exist
- **MUST** continue installation even if user declines database drop
- **MUST** use `run_with_spinner` for database drop operation with progress indicator

**Example implementation:**
```bash
if [[ -n "${DC_ORO_DATABASE_SCHEMA:-}" ]]; then
  db_name="${DC_ORO_DATABASE_DBNAME:-app}"
  if confirm_yes_no "Drop existing database '${db_name}' before installation?"; then
    # Drop database using database-cli container
    # PostgreSQL: psql -d postgres -c "DROP DATABASE IF EXISTS ..."
    # MySQL: mysql -e "DROP DATABASE IF EXISTS ..."
  fi
fi
```

## Database and Service Access Rules (CRITICAL)

**When implementing or modifying ANY code that interacts with databases or services:**

- **MUST** use PHP or Node.js scripts for ALL database/service operations
- **MUST** use PHP PDO for database operations (PostgreSQL, MySQL/MariaDB)
- **MUST** use PHP/Node.js for service checks (Redis, Elasticsearch, RabbitMQ, etc.)
- **MUST NOT** use direct command-line tools (psql, mysql, redis-cli, etc.) for checks or operations
- **MUST NOT** rely on system binaries being available in containers

**Why this rule exists:**
- PHP and Node.js are guaranteed to be available in CLI/FPM containers
- Database CLI tools (psql, mysql) may not be installed in all containers
- Consistent approach across all service checks and operations
- Better error handling and cross-platform compatibility

**Examples:**

```bash
# ✅ CORRECT - Use PHP for database checks
php /tmp/db-check.php connection
php /tmp/db-check.php version
php /tmp/db-check.php list
php /tmp/db-check.php exists

# ✅ CORRECT - Use PHP PDO for database operations
php -r "try { \$pdo = new PDO(...); ... } catch (PDOException \$e) { ... }"

# ❌ WRONG - Direct command-line tools
psql -h database -U app -d postgres -c "SELECT version();"
mysql -h database -u app -e "SHOW DATABASES;"
redis-cli -h redis ping
```

**Exception:** Only use direct CLI tools when:
- User explicitly requests it (e.g., `orodc database psql` command)
- It's a convenience wrapper that calls PHP/Node.js internally
- It's for interactive user sessions, not automated checks

---

# 📦 **BINARY STRUCTURE AND PATHS (CRITICAL)**

## Understanding OroDC Binary Structure

**OroDC has TWO different execution contexts that affect path resolution:**

### 1. **Homebrew Installation (Production)**

When installed via `brew install`, the structure is:
```
/usr/local/Cellar/docker-compose-oroplatform/X.Y.Z/
├── bin/
│   └── orodc -> ../libexec/orodc-main (symlink)
└── libexec/
    ├── orodc-main (copy of bin/orodc from tap)
    ├── orodc-find_free_port
    ├── orodc-sync
    └── orodc/ (modular structure)
        ├── cache.sh
        ├── search.sh
        ├── compose.sh
        ├── lib/
        │   ├── common.sh
        │   ├── ui.sh
        │   └── environment.sh
        └── ...
```

**Path resolution in Homebrew:**
- `bin/orodc` is a **symlink** to `libexec/orodc-main`
- When symlink is followed: `SCRIPT_PATH=/usr/local/Cellar/.../libexec/orodc-main`
- `SCRIPT_DIR` becomes `.../libexec/`
- `LIBEXEC_DIR="${SCRIPT_DIR}/orodc"` → `.../libexec/orodc/` ✅

### 2. **Tap Directory (Development)**

When working in tap directory for development:
```
homebrew-docker-compose-oroplatform/
├── bin/
│   ├── orodc (real file, not symlink)
│   ├── orodc-find_free_port
│   └── orodc-sync
└── libexec/
    └── orodc/ (modular structure)
        ├── cache.sh
        ├── search.sh
        ├── compose.sh
        ├── lib/
        │   ├── common.sh
        │   ├── ui.sh
        │   └── environment.sh
        └── ...
```

**Path resolution in tap:**
- `bin/orodc` is a **real file** (not symlink)
- `SCRIPT_PATH=/path/to/tap/bin/orodc`
- `SCRIPT_DIR` becomes `.../bin/`
- `LIBEXEC_DIR="${SCRIPT_DIR}/orodc"` → `.../bin/orodc` ❌ (this is a FILE, not directory!)
- **Need different logic:** `LIBEXEC_DIR="${SCRIPT_DIR}/../libexec/orodc"` ✅

### 3. **Path Resolution Logic in bin/orodc**

```bash
# Determine paths - resolve symlink to get actual installation directory
SCRIPT_PATH="${BASH_SOURCE[0]}"
# Follow symlink if it is one (for Homebrew installation)
if [ -L "$SCRIPT_PATH" ]; then
  SCRIPT_PATH="$(readlink -f "$SCRIPT_PATH")"
fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# SCRIPT_DIR will be .../libexec (Homebrew) or .../bin (development tap)
# Check if we're in development tap or Homebrew installation
if [[ "$(basename "$SCRIPT_DIR")" == "bin" ]]; then
  # Development tap - libexec is sibling directory
  LIBEXEC_DIR="${SCRIPT_DIR}/../libexec/orodc"
else
  # Homebrew installation - libexec modules are in ./orodc/
  LIBEXEC_DIR="${SCRIPT_DIR}/orodc"
fi
```

### 4. **Formula Installation Process**

**How Homebrew Formula creates the structure:**

```ruby
# Formula/docker-compose-oroplatform.rb

def install
  # Copy main orodc dispatcher script to libexec root
  (libexec/"orodc-main").write (tap_root/"bin/orodc").read
  (libexec/"orodc-main").chmod 0755
  
  # Copy entire libexec/orodc/ modular structure
  if (tap_root/"libexec/orodc").exist?
    cp_r (tap_root/"libexec/orodc"), libexec
  end
  
  # Create bin symlink to the main dispatcher
  bin.install_symlink libexec/"orodc-main" => "orodc"
end
```

**Installation steps:**
1. Copies `bin/orodc` → `libexec/orodc-main` (real file)
2. Copies `libexec/orodc/` → `libexec/orodc/` (directory structure)
3. Creates symlink `bin/orodc` → `libexec/orodc-main`

### 5. **Key Differences Summary**

| Aspect | Homebrew Install | Tap Development |
|--------|-----------------|-----------------|
| `bin/orodc` | Symlink → `libexec/orodc-main` | Real file |
| `SCRIPT_PATH` after resolve | `.../libexec/orodc-main` | `.../bin/orodc` |
| `SCRIPT_DIR` | `.../libexec/` | `.../bin/` |
| `basename $SCRIPT_DIR` | `libexec` | `bin` |
| `LIBEXEC_DIR` logic | `${SCRIPT_DIR}/orodc` | `${SCRIPT_DIR}/../libexec/orodc` |

### 6. **CRITICAL Rules for Path Resolution**

**✅ ALWAYS:**
- Check if `SCRIPT_DIR` basename is `bin` to detect tap development
- Use conditional logic for `LIBEXEC_DIR` based on context
- Test both contexts when modifying path resolution
- Follow symlinks with `readlink -f` for Homebrew installations

**❌ NEVER:**
- Assume `SCRIPT_DIR` is always the same location
- Use hardcoded paths without checking context
- Forget to handle both symlink and real file cases
- Use relative paths without understanding current context

### 7. **Testing in Both Contexts**

**Test in tap directory (development):**
```bash
cd /path/to/tap
./bin/orodc help
./bin/orodc version
```

**Test in Homebrew installation:**
```bash
brew reinstall digitalspacestdio/docker-compose-oroplatform/docker-compose-oroplatform
orodc help
orodc version
```

### 8. **When Adding New Modules**

**✅ Correct structure:**
```bash
# New module location
libexec/orodc/new-module.sh

# Router addition in bin/orodc
new-module)
  shift
  if [[ -n "${ORODC_IS_INTERACTIVE_MENU:-}" ]]; then
    execute_with_menu_return "${LIBEXEC_DIR}/new-module.sh" "$@"
  else
    exec "${LIBEXEC_DIR}/new-module.sh" "$@"
  fi
  ;;
```

**Path will resolve correctly in both contexts:**
- Homebrew: `${LIBEXEC_DIR}/new-module.sh` → `.../libexec/orodc/new-module.sh`
- Tap: `${LIBEXEC_DIR}/new-module.sh` → `.../libexec/orodc/new-module.sh`

---

# 📚 **DOCUMENTATION REFERENCES**

**For AI agents (this file):**
- Git workflow rules
- Response guidelines
- Critical constraints

**For users and development info:**
- [DEVELOPMENT.md](DEVELOPMENT.md) - Commands, workflows, troubleshooting
- [openspec/project.md](openspec/project.md) - Architecture, context, tech stack
- [openspec/changes/refactor-cli-modular-architecture/design.md](openspec/changes/refactor-cli-modular-architecture/design.md) - CLI modular architecture, file structure, and services
- [LOCAL-TESTING.md](LOCAL-TESTING.md) - Testing methods and procedures

**Always refer users to appropriate documentation instead of repeating content in responses.**

---

**Remember: Branch first, version first, commit later! Never push to master!** 📦🌳
