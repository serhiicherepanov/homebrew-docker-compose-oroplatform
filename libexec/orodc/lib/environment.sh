#!/bin/bash
# Environment Management Library
# Provides environment initialization, project detection, registry management

# This is a SIMPLIFIED version for minimal working implementation
# Full version with all registry functions can be added later

# Find file in current or parent directories
find-up() {
  local file="$1"
  local path="${2:-$PWD}"
  while [[ "$path" != "" && ! -e "$path/$file" ]]; do
    path=${path%/*}
  done
  echo "$path"
}

# Load .env file safely
load_env_safe() {
  local env_file="$1"
  if [[ -f "$env_file" ]]; then
    set -a
    source "$env_file"
    set +a
    
    # CRITICAL: Normalize ORO_MAILER_ENCRYPTION immediately after loading
    # Handle "null" (string) and empty string - set to tls
    if [[ -z "${ORO_MAILER_ENCRYPTION:-}" ]] || [[ "${ORO_MAILER_ENCRYPTION:-}" == "" ]] || [[ "${ORO_MAILER_ENCRYPTION:-}" == "null" ]]; then
      export ORO_MAILER_ENCRYPTION="tls"
    fi
  fi
}

# Check if in project
check_in_project() {
  if [[ -z "${DC_ORO_NAME:-}" ]] || [[ -z "${DC_ORO_CONFIG_DIR:-}" ]]; then
    msg_error "No project found in current directory"
    msg_info "Please navigate to a project directory or run 'orodc init'"
    echo "" >&2
    return 1
  fi
  return 0
}

# Environment registry functions (simplified)
get_environment_registry_file() {
  local registry_dir="${HOME}/.orodc"
  mkdir -p "$registry_dir"
  echo "${registry_dir}/environments.json"
}

get_environment_registry() {
  local registry_file=$(get_environment_registry_file)
  if [[ -f "$registry_file" ]]; then
    cat "$registry_file"
  else
    echo '{"environments":[]}'
  fi
}

write_environment_registry() {
  local registry="$1"
  local registry_file=$(get_environment_registry_file)
  echo "$registry" > "$registry_file"
}

register_environment() {
  local env_name="$1"
  local env_path="$2"
  local config_dir="$3"

  # Check if jq is available
  if ! command -v jq >/dev/null 2>&1; then
    return 0
  fi

  local registry=$(get_environment_registry)
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Ensure absolute path
  local absolute_path=$(realpath "$env_path" 2>/dev/null || echo "$env_path")
  if [[ -n "$absolute_path" ]] && [[ "$absolute_path" != "$env_path" ]]; then
    env_path="$absolute_path"
  fi

  # Remove existing entry if present
  registry=$(echo "$registry" | jq --arg name "$env_name" '.environments = (.environments | map(select(.name != $name)))')

  # Add new entry
  registry=$(echo "$registry" | jq --arg name "$env_name" \
    --arg path "$env_path" \
    --arg config "$config_dir" \
    --arg timestamp "$timestamp" \
    '.environments += [{
      "name": $name,
      "path": $path,
      "config_dir": $config,
      "last_used": $timestamp
    }]')

  write_environment_registry "$registry"
}

# Unregister environment from registry
unregister_environment() {
  local env_name="$1"
  
  # Check if jq is available
  if ! command -v jq >/dev/null 2>&1; then
    return 0
  fi
  
  local registry=$(get_environment_registry)
  # Remove entry with matching name
  registry=$(echo "$registry" | jq --arg name "$env_name" '.environments = (.environments | map(select(.name != $name)))')
  
  write_environment_registry "$registry"
}

# Check if environment is registered
is_environment_registered() {
  local env_name="$1"
  
  # Check if jq is available
  if ! command -v jq >/dev/null 2>&1; then
    return 1
  fi
  
  local registry=$(get_environment_registry)
  local count=$(echo "$registry" | jq --arg name "$env_name" '[.environments[] | select(.name == $name)] | length')
  
  if [[ "$count" -gt 0 ]]; then
    return 0
  else
    return 1
  fi
}

# Get environment status (running/stopped/uninitialized)
get_environment_status() {
  local env_name="$1"
  local env_path="${2:-}"
  
  # If not in a project, return uninitialized
  if [[ -z "$env_name" ]] || [[ -z "$env_path" ]]; then
    echo "uninitialized"
    return 0
  fi
  
  # Check if config directory exists
  local config_dir="${HOME}/.docker-compose-oroplatform/${env_name}"
  if [[ ! -f "${config_dir}/docker-compose.yml" ]]; then
    echo "uninitialized"
    return 0
  fi
  
  # Resolve Docker binary if not set
  local docker_bin="${DOCKER_BIN:-}"
  if [[ -z "$docker_bin" ]]; then
    if command -v docker >/dev/null 2>&1; then
      docker_bin=$(command -v docker)
    else
      echo "stopped"
      return 0
    fi
  fi
  
  # Check if Docker is available and working
  if ! "$docker_bin" ps >/dev/null 2>&1; then
    echo "stopped"
    return 0
  fi
  
  # Check if any containers for this environment are running
  # Look for containers with the environment name prefix
  local running_count=$("$docker_bin" ps --filter "name=${env_name}" --format "{{.Names}}" 2>/dev/null | grep -c "^${env_name}_" || echo "0")
  
  if [[ "$running_count" -gt 0 ]]; then
    echo "running"
  else
    echo "stopped"
  fi
}

# Get environment info by name
get_environment_info() {
  local env_name="$1"
  
  # Check if jq is available
  if ! command -v jq >/dev/null 2>&1; then
    return 1
  fi
  
  local registry=$(get_environment_registry)
  echo "$registry" | jq -r --arg name "$env_name" '.environments[] | select(.name == $name) | "\(.name)|\(.path)|\(.config_dir)"'
}

# List all registered environments with interactive selection
list_environments() {
  # Check if jq is available
  if ! command -v jq >/dev/null 2>&1; then
    msg_warning "jq is not installed. Cannot list environments."
    msg_info "Install jq: brew install jq"
    return 1
  fi
  
  local registry=$(get_environment_registry)
  local env_count=$(echo "$registry" | jq '.environments | length')
  
  if [[ "$env_count" -eq 0 ]]; then
    msg_info "No environments registered yet."
    return 0
  fi
  
  # Build arrays of environment data
  local env_names=()
  local env_paths=()
  local env_statuses=()
  local index=1
  
  # Collect environment data
  while IFS='|' read -r name path last_used; do
    env_names+=("$name")
    env_paths+=("$path")
    local status=$(get_environment_status "$name" "$path")
    env_statuses+=("$status")
    index=$((index + 1))
  done < <(echo "$registry" | jq -r '.environments[] | "\(.name)|\(.path)|\(.last_used)"')
  
  # Display environments
  echo "" >&2
  echo -e "\033[1;34m========================================\033[0m" >&2
  echo -e "\033[1;34m    Select Environment\033[0m" >&2
  echo -e "\033[1;34m========================================\033[0m" >&2
  echo "" >&2
  
  # Show current environment if any
  if [[ -n "${DC_ORO_NAME:-}" ]]; then
    echo -e "Current: \033[1m${DC_ORO_NAME}\033[0m" >&2
    echo "" >&2
  fi
  
  # Display numbered list
  local i=1
  for name in "${env_names[@]}"; do
    local idx=$((i - 1))
    local status="${env_statuses[$idx]}"
    local path="${env_paths[$idx]}"
    
    # Format status with colors
    local status_display=""
    local marker=""
    case "$status" in
      running)
        status_display=$'\033[32mrunning\033[0m'
        ;;
      stopped)
        status_display=$'\033[31mstopped\033[0m'
        ;;
      *)
        status_display=$'\033[33muninitialized\033[0m'
        ;;
    esac
    
    # Mark current environment
    if [[ "$name" == "${DC_ORO_NAME:-}" ]]; then
      marker=$' \033[33m(current)\033[0m'
    fi
    
    # Truncate path if too long
    local display_path="$path"
    if [[ ${#display_path} -gt 50 ]]; then
      display_path="...${display_path: -47}"
    fi
    
    printf "  %2d) %-30s %b%s\n" "$i" "$name" "$status_display" "$marker" >&2
    printf "      %s\n" "$display_path" >&2
    echo "" >&2
    i=$((i + 1))
  done
  
  echo "" >&2
  echo -n "Select environment [1-$env_count] or 'q' to cancel: " >&2
  read -r choice
  
  # Handle cancellation
  if [[ "$choice" == "q" ]] || [[ "$choice" == "Q" ]] || [[ -z "$choice" ]]; then
    return 0
  fi
  
  # Validate choice
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt "$env_count" ]]; then
    msg_error "Invalid selection"
    return 1
  fi
  
  # Get selected environment
  local selected_idx=$((choice - 1))
  local selected_name="${env_names[$selected_idx]}"
  local selected_path="${env_paths[$selected_idx]}"
  
  # Check if already in this environment
  if [[ "$selected_name" == "${DC_ORO_NAME:-}" ]] && [[ "$selected_path" == "$PWD" ]]; then
    msg_info "Already in this environment"
    return 0
  fi
  
  # Check if path exists
  if [[ ! -d "$selected_path" ]]; then
    msg_error "Environment path does not exist: $selected_path"
    return 1
  fi
  
  # Update last_used timestamp
  local env_info=$(get_environment_info "$selected_name")
  if [[ -n "$env_info" ]]; then
    IFS='|' read -r name path config_dir <<< "$env_info"
    register_environment "$name" "$path" "$config_dir" 2>/dev/null || true
  fi
  
  # Export selected path via environment variable (for menu.sh to read)
  # This allows menu.sh to change directory
  export ORODC_SELECTED_PATH="$selected_path"
  
  # Return special code to indicate environment switch
  # Menu will handle directory change and reinitialization
  return 2
}

# Manage domains for current environment
manage_domains() {
  if ! check_in_project; then
    return 1
  fi
  
  local env_file="${DC_ORO_APPDIR}/.env.orodc"
  
  # Get current extra hosts
  local current_hosts="${DC_ORO_EXTRA_HOSTS:-}"
  
  echo "" >&2
  msg_highlight "Domain Management for: ${DC_ORO_NAME}" >&2
  echo "" >&2
  
  if [[ -n "$current_hosts" ]]; then
    msg_info "Current extra domains:" >&2
    IFS=',' read -ra HOSTS <<< "$current_hosts"
    local i=1
    for host in "${HOSTS[@]}"; do
      host=$(echo "$host" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      if [[ -n "$host" ]]; then
        echo "  $i) $host" >&2
        i=$((i + 1))
      fi
    done
  else
    msg_info "No extra domains configured." >&2
  fi
  
  echo "" >&2
  msg_info "To add/remove domains, edit DC_ORO_EXTRA_HOSTS in:" >&2
  echo "  $env_file" >&2
  echo "" >&2
  msg_info "Example format:" >&2
  echo "  DC_ORO_EXTRA_HOSTS=example.com,test.example.com" >&2
  echo "" >&2
}

# Build Traefik routing rule
build_traefik_rule() {
  # Start with main host
  local traefik_rule="Host(\`${DC_ORO_NAME:-unnamed}.docker.local\`)"

  # Process DC_ORO_EXTRA_HOSTS
  if [[ -n "${DC_ORO_EXTRA_HOSTS:-}" ]]; then
    IFS=',' read -ra HOSTS <<< "$DC_ORO_EXTRA_HOSTS"
    for host in "${HOSTS[@]}"; do
      host=$(echo "$host" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      if [[ -n "$host" ]]; then
        # Auto-append .docker.local if host is a single word
        if [[ "$host" != *.* ]]; then
          host="$host.docker.local"
        fi
        traefik_rule="$traefik_rule || Host(\`$host\`)"
      fi
    done
  fi

  export DC_ORO_TRAEFIK_RULE="$traefik_rule"
}

# CRITICAL: Main environment initialization
# This function MUST be called before any docker compose commands
initialize_environment() {
  # Don't reinitialize if already done
  if [[ "${ORODC_ENV_INITIALIZED:-}" == "1" ]]; then
    return 0
  fi

  # Resolve critical dependencies
  export BREW_BIN=$(resolve_bin "brew")
  export DOCKER_BIN=$(resolve_bin "docker")

  # Check docker compose
  if ! "$DOCKER_BIN" compose version >/dev/null 2>&1; then
    msg_error "Docker Compose not found or outdated"
    echo "   Docker Compose V2 is required (docker compose, not docker-compose)"
    echo "   Update Docker: https://docs.docker.com/compose/install/"
    echo
    msg_error "OroDC cannot continue without Docker Compose"
    exit 1
  fi

  # Set up Homebrew environment if needed
  if [[ "$BREW_BIN" != *"/usr/local/bin/brew"* ]] && [[ "$BREW_BIN" != *"/opt/homebrew/bin/brew"* ]]; then
    eval "$("$BREW_BIN" shellenv)" 2>/dev/null || true
  fi

  export DIR=$("$BREW_BIN" --prefix docker-compose-oroplatform)/share/docker-compose-oroplatform
  debug_log "initialize_environment: STEP 1 - DIR set to: ${DIR}"
  debug_log "initialize_environment: STEP 1 - SCRIPT_DIR=${SCRIPT_DIR:-not set}"

  # Try to get rsync from Homebrew, fallback to system rsync
  RSYNC_BIN="$("$BREW_BIN" --prefix rsync)/bin/rsync"
  if [[ ! -x "$RSYNC_BIN" ]]; then
    RSYNC_BIN=$(resolve_bin "rsync")
  fi

  # Set up Docker Compose command
  export DOCKER_COMPOSE_BIN="$DOCKER_BIN compose"
  export DOCKER_COMPOSE_BIN_CMD="$DOCKER_COMPOSE_BIN"
  export DOCKER_COMPOSE_VERSION=$($DOCKER_COMPOSE_BIN_CMD version | grep -E '[0-9]+\.[0-9]+\.[0-9]+' -o | head -1 | awk -F. '{ print $1 }')

  # Find project directory
  if [[ -z "${DC_ORO_APPDIR:-}" ]]; then
    export DC_ORO_APPDIR=$(find-up composer.json)
  fi

  if [[ -z "${DC_ORO_APPDIR:-}" ]]; then
    if [ -z "$(ls -A "$PWD")" ]; then
      export DC_ORO_APPDIR="$PWD"
    else
      # Not in a project - this is OK for some commands (init, proxy, etc.)
      export DC_ORO_APPDIR=""
      export ORODC_ENV_INITIALIZED=1
      return 0
    fi
  fi

  # Load environment files if in project
  if [[ -n "$DC_ORO_APPDIR" ]]; then
    cd "$DC_ORO_APPDIR"

    load_env_safe "$DC_ORO_APPDIR/.env"
    load_env_safe "$DC_ORO_APPDIR/.env-app"
    load_env_safe "$DC_ORO_APPDIR/.env-app.local"
    load_env_safe "$DC_ORO_APPDIR/.env.orodc"
    
    # CRITICAL: Normalize variables AFTER loading all .env files
    # This ensures orodc is the source of truth and overrides any external values
    # Normalize empty variables to unset (so default values are used in docker-compose.yml)
    # This handles case when .env files have VAR="" (empty string) or VAR=null (string "null")
    # Docker Compose uses ${VAR:-default} syntax, which only works if VAR is unset, not if it's empty string
    # Note: DC_ORO_MQ_URI and DC_ORO_REDIS_URI are handled later with explicit default values
    if [[ "${DC_ORO_MQ_URI:-}" == "" ]]; then
      unset DC_ORO_MQ_URI
    fi
    if [[ "${DC_ORO_REDIS_URI:-}" == "" ]]; then
      unset DC_ORO_REDIS_URI
    fi
    if [[ "${DC_ORO_COMPOSER_AUTH:-}" == "" ]]; then
      unset DC_ORO_COMPOSER_AUTH
    fi
    # Normalize ORO_MAILER_ENCRYPTION: handle "null" (string) and empty string - set to tls
    # CRITICAL: This must happen AFTER loading all .env files to ensure orodc is source of truth
    if [[ -z "${ORO_MAILER_ENCRYPTION:-}" ]] || [[ "${ORO_MAILER_ENCRYPTION:-}" == "" ]] || [[ "${ORO_MAILER_ENCRYPTION:-}" == "null" ]]; then
      export ORO_MAILER_ENCRYPTION="tls"
      debug_log "initialize_environment: normalized ORO_MAILER_ENCRYPTION (set to tls)"
    fi

    # Set DC_ORO_NAME from directory name if not set
    if [[ -z "${DC_ORO_NAME:-}" ]]; then
      export DC_ORO_NAME=$(basename "$DC_ORO_APPDIR")
    fi

    # Set DC_ORO_CONFIG_DIR
    if [[ -z "${DC_ORO_CONFIG_DIR:-}" ]]; then
      export DC_ORO_CONFIG_DIR="${HOME}/.docker-compose-oroplatform/${DC_ORO_NAME}"
    fi

    # Create config directory
    mkdir -p "${DC_ORO_CONFIG_DIR}"

    # Create SSH key if it doesn't exist and export public key (same as old implementation)
    if [[ -z ${ORO_SSH_PUBLIC_KEY:-} ]]; then
      if [[ ! -e "${DC_ORO_CONFIG_DIR}/ssh_id_ed25519" ]]; then
        ssh-keygen -t ed25519 -f "${DC_ORO_CONFIG_DIR}/ssh_id_ed25519" -N "" -q
        chmod 0600 "${DC_ORO_CONFIG_DIR}/ssh_id_ed25519"
      fi
      
      if [[ -f "${DC_ORO_CONFIG_DIR}/ssh_id_ed25519.pub" ]]; then
        export ORO_SSH_PUBLIC_KEY=$(cat "${DC_ORO_CONFIG_DIR}/ssh_id_ed25519.pub")
      fi
    fi

    # Sync compose files
    ${RSYNC_BIN} -r --delete \
      --exclude='ssh_id_*' \
      --exclude='.cached_*' \
      --exclude='compose.yml' \
      --exclude='.xdebug_env' \
      "${DIR}/compose/" "${DC_ORO_CONFIG_DIR}/"

    # Setup certificates
    setup_project_certificates

    # Detect database type: priority order:
    # 1. DC_ORO_DATABASE_SCHEMA from .env.orodc (explicit)
    # 2. Auto-detect from DC_ORO_DATABASE_PORT (port-based detection)
    # 3. Parse ORO_DB_URL (fallback)
    
    # First: normalize schema from .env.orodc if already set
    if [[ -n "${DC_ORO_DATABASE_SCHEMA:-}" ]]; then
      local schema_value="${DC_ORO_DATABASE_SCHEMA}"
      if [[ "$schema_value" == "pgsql" ]] || [[ "$schema_value" == "postgresql" ]] || [[ "$schema_value" == "pdo_pgsql" ]]; then
        schema_value="postgres"
        export DC_ORO_DATABASE_SCHEMA="$schema_value"
      elif [[ "$schema_value" == "mariadb" ]] || [[ "$schema_value" == "pdo_mysql" ]]; then
        schema_value="mysql"
        export DC_ORO_DATABASE_SCHEMA="$schema_value"
      fi
      debug_log "initialize_environment: using schema=${schema_value} from .env.orodc"
    fi

    # Second: auto-detect schema from port if schema is not set (port takes priority over ORO_DB_URL)
    if [[ -z "${DC_ORO_DATABASE_SCHEMA:-}" ]] && [[ -n "${DC_ORO_DATABASE_PORT:-}" ]]; then
      local detected_schema=""
      if [[ "${DC_ORO_DATABASE_PORT}" == "3306" ]]; then
        detected_schema="mysql"
      elif [[ "${DC_ORO_DATABASE_PORT}" == "5432" ]]; then
        detected_schema="postgres"
      fi
      
      if [[ -n "$detected_schema" ]]; then
        export DC_ORO_DATABASE_SCHEMA="$detected_schema"
        debug_log "initialize_environment: auto-detected schema=${detected_schema} from port ${DC_ORO_DATABASE_PORT}"
        
        # Save detected schema to .env.orodc for future use
        local env_file="${DC_ORO_APPDIR}/.env.orodc"
        if [[ -f "$env_file" ]]; then
          if grep -q "^DC_ORO_DATABASE_SCHEMA=" "$env_file" 2>/dev/null; then
            if [[ "$(uname)" == "Darwin" ]]; then
              sed -i '' "s|^DC_ORO_DATABASE_SCHEMA=.*|DC_ORO_DATABASE_SCHEMA=${detected_schema}|" "$env_file"
            else
              sed -i "s|^DC_ORO_DATABASE_SCHEMA=.*|DC_ORO_DATABASE_SCHEMA=${detected_schema}|" "$env_file"
            fi
          else
            echo "DC_ORO_DATABASE_SCHEMA=${detected_schema}" >> "$env_file"
          fi
        fi
      fi
    fi

    # Third: parse ORO_DB_URL only if schema is still not set
    if [[ -z "${DC_ORO_DATABASE_SCHEMA:-}" ]] && [[ -n "${ORO_DB_URL:-}" ]]; then
      # Parse ORO_DB_URL to detect database schema (returns normalized: postgres or mysql)
      parse_dsn_uri "${ORO_DB_URL}" "database" "DC_ORO"
      
      # If schema was detected, save it to .env.orodc for future use
      if [[ -n "${DC_ORO_DATABASE_SCHEMA:-}" ]]; then
        local env_file="${DC_ORO_APPDIR}/.env.orodc"
        local schema_value="${DC_ORO_DATABASE_SCHEMA}"
        
        # Update or add DC_ORO_DATABASE_SCHEMA in .env.orodc
        if grep -q "^DC_ORO_DATABASE_SCHEMA=" "$env_file" 2>/dev/null; then
          if [[ "$(uname)" == "Darwin" ]]; then
            sed -i '' "s|^DC_ORO_DATABASE_SCHEMA=.*|DC_ORO_DATABASE_SCHEMA=${schema_value}|" "$env_file"
          else
            sed -i "s|^DC_ORO_DATABASE_SCHEMA=.*|DC_ORO_DATABASE_SCHEMA=${schema_value}|" "$env_file"
          fi
        else
          echo "DC_ORO_DATABASE_SCHEMA=${schema_value}" >> "$env_file"
        fi
        
        debug_log "initialize_environment: detected schema=${schema_value} from ORO_DB_URL, saved to .env.orodc"
      else
        debug_log "initialize_environment: could not detect schema from ORO_DB_URL"
      fi
    fi

    # Generate or regenerate DC_ORO_DATABASE_URI based on schema and connection parameters
    # Always regenerate if schema is set to ensure consistency with port
    if [[ -n "${DC_ORO_DATABASE_SCHEMA:-}" ]]; then
      local db_schema="${DC_ORO_DATABASE_SCHEMA}"
      local db_user="${DC_ORO_DATABASE_USER:-app}"
      local db_password="${DC_ORO_DATABASE_PASSWORD:-app}"
      local db_host="${DC_ORO_DATABASE_HOST:-database}"
      local db_name="${DC_ORO_DATABASE_DBNAME:-app}"
      
      # Use port from DC_ORO_DATABASE_PORT if set, otherwise determine from schema
      local db_port="${DC_ORO_DATABASE_PORT:-}"
      if [[ -z "$db_port" ]]; then
        if [[ "$db_schema" == "postgres" ]]; then
          db_port="5432"
        elif [[ "$db_schema" == "mysql" ]]; then
          db_port="3306"
        else
          db_port="5432"  # Default to PostgreSQL
        fi
      fi
      
      # Check if existing URI matches schema and port - regenerate if not
      local needs_regenerate=false
      if [[ -n "${DC_ORO_DATABASE_URI:-}" ]]; then
        # Check if URI schema matches detected schema
        if [[ "$db_schema" == "postgres" ]] && [[ ! "${DC_ORO_DATABASE_URI}" =~ ^postgres:// ]]; then
          needs_regenerate=true
        elif [[ "$db_schema" == "mysql" ]] && [[ ! "${DC_ORO_DATABASE_URI}" =~ ^mysql:// ]]; then
          needs_regenerate=true
        fi
        # Check if URI port matches DC_ORO_DATABASE_PORT
        if [[ -n "${DC_ORO_DATABASE_PORT:-}" ]]; then
          if [[ "$db_schema" == "postgres" ]] && [[ "${DC_ORO_DATABASE_URI}" =~ :5432/ ]]; then
            if [[ "$db_port" != "5432" ]]; then
              needs_regenerate=true
            fi
          elif [[ "$db_schema" == "mysql" ]] && [[ "${DC_ORO_DATABASE_URI}" =~ :3306/ ]]; then
            if [[ "$db_port" != "3306" ]]; then
              needs_regenerate=true
            fi
          fi
        fi
      else
        needs_regenerate=true
      fi
      
      # Build DSN URI based on schema
      if [[ "$needs_regenerate" == "true" ]]; then
        if [[ "$db_schema" == "postgres" ]]; then
          export DC_ORO_DATABASE_URI="postgres://${db_user}:${db_password}@${db_host}:${db_port}/${db_name}"
        elif [[ "$db_schema" == "mysql" ]]; then
          export DC_ORO_DATABASE_URI="mysql://${db_user}:${db_password}@${db_host}:${db_port}/${db_name}"
        else
          export DC_ORO_DATABASE_URI="postgres://${db_user}:${db_password}@${db_host}:${db_port}/${db_name}"
        fi
        debug_log "initialize_environment: regenerated DC_ORO_DATABASE_URI=${DC_ORO_DATABASE_URI} (schema=${db_schema}, port=${db_port})"
      else
        debug_log "initialize_environment: using existing DC_ORO_DATABASE_URI=${DC_ORO_DATABASE_URI}"
      fi
    fi

    # Generate DC_ORO_MQ_URI - default to DBAL for Community Oro (which only supports DBAL)
    # User can override by setting DC_ORO_MQ_URI explicitly (e.g., for RabbitMQ: amqp://user:pass@mq:5672/)
    # Handle empty string as unset (empty string means use default)
    # Check if variable is unset OR empty string (after loading from .env.orodc)
    if [[ -z "${DC_ORO_MQ_URI:-}" ]] || [[ "${DC_ORO_MQ_URI}" == "" ]] || [[ "${DC_ORO_MQ_URI}" == '""' ]]; then
      # Default to DBAL for Community Oro (only transport supported)
      # Format: dbal: (not dbal://)
      export DC_ORO_MQ_URI="dbal:"
      debug_log "initialize_environment: generated DC_ORO_MQ_URI=${DC_ORO_MQ_URI} (default: DBAL for Community Oro)"
    else
      # Normalize dbal:// to dbal: (DBAL transport doesn't use //)
      if [[ "${DC_ORO_MQ_URI}" == "dbal://" ]]; then
        export DC_ORO_MQ_URI="dbal:"
        debug_log "initialize_environment: normalized DC_ORO_MQ_URI from dbal:// to dbal:"
      fi
      debug_log "initialize_environment: using existing DC_ORO_MQ_URI=${DC_ORO_MQ_URI}"
    fi

    # Generate DC_ORO_REDIS_URI - default to redis://redis
    # User can override by setting DC_ORO_REDIS_URI explicitly (e.g., redis://redis:6379)
    # Handle empty string as unset (empty string means use default)
    # Check if variable is unset OR empty string (after loading from .env.orodc)
    if [[ -z "${DC_ORO_REDIS_URI:-}" ]] || [[ "${DC_ORO_REDIS_URI}" == "" ]] || [[ "${DC_ORO_REDIS_URI}" == '""' ]]; then
      # Default to redis://redis (standard Redis service name in docker-compose)
      export DC_ORO_REDIS_URI="redis://redis"
      debug_log "initialize_environment: generated DC_ORO_REDIS_URI=${DC_ORO_REDIS_URI} (default: redis://redis)"
    else
      debug_log "initialize_environment: using existing DC_ORO_REDIS_URI=${DC_ORO_REDIS_URI}"
    fi

    # Build compose command with config files
    if [[ -f "${DC_ORO_CONFIG_DIR}/docker-compose.yml" ]]; then
      DOCKER_COMPOSE_BIN_CMD="${DOCKER_COMPOSE_BIN_CMD} -f ${DC_ORO_CONFIG_DIR}/docker-compose.yml"
    fi

    # Add sync mode compose file (default, mutagen, ssh)
    if [[ "${DC_ORO_MODE:-default}" == "default" ]] && [[ -f "${DC_ORO_CONFIG_DIR}/docker-compose-default.yml" ]]; then
      DOCKER_COMPOSE_BIN_CMD="${DOCKER_COMPOSE_BIN_CMD} -f ${DC_ORO_CONFIG_DIR}/docker-compose-default.yml"
      debug_log "initialize_environment: added docker-compose-default.yml"
    fi

    # Add database-specific compose file based on detected schema
    # Schema is normalized to 'postgres' or 'mysql' at this point
    if [[ -n "${DC_ORO_DATABASE_SCHEMA:-}" ]]; then
      if [[ "${DC_ORO_DATABASE_SCHEMA}" == "postgres" ]]; then
        if [[ -f "${DC_ORO_CONFIG_DIR}/docker-compose-pgsql.yml" ]]; then
          DOCKER_COMPOSE_BIN_CMD="${DOCKER_COMPOSE_BIN_CMD} -f ${DC_ORO_CONFIG_DIR}/docker-compose-pgsql.yml"
          debug_log "initialize_environment: added docker-compose-pgsql.yml"
        else
          debug_log "initialize_environment: docker-compose-pgsql.yml not found"
        fi
      elif [[ "${DC_ORO_DATABASE_SCHEMA}" == "mysql" ]]; then
        if [[ -f "${DC_ORO_CONFIG_DIR}/docker-compose-mysql.yml" ]]; then
          DOCKER_COMPOSE_BIN_CMD="${DOCKER_COMPOSE_BIN_CMD} -f ${DC_ORO_CONFIG_DIR}/docker-compose-mysql.yml"
          debug_log "initialize_environment: added docker-compose-mysql.yml"
        else
          debug_log "initialize_environment: docker-compose-mysql.yml not found"
        fi
      else
        debug_log "initialize_environment: unknown database schema '${DC_ORO_DATABASE_SCHEMA}', skipping database-specific compose file"
      fi
    else
      debug_log "initialize_environment: DC_ORO_DATABASE_SCHEMA not set, skipping database-specific compose file"
    fi

    # Add user custom compose file if exists
    if [[ -f "${DC_ORO_APPDIR}/.docker-compose.user.yml" ]]; then
      DOCKER_COMPOSE_BIN_CMD="${DOCKER_COMPOSE_BIN_CMD} -f ${DC_ORO_APPDIR}/.docker-compose.user.yml"
      debug_log "initialize_environment: added .docker-compose.user.yml"
    fi

    # Set port prefix
    export DC_ORO_PORT_PREFIX=${DC_ORO_PORT_PREFIX:-"301"}
    debug_log "initialize_environment: STEP 2 - DC_ORO_PORT_PREFIX=${DC_ORO_PORT_PREFIX}"

    # Build Traefik rule
    build_traefik_rule
    debug_log "initialize_environment: STEP 3 - Traefik rule built"

    # Find and export ports - MUST be called to set port variables
    debug_log "initialize_environment: STEP 4 - Before find_and_export_ports"
    debug_log "initialize_environment: STEP 4 - DC_ORO_NAME=${DC_ORO_NAME:-not set}, DC_ORO_CONFIG_DIR=${DC_ORO_CONFIG_DIR:-not set}"
    debug_log "initialize_environment: STEP 4 - SCRIPT_DIR=${SCRIPT_DIR:-not set}, DIR=${DIR:-not set}"
    
    # Check if orodc-find_free_port exists before calling
    local find_port_check=""
    if command -v orodc-find_free_port >/dev/null 2>&1; then
      find_port_check=$(command -v orodc-find_free_port)
      debug_log "initialize_environment: STEP 4 - orodc-find_free_port found in PATH: $find_port_check"
    elif [[ -n "${SCRIPT_DIR:-}" ]] && [[ -x "${SCRIPT_DIR}/orodc-find_free_port" ]]; then
      find_port_check="${SCRIPT_DIR}/orodc-find_free_port"
      debug_log "initialize_environment: STEP 4 - orodc-find_free_port found via SCRIPT_DIR: $find_port_check"
    elif [[ -n "${DIR:-}" ]]; then
      local prefix_dir="$(dirname "$(dirname "$DIR")")"
      local candidate="${prefix_dir}/libexec/orodc-find_free_port"
      debug_log "initialize_environment: STEP 4 - checking DIR-based path: $candidate"
      if [[ -x "$candidate" ]]; then
        find_port_check="$candidate"
        debug_log "initialize_environment: STEP 4 - orodc-find_free_port found via DIR: $find_port_check"
      else
        debug_log "initialize_environment: STEP 4 - DIR-based path not executable or not found"
      fi
    fi
    
    if [[ -z "$find_port_check" ]]; then
      debug_log "initialize_environment: STEP 4 - WARNING: orodc-find_free_port not found before calling find_and_export_ports"
    fi
    
    if [[ -n "${DC_ORO_NAME:-}" ]] && [[ -n "${DC_ORO_CONFIG_DIR:-}" ]]; then
      find_and_export_ports "${DC_ORO_NAME}" "${DC_ORO_CONFIG_DIR}"
      debug_log "initialize_environment: STEP 5 - After find_and_export_ports"
      debug_log "initialize_environment: STEP 5 - ports set - MQ=${DC_ORO_PORT_MQ:-not set}, SEARCH=${DC_ORO_PORT_SEARCH:-not set}, MAIL=${DC_ORO_PORT_MAIL_WEBGUI:-not set}"
    else
      debug_log "initialize_environment: STEP 5 - skipping port allocation - DC_ORO_NAME=${DC_ORO_NAME:-not set}, DC_ORO_CONFIG_DIR=${DC_ORO_CONFIG_DIR:-not set}"
    fi
  fi

  export ORODC_ENV_INITIALIZED=1
}
