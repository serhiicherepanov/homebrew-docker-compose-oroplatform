#!/bin/bash
# Common Functions Library
# Provides basic utilities: logging, timing, env vars, binary resolution

# Debug logging to file (always enabled for debugging menu issues)
DEBUG_LOG="/tmp/orodc-debug.log"
debug_log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$DEBUG_LOG"
}

# Clear log on new session (only once per process tree)
if [[ "${ORODC_LOG_CLEARED:-}" != "1" ]]; then
  echo "=== New orodc session $(date '+%Y-%m-%d %H:%M:%S') ===" > "$DEBUG_LOG"
  export ORODC_LOG_CLEARED=1
fi

# Setup logging only when OroDC is used as PHP binary
setup_php_logging() {
  mkdir -p /tmp/.orodc
  local log_file="/tmp/.orodc/$(basename $0).$(echo "$@" | md5sum - | awk '{ print $1 }').log"
  local err_file="/tmp/.orodc/$(basename $0).$(echo "$@" | md5sum - | awk '{ print $1 }').err"
  touch "$log_file" "$err_file"
  exec 1> >(tee "$log_file")
  exec 2> >(tee "$err_file")
}

# Command timing functions
get_timing_log_file() {
  local timing_dir="${HOME}/.orodc"
  mkdir -p "$timing_dir"
  echo "${timing_dir}/.timing-log"
}

get_previous_timing() {
  local command=$1
  local timing_file=$(get_timing_log_file)

  if [[ -f "$timing_file" ]]; then
    grep "^${command}:" "$timing_file" 2>/dev/null | tail -1 | cut -d: -f2
  fi
}

save_timing() {
  local command=$1
  local duration=$2
  local timing_file=$(get_timing_log_file)

  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "${command}:${duration}:${timestamp}" >> "$timing_file"
}

# Function to update or add environment variable in .env.orodc file
update_env_var() {
  local file="$1"
  local key="$2"
  local value="$3"

  if [[ -f "$file" ]]; then
    if grep -q "^${key}=" "$file"; then
      sed -i.tmp "s|^${key}=.*|${key}=${value}|" "$file"
      rm -f "${file}.tmp"
    else
      echo "${key}=${value}" >> "$file"
    fi
  else
    echo "${key}=${value}" >> "$file"
  fi
}

# Function to resolve binary location with error handling
# Usage: resolve_bin "binary_name" ["install_instructions"]
resolve_bin() {
  local bin_name="$1"
  local install_msg="${2:-}"
  local found_path=""

  # Try PATH first
  if command -v "$bin_name" >/dev/null 2>&1; then
    found_path=$(command -v "$bin_name")
    if [ "$DEBUG" ]; then echo "DEBUG: Found $bin_name in PATH: $found_path" >&2; fi
    echo "$found_path"
    return 0
  fi

  # Try common locations for specific binaries
  case "$bin_name" in
    "brew")
      local brew_paths=("/opt/homebrew/bin/brew" "/usr/local/bin/brew" "/home/linuxbrew/.linuxbrew/bin/brew")
      for brew_path in "${brew_paths[@]}"; do
        if [[ -x "$brew_path" ]]; then
          found_path="$brew_path"
          msg_warning "$bin_name found at $found_path but not in PATH"
          echo "   Add to PATH: export PATH=\"$(dirname "$found_path"):\$PATH\"" >&2
          echo "$found_path"
          return 0
        fi
      done
      ;;
    "docker")
      local docker_paths=("/usr/bin/docker" "/usr/local/bin/docker" "/snap/bin/docker")
      for docker_path in "${docker_paths[@]}"; do
        if [[ -x "$docker_path" ]]; then
          found_path="$docker_path"
          msg_warning "$bin_name found at $found_path but not in PATH"
          echo "$found_path"
          return 0
        fi
      done
      ;;
  esac

  # Not found - show error and exit
  msg_error "$bin_name not found in PATH or common locations"

  if [[ -n "$install_msg" ]]; then
    echo "   $install_msg"
  else
    # Default install instructions
    case "$bin_name" in
      "docker")
        echo "   Install: curl -fsSL https://get.docker.com | sh"
        echo "   Or visit: https://docs.docker.com/engine/install/"
        ;;
      "brew")
        echo "   Install: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        echo "   Then add to PATH: export PATH=\"/home/linuxbrew/.linuxbrew/bin:\$PATH\""
        ;;
      "rsync")
        echo "   Install: sudo apt-get install rsync  # Ubuntu/Debian"
        echo "   Or: brew install rsync"
        ;;
      "jq")
        echo "   Install: sudo apt-get install jq  # Ubuntu/Debian"
        echo "   Or: brew install jq"
        ;;
      *)
        echo "   Please install $bin_name and ensure it's in your PATH"
        ;;
    esac
  fi

  echo
  msg_error "OroDC cannot continue without $bin_name"
  exit 1
}

# Get first non-flag argument from args array
get_first_non_flag_arg() {
  local args=("$@")
  for arg in "${args[@]}"; do
    if [[ "$arg" != -* ]]; then
      echo "$arg"
      return 0
    fi
  done
  echo ""
}

