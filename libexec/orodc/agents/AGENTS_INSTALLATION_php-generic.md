# Generic PHP Installation Guide

**Complete guide for creating a new generic PHP project from scratch.**

## Prerequisites

- Complete steps 1-4 from `orodc agents installation` (common part):
  - Navigate to empty project directory
  - Run `orodc init` manually in terminal (MUST be done by user BEFORE using agent)
  - Run `orodc up -d`
  - Verify containers are running with `orodc ps`

## Installation Steps

### Step 1: Verify Directory is Empty

**REQUIRED**: Ensure directory is empty (or contains only `.git`):

```bash
orodc exec ls -la
# Should show only .git (if version control) or be empty
```

**IMPORTANT**: Project creation commands MUST be run in an empty directory.

### Step 2: Extract Environment Variables

**REQUIRED**: Before running installation commands, extract environment variables needed for configuration:

```bash
# Primary command: Get all OroDC service connection variables
orodc exec env | grep ORO_

# Or get all environment variables
orodc exec env

# Filter by specific service:
orodc exec env | grep -i database
orodc exec env | grep -i redis
orodc exec env | grep -i search
```

**IMPORTANT**: 
- **MUST be done BEFORE Step 6 (Configure Application)** - you'll need these variables for application configuration
- Save these variables or keep them accessible
- Common variables you'll need:
  - Database connection variables (`ORO_DB_HOST`, `ORO_DB_NAME`, `ORO_DB_USER`, `ORO_DB_PASSWORD`)
  - Cache/Redis variables (if using cache)
  - Search engine variables (if using search)
  - Message queue variables (if using RabbitMQ)

### Step 3: Initialize Project Structure

Create basic project structure:

```bash
orodc exec mkdir -p src public config
```

### Step 4: Create Composer Configuration

Create `composer.json`:

```bash
orodc exec composer init
```

Or create manually with basic structure.

### Step 5: Install Dependencies

```bash
orodc exec composer install
```

### Step 6: Create Entry Point

Create `public/index.php` as application entry point:

```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

// Your application bootstrap code here
```

### Step 7: Configure Application

Create configuration files as needed:
- Database configuration (use environment variables extracted in Step 2)
- Application settings
- Service configurations

## Verification

- **Application**: `https://{project_name}.docker.local`
- Check application is accessible and working

## Important Notes

- **Project structure**: Organize code according to your framework or architecture
- **Environment variables**: Use `orodc exec env | grep ORO_` to get all OroDC service connection variables (database, cache, search, message queue, etc.)
- **Composer**: Use Composer for dependency management
- **Entry point**: Configure web server to point to `public/index.php` or your entry point
