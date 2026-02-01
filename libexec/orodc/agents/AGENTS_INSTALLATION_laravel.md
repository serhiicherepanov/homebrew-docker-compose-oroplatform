# Laravel Installation Guide

**Complete guide for creating a new Laravel project from scratch.**

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
```

**IMPORTANT**: 
- **MUST be done BEFORE Step 4 (Configure Environment)** - you'll need these variables for `.env` configuration
- Save these variables or keep them accessible
- Key variables you'll need:
  - `DB_HOST` - Database host (usually "database")
  - `DB_DATABASE` - Database name (from `ORO_DB_NAME`)
  - `DB_USERNAME` - Database user (from `ORO_DB_USER`)
  - `DB_PASSWORD` - Database password (from `ORO_DB_PASSWORD`)

### Step 3: Create Laravel Project

Create new Laravel project using Composer:

```bash
orodc exec composer create-project laravel/laravel .
```

### Step 4: Install Dependencies

```bash
orodc exec composer install
```

### Step 5: Configure Environment

Copy environment file and configure:

```bash
orodc exec cp .env.example .env
```

Edit `.env` with database connection details from environment variables extracted in Step 2:
- `DB_HOST` - Database host (usually "database")
- `DB_DATABASE` - Database name
- `DB_USERNAME` - Database user
- `DB_PASSWORD` - Database password

### Step 6: Generate Application Key

**REQUIRED**: Generate application encryption key:

```bash
orodc exec artisan key:generate
```

### Step 7: Run Database Migrations

```bash
orodc exec artisan migrate
```

### Step 8: Clear and Cache Configuration

```bash
orodc exec artisan config:clear
orodc exec artisan cache:clear
orodc exec artisan config:cache
```

## Verification

- **Application**: `https://{project_name}.docker.local`
- Check application is accessible and working

## Important Notes

- **Application key**: Always generate application key after creating project
- **Environment configuration**: Always configure `.env` with correct database settings
- **Migrations**: Run migrations to set up database schema