# Parse DSN URI and extract components
# Usage: parse_dsn_uri "dsn_uri" "component_prefix" "env_prefix"
# Example: parse_dsn_uri "postgres://user:pass@host:5432/db" "database" "DC_ORO"
# Sets: DC_ORO_DATABASE_SCHEMA, DC_ORO_DATABASE_HOST, DC_ORO_DATABASE_PORT, etc.
parse_dsn_uri() {
  local dsn_uri="$1"
  local component_prefix="$2"
  local env_prefix="$3"
  
  if [[ -z "$dsn_uri" ]]; then
    return 0
  fi
  
  # Convert component_prefix to uppercase (compatible with older bash)
  local component_upper=$(echo "$component_prefix" | tr '[:lower:]' '[:upper:]')
  
  # Extract schema (postgres, mysql, etc.)
  local schema=""
  if [[ "$dsn_uri" =~ ^([^:]+):// ]]; then
    schema="${BASH_REMATCH[1]}"
    # Normalize schema names
    case "$schema" in
      postgres|postgresql|pgsql|pdo_pgsql)
        schema="postgres"
        ;;
      mysql|mariadb|pdo_mysql)
        schema="mysql"
        ;;
    esac
    # Export schema variable
    eval "export ${env_prefix}_${component_upper}_SCHEMA=\"$schema\""
    debug_log "parse_dsn_uri: detected schema=$schema from $dsn_uri"
  fi
  
  # Extract host, port, user, password, database name
  if [[ "$dsn_uri" =~ ^[^:]+://([^:@]+):([^@]+)@([^:/]+):([0-9]+)/(.+)$ ]]; then
    local user="${BASH_REMATCH[1]}"
    local password="${BASH_REMATCH[2]}"
    local host="${BASH_REMATCH[3]}"
    local port="${BASH_REMATCH[4]}"
    local dbname="${BASH_REMATCH[5]}"
    
    # Export variables using eval for dynamic names
    eval "export ${env_prefix}_${component_upper}_USER=\"$user\""
    eval "export ${env_prefix}_${component_upper}_PASSWORD=\"$password\""
    eval "export ${env_prefix}_${component_upper}_HOST=\"$host\""
    eval "export ${env_prefix}_${component_upper}_PORT=\"$port\""
    eval "export ${env_prefix}_${component_upper}_DBNAME=\"$dbname\""
    
    debug_log "parse_dsn_uri: extracted host=$host port=$port user=$user dbname=$dbname"
  elif [[ "$dsn_uri" =~ ^[^:]+://([^:@]+)@([^:/]+):([0-9]+)/(.+)$ ]]; then
    # No password case
    local user="${BASH_REMATCH[1]}"
    local host="${BASH_REMATCH[2]}"
    local port="${BASH_REMATCH[3]}"
    local dbname="${BASH_REMATCH[4]}"
    
    # Export variables using eval for dynamic names
    eval "export ${env_prefix}_${component_upper}_USER=\"$user\""
    eval "export ${env_prefix}_${component_upper}_HOST=\"$host\""
    eval "export ${env_prefix}_${component_upper}_PORT=\"$port\""
    eval "export ${env_prefix}_${component_upper}_DBNAME=\"$dbname\""
    
    debug_log "parse_dsn_uri: extracted host=$host port=$port user=$user dbname=$dbname (no password)"
  fi
}

# Parse compose flags into left/right arrays
# This is a simplified version for compose module
# Usage: parse_compose_flags "$@"
# Sets global arrays: args, left_flags, left_options, right_flags, right_options
parse_compose_flags() {
  args=()
  left_flags=()
  left_options=()
  right_flags=()
  right_options=()

  local i=0
  local saw_first_arg=false
  local args_input=("$@")

  while [[ $i -lt ${#args_input[@]} ]]; do
    arg="${args_input[$i]}"
    next="${args_input[$((i + 1))]:-}"

    if [[ "$arg" == --*=* ]]; then
      # --key=value format
      if [[ "$saw_first_arg" == false ]]; then
        left_options+=("$arg")
      else
        right_options+=("$arg")
      fi
      i=$((i + 1))

    elif [[ "$arg" == --* && "$next" != -* && -n "$next" ]]; then
      # --key value format
      if [[ "$saw_first_arg" == false ]]; then
        left_options+=("$arg" "$next")
      else
        right_options+=("$arg" "$next")
      fi
      i=$((i + 2))

    elif [[ "$arg" == -* ]]; then
      # Single flag -f, -d, etc.
      if [[ "$saw_first_arg" == false ]]; then
        left_flags+=("$arg")
      else
        right_flags+=("$arg")
      fi
      i=$((i + 1))

    else
      # Positional argument (command or service name)
      args+=("$arg")
      saw_first_arg=true
      i=$((i + 1))
    fi
  done
}

# Function to get compatible Node.js versions based on PHP version (sorted newest to oldest)
# Usage: get_compatible_node_versions "php_version"
# Example: get_compatible_node_versions "8.4" returns "22 20 18"
get_compatible_node_versions() {
  local php_ver="$1"
  case "$php_ver" in
    7.3) echo "16" ;;
    7.4) echo "18 16" ;;
    8.1) echo "22 20 18 16" ;;
    8.2|8.3|8.4) echo "22 20 18" ;;
    8.5) echo "24 22" ;;
    *) echo "22 20 18" ;;
  esac
}

# Resolve project family/type from composer.json and project structure
# Returns: oro, magento, laravel, symfony, yii, or generic
# Can be overridden with DC_ORO_PROJECT_FAMILY env var
project_family_resolve() {
  # Check for explicit override first
  if [[ -n "${DC_ORO_PROJECT_FAMILY:-}" ]]; then
    echo "${DC_ORO_PROJECT_FAMILY}"
    return 0
  fi
  
  # Check for explicit Oro override (backward compatibility)
  if [[ -n "${DC_ORO_IS_ORO_PROJECT:-}" ]]; then
    case "${DC_ORO_IS_ORO_PROJECT,,}" in
      1|true|yes)
        echo "oro"
        return 0
        ;;
      0|false|no)
        # Force generic if explicitly set to false
        echo "generic"
        return 0
        ;;
    esac
  fi
  
  local composer_file="${DC_ORO_APPDIR:-$PWD}/composer.json"
  local app_dir="${DC_ORO_APPDIR:-$PWD}"
  
  # If no composer.json, return generic
  if [[ ! -f "$composer_file" ]]; then
    echo "generic"
    return 0
  fi
  
  # Detect from composer.json dependencies
  # Priority order: Oro > Magento > Laravel > Symfony > Yii > Generic
  
  if command -v jq >/dev/null 2>&1; then
    # Use jq for reliable JSON parsing
    local packages
    packages=$(jq -r '.require // {} | keys[]' "$composer_file" 2>/dev/null || echo "")
    
    # Check for Oro ecosystem packages
    if echo "$packages" | grep -qE '^(oro/platform|oro/commerce|oro/crm|oro/customer-portal|marello/marello)$'; then
      echo "oro"
      return 0
    fi
    
    # Check for Magento packages
    if echo "$packages" | grep -qE '^(magento/product-|magento/magento2-|magento/framework|mage-os/mageos)'; then
      echo "magento"
      return 0
    fi
    
    # Check for Laravel
    if echo "$packages" | grep -qE '^laravel/framework$'; then
      echo "laravel"
      return 0
    fi
    
    # Check for Symfony
    if echo "$packages" | grep -qE '^symfony/symfony$'; then
      echo "symfony"
      return 0
    fi
    
    # Check for Yii
    if echo "$packages" | grep -qE '^(yiisoft/yii2|yiisoft/yii)$'; then
      echo "yii"
      return 0
    fi
  else
    # Fallback: grep-based detection (less reliable but works without jq)
    
    # Check for Oro ecosystem packages
    if grep -qE '"(oro/platform|oro/commerce|oro/crm|oro/customer-portal|marello/marello)"' "$composer_file" 2>/dev/null; then
      echo "oro"
      return 0
    fi
    
    # Check for Magento packages
    if grep -qE '"(magento/product-|magento/magento2-|magento/framework|mage-os/mageos)' "$composer_file" 2>/dev/null; then
      echo "magento"
      return 0
    fi
    
    # Check for Laravel
    if grep -qE '"laravel/framework"' "$composer_file" 2>/dev/null; then
      echo "laravel"
      return 0
    fi
    
    # Check for Symfony
    if grep -qE '"symfony/symfony"' "$composer_file" 2>/dev/null; then
      echo "symfony"
      return 0
    fi
    
    # Check for Yii
    if grep -qE '"(yiisoft/yii2|yiisoft/yii)"' "$composer_file" 2>/dev/null; then
      echo "yii"
      return 0
    fi
  fi
  
  # Check for project-specific files (fallback detection)
  
  # Check for bin/magento (Magento-specific)
  if [[ -f "${app_dir}/bin/magento" ]]; then
    echo "magento"
    return 0
  fi
  
  # Check for artisan (Laravel-specific)
  if [[ -f "${app_dir}/artisan" ]]; then
    echo "laravel"
    return 0
  fi
  
  # Check for bin/console (could be Symfony, but not if it's Oro)
  # Note: We already checked for Oro above, so if we get here and have bin/console, it's likely Symfony
  if [[ -f "${app_dir}/bin/console" ]]; then
    echo "symfony"
    return 0
  fi
  
  # Default: generic PHP project
  echo "generic"
  return 0
}

# Detect if current project is an Oro Platform application
# Returns 0 (true) if Oro project, 1 (false) otherwise
# Can be overridden with DC_ORO_IS_ORO_PROJECT env var
# Backward compatibility wrapper around project_family_resolve
is_oro_project() {
  local family
  family=$(project_family_resolve)
  if [[ "$family" == "oro" ]]; then
    return 0
  else
    return 1
  fi
}
