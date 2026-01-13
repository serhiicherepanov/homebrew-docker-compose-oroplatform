#!/bin/bash
# Docker/Compose Utilities Library
# Provides Docker Compose helpers, certificate setup, and service URL display

# Setup certificates synchronization
setup_project_certificates() {
  local project_crt_dir="${PWD}/.crt"
  local build_crt_dir="${DC_ORO_CONFIG_DIR}/docker/project-php-node-symfony/.crt"

  # Remove old certificates directory
  rm -rf "${build_crt_dir}"

  # Check if project has certificates
  if [[ -d "${project_crt_dir}" ]]; then
    local cert_count=$(find "${project_crt_dir}" -type f \( -name "*.crt" -o -name "*.pem" \) 2>/dev/null | wc -l)

    if [[ "${cert_count}" -gt 0 ]]; then
      msg_info "Found ${cert_count} certificate(s) in ${project_crt_dir}"
      echo "   Preparing project build context with custom certificates..."

      # Create .crt directory in build context
      mkdir -p "${build_crt_dir}"

      # Copy certificates to build context
      find "${project_crt_dir}" -type f \( -name "*.crt" -o -name "*.pem" \) -exec cp {} "${build_crt_dir}/" \;

      msg_ok "Certificates prepared for Docker build"
    else
      msg_info ".crt directory exists but contains no certificate files"
    fi
  else
    # Skip certificate message - building standard image silently
    true
  fi
}

# Generate compose.yml config file if needed
# Usage: generate_compose_config_if_needed "command"
generate_compose_config_if_needed() {
  local compose_cmd="$1"

  # CRITICAL: Normalize ORO_MAILER_ENCRYPTION before generating compose.yml
  # orodc is the source of truth - normalize any "null" or empty values to tls
  if [[ -z "${ORO_MAILER_ENCRYPTION:-}" ]] || [[ "${ORO_MAILER_ENCRYPTION:-}" == "" ]] || [[ "${ORO_MAILER_ENCRYPTION:-}" == "null" ]]; then
    export ORO_MAILER_ENCRYPTION="tls"
    debug_log "docker-utils: normalized ORO_MAILER_ENCRYPTION (set to tls)"
  fi

  # Generate config file only if it doesn't exist or if it's a management command
  if [[ ! -f "${DC_ORO_CONFIG_DIR}/compose.yml" ]] || [[ "$compose_cmd" =~ ^(up|down|purge|build|pull|push|restart|start|stop|kill|rm|create|ps|doctor)$ ]]; then
    # Generate compose.yml with all environment variables (ports, etc.) available
    eval "${DOCKER_COMPOSE_BIN_CMD} ${left_flags[*]} ${left_options[*]} config" > "${DC_ORO_CONFIG_DIR}/compose.yml" 2>/dev/null || true

    # Register environment after creating compose.yml
    if [[ -f "${DC_ORO_CONFIG_DIR}/compose.yml" ]] && [[ -n "${DC_ORO_NAME:-}" ]] && [[ -n "${DC_ORO_CONFIG_DIR:-}" ]]; then
      debug_log "compose.yml created: Registering environment name='${DC_ORO_NAME}' path='$PWD' config='${DC_ORO_CONFIG_DIR}'"
      register_environment "${DC_ORO_NAME}" "$PWD" "${DC_ORO_CONFIG_DIR}"
    fi
  fi
}

# Execute a generic compose command
# Usage: exec_compose_command "command" "services..."
exec_compose_command() {
  local docker_cmd="$1"
  shift
  local docker_services="$*"

  # For build command, use spinner
  if [[ "$docker_cmd" == "build" ]]; then
    full_cmd="${DOCKER_COMPOSE_BIN_CMD} ${left_flags[*]} ${left_options[*]} ${docker_cmd} ${right_flags[*]} ${right_options[*]} ${docker_services}"
    run_with_spinner "Building services" "$full_cmd"
    return $?
  fi

  # For down command, use spinner
  if [[ "$docker_cmd" == "down" ]]; then
    full_cmd="${DOCKER_COMPOSE_BIN_CMD} ${left_flags[*]} ${left_options[*]} ${docker_cmd} ${right_flags[*]} ${right_options[*]} ${docker_services}"
    run_with_spinner "Stopping services" "$full_cmd"
    return $?
  fi

  # For all other commands, run directly (variables are already exported)
  full_cmd="${DOCKER_COMPOSE_BIN_CMD} ${left_flags[*]} ${left_options[*]} ${docker_cmd} ${right_flags[*]} ${right_options[*]} ${docker_services}"
  eval "$full_cmd"
  return $?
}

# Convert bytes to human-readable format
# Usage: bytes_to_human <bytes>
bytes_to_human() {
  local bytes="$1"
  if [[ "$bytes" -ge 1073741824 ]]; then
    echo "$((bytes / 1073741824))GB"
  elif [[ "$bytes" -ge 1048576 ]]; then
    echo "$((bytes / 1048576))MB"
  elif [[ "$bytes" -ge 1024 ]]; then
    echo "$((bytes / 1024))KB"
  else
    echo "${bytes}B"
  fi
}

# Calculate project directory size in bytes
# Usage: calculate_project_size
# Returns: size in bytes (or 0 if error)
calculate_project_size() {
  local project_dir="${DC_ORO_APPDIR:-}"
  
  # Return 0 if project directory not set or doesn't exist
  if [[ -z "$project_dir" ]] || [[ ! -d "$project_dir" ]]; then
    echo "0"
    return 0
  fi
  
  # Use du -sb to get exact byte count
  local size_bytes
  size_bytes=$(du -sb "${project_dir}" 2>/dev/null | awk '{print $1}')
  
  # Return 0 if calculation failed
  if [[ -z "$size_bytes" ]] || ! [[ "$size_bytes" =~ ^[0-9]+$ ]]; then
    echo "0"
    return 0
  fi
  
  echo "$size_bytes"
}

# Check available disk space in Docker volume
# Usage: check_volume_disk_space <volume_name>
# Returns: available space in bytes (or 0 if error)
check_volume_disk_space() {
  local volume_name="$1"
  
  # Return 0 if volume name not provided
  if [[ -z "$volume_name" ]]; then
    echo "0"
    return 0
  fi
  
  # Check if volume exists
  if ! docker volume inspect "$volume_name" >/dev/null 2>&1; then
    # Volume doesn't exist - estimate from host disk space where Docker stores volumes
    # Docker volumes are typically stored in /var/lib/docker/volumes on Linux
    # or ~/Library/Containers/com.docker.docker/Data/vms/0/data/docker/volumes on macOS
    # For simplicity, check root filesystem available space
    local available_bytes
    available_bytes=$(df -B1 / 2>/dev/null | tail -1 | awk '{print $4}')
    if [[ -n "$available_bytes" ]] && [[ "$available_bytes" =~ ^[0-9]+$ ]]; then
      echo "$available_bytes"
      return 0
    fi
    echo "0"
    return 0
  fi
  
  # Use temporary container to check volume space
  local available_bytes
  available_bytes=$(docker run --rm -v "${volume_name}:/check" alpine df -B1 /check 2>/dev/null | tail -1 | awk '{print $4}')
  
  # Return 0 if check failed
  if [[ -z "$available_bytes" ]] || ! [[ "$available_bytes" =~ ^[0-9]+$ ]]; then
    echo "0"
    return 0
  fi
  
  echo "$available_bytes"
}

# Check available disk space in container filesystem
# Usage: check_container_disk_space <container_name> <mount_path>
# Returns: available space in bytes (or 0 if error)
check_container_disk_space() {
  local container_name="$1"
  local mount_path="${2:-/app}"
  
  # Return 0 if container name not provided
  if [[ -z "$container_name" ]]; then
    echo "0"
    return 0
  fi
  
  # Check if container is running
  if ! docker ps --format "{{.Names}}" 2>/dev/null | grep -q "^${container_name}$"; then
    # Container not running - check volume space instead
    local volume_name="${DC_ORO_NAME:-}_appcode"
    check_volume_disk_space "$volume_name"
    return 0
  fi
  
  # Use docker exec to check space in container
  local available_bytes
  available_bytes=$(docker exec "${container_name}" df -B1 "${mount_path}" 2>/dev/null | tail -1 | awk '{print $4}')
  
  # Return 0 if check failed
  if [[ -z "$available_bytes" ]] || ! [[ "$available_bytes" =~ ^[0-9]+$ ]]; then
    echo "0"
    return 0
  fi
  
  echo "$available_bytes"
}

# Check disk space for rsync sync mode
# Usage: check_rsync_sync_disk_space
# Returns: 0 if sufficient space, 1 if insufficient
check_rsync_sync_disk_space() {
  local mode="${DC_ORO_MODE:-default}"
  
  # Skip if not rsync mode
  if [[ "$mode" != "ssh" ]]; then
    return 0
  fi
  
  # Skip if bypass flag set
  if [[ "${DC_ORO_SKIP_DISK_CHECK:-}" == "1" ]]; then
    return 0
  fi
  
  msg_info "Checking disk space for rsync sync..."
  
  # Calculate required space (project size + 20% overhead)
  local project_bytes
  project_bytes=$(calculate_project_size)
  
  if [[ "$project_bytes" -eq 0 ]]; then
    msg_warning "Could not calculate project size, skipping disk space check"
    return 0
  fi
  
  local required_bytes=$((project_bytes * 120 / 100))
  
  # Check available space in target container or volume
  local available_bytes=0
  local container_name="${DC_ORO_NAME:-}_cli"
  
  # Try to check container space first
  if docker ps --format "{{.Names}}" 2>/dev/null | grep -q "^${container_name}$"; then
    available_bytes=$(check_container_disk_space "$container_name" "${DC_ORO_APPDIR:-/app}")
  else
    # Container not running, check volume space
    local volume_name="${DC_ORO_NAME:-}_appcode"
    available_bytes=$(check_volume_disk_space "$volume_name")
  fi
  
  if [[ "$available_bytes" -eq 0 ]]; then
    msg_warning "Could not check available disk space, skipping check"
    return 0
  fi
  
  # Compare required vs available
  if [[ "$available_bytes" -lt "$required_bytes" ]]; then
    local required_human=$(bytes_to_human "$required_bytes")
    local available_human=$(bytes_to_human "$available_bytes")
    msg_error "Insufficient disk space for rsync sync"
    msg_error "Required: ${required_human}, Available: ${available_human}"
    msg_error "Set DC_ORO_SKIP_DISK_CHECK=1 to bypass this check"
    return 1
  fi
  
  local required_human=$(bytes_to_human "$required_bytes")
  local available_human=$(bytes_to_human "$available_bytes")
  msg_ok "Disk space check passed (Required: ${required_human}, Available: ${available_human})"
  return 0
}

# Check disk space for mutagen sync mode
# Usage: check_mutagen_sync_disk_space
# Returns: 0 if sufficient space, 1 if insufficient
check_mutagen_sync_disk_space() {
  local mode="${DC_ORO_MODE:-default}"
  
  # Skip if not mutagen mode
  if [[ "$mode" != "mutagen" ]]; then
    return 0
  fi
  
  # Skip if bypass flag set
  if [[ "${DC_ORO_SKIP_DISK_CHECK:-}" == "1" ]]; then
    return 0
  fi
  
  msg_info "Checking disk space for mutagen sync..."
  
  # Calculate required space (project size + 20% overhead)
  local project_bytes
  project_bytes=$(calculate_project_size)
  
  if [[ "$project_bytes" -eq 0 ]]; then
    msg_warning "Could not calculate project size, skipping disk space check"
    return 0
  fi
  
  local required_bytes=$((project_bytes * 120 / 100))
  
  # Check available space in Docker volume
  local volume_name="${DC_ORO_NAME:-}_appcode"
  local available_bytes
  available_bytes=$(check_volume_disk_space "$volume_name")
  
  if [[ "$available_bytes" -eq 0 ]]; then
    msg_warning "Could not check available disk space, skipping check"
    return 0
  fi
  
  # Compare required vs available
  if [[ "$available_bytes" -lt "$required_bytes" ]]; then
    local required_human=$(bytes_to_human "$required_bytes")
    local available_human=$(bytes_to_human "$available_bytes")
    msg_error "Insufficient disk space for mutagen sync"
    msg_error "Required: ${required_human}, Available: ${available_human}"
    msg_error "Set DC_ORO_SKIP_DISK_CHECK=1 to bypass this check"
    return 1
  fi
  
  local required_human=$(bytes_to_human "$required_bytes")
  local available_human=$(bytes_to_human "$available_bytes")
  msg_ok "Disk space check passed (Required: ${required_human}, Available: ${available_human})"
  return 0
}

# Main disk space check function for sync operations
# Usage: check_sync_disk_space
# Returns: 0 if sufficient space or not needed, 1 if insufficient
check_sync_disk_space() {
  local mode="${DC_ORO_MODE:-default}"
  
  # Skip if default mode (no sync)
  if [[ "$mode" == "default" ]]; then
    return 0
  fi
  
  # Skip if bypass flag set
  if [[ "${DC_ORO_SKIP_DISK_CHECK:-}" == "1" ]]; then
    return 0
  fi
  
  # Check based on sync mode
  if [[ "$mode" == "mutagen" ]]; then
    check_mutagen_sync_disk_space
    return $?
  elif [[ "$mode" == "ssh" ]]; then
    check_rsync_sync_disk_space
    return $?
  fi
  
  # Unknown mode, skip check
  return 0
}

# Handle compose up command with separate build and start phases
# Usage: handle_compose_up
# Expects: docker_services, left_flags, left_options, right_flags, right_options
handle_compose_up() {
  # Get previous timing for statistics only
  prev_timing=$(get_previous_timing "up")

  # Check if we should skip build phase
  skip_build=false
  if [[ " ${right_flags[*]} " =~ " --no-build " ]]; then
    skip_build=true
  fi

  # If DEBUG or VERBOSE, run without timing wrapper
  if [[ -n "${DEBUG:-}" ]] || [[ -n "${VERBOSE:-}" ]]; then
    # Phase 1: Build images (unless --no-build is specified)
    if [[ "$skip_build" == "false" ]]; then
      build_cmd="${DOCKER_COMPOSE_BIN_CMD} ${left_flags[*]} ${left_options[*]} build ${docker_services}"
      eval "$build_cmd" || exit $?
    fi

    # Check disk space before starting sync operations (mutagen/rsync modes)
    if ! check_sync_disk_space; then
      exit 1
    fi

    # Phase 2: Start services
    up_flags=()
    for flag in "${right_flags[@]}"; do
      if [[ "$flag" != "--build" ]]; then
        up_flags+=("$flag")
      fi
    done

    up_cmd="${DOCKER_COMPOSE_BIN_CMD} ${left_flags[*]} ${left_options[*]} up --remove-orphans ${up_flags[*]} ${right_options[*]} ${docker_services}"
    eval "$up_cmd" || exit $?
    show_service_urls
    exit 0
  fi

  # Record start time for entire up operation
  up_start_time=$(date +%s)

  # Phase 1: Build images (unless --no-build is specified)
  if [[ "$skip_build" == "false" ]]; then
    build_cmd="${DOCKER_COMPOSE_BIN_CMD} ${left_flags[*]} ${left_options[*]} build ${docker_services}"
    DC_ORO_NAME="$DC_ORO_NAME" run_with_spinner "Building services" "$build_cmd" || exit $?
  fi

  # Check disk space before starting sync operations (mutagen/rsync modes)
  # This check happens after build but before containers start
  if ! check_sync_disk_space; then
    exit 1
  fi

  # Phase 2: Start services
  up_flags=()
  has_wait_flag=false
  for flag in "${right_flags[@]}"; do
    if [[ "$flag" != "--build" ]]; then
      up_flags+=("$flag")
      if [[ "$flag" == "--wait" ]]; then
        has_wait_flag=true
      fi
    fi
  done

  # Add --wait flag if -d is present and --wait is not already there
  # This ensures we wait for health checks before returning
  if [[ " ${up_flags[*]} " =~ " -d " ]] && [[ "$has_wait_flag" == "false" ]]; then
    up_flags+=("--wait")
  fi

  up_cmd="${DOCKER_COMPOSE_BIN_CMD} ${left_flags[*]} ${left_options[*]} up --remove-orphans ${up_flags[*]} ${right_options[*]} ${docker_services}"
  run_with_spinner "Starting services" "$up_cmd" || exit $?

  # Calculate total up time and save
  up_end_time=$(date +%s)
  up_duration=$((up_end_time - up_start_time))

  # Save timing
  save_timing "up" "$up_duration"

  msg_ok "Services started in ${up_duration}s"

  show_service_urls
  exit 0
}

# Execute command in CLI container
# Usage: exec_in_cli "command" "args..."
exec_in_cli() {
  local cmd="$1"
  shift
  local cmd_args="$*"

  # Run command in CLI container
  ${DOCKER_COMPOSE_BIN_CMD} run --rm cli "$cmd" $cmd_args
}

# Show service URLs after successful 'up' command
show_service_urls() {
  echo "" >&2

  # Check if proxy container is running
  local proxy_running=false
  if ${DOCKER_BIN} ps --filter "name=proxy" --filter "status=running" --format "{{.Names}}" 2>/dev/null | grep -q "^proxy$"; then
    proxy_running=true
  fi

  # Show domain URL if proxy is running
  if [[ "$proxy_running" == "true" ]]; then
    printf "\033[1;32m[${DC_ORO_NAME}] Application: https://${DC_ORO_NAME}.docker.local\033[0m\n"
    echo "" >&2
  fi

  # Always show localhost URLs
  printf "\033[0;37m[${DC_ORO_NAME}] Application: http://localhost:${DC_ORO_PORT_NGINX}\033[0m\n"
  printf "\033[0;37m[${DC_ORO_NAME}] Mailhog: http://localhost:${DC_ORO_PORT_MAIL_WEBGUI}\033[0m\n"
  printf "\033[0;37m[${DC_ORO_NAME}] Elasticsearch: http://localhost:${DC_ORO_PORT_SEARCH}\033[0m\n"
  printf "\033[0;37m[${DC_ORO_NAME}] Mq: http://localhost:${DC_ORO_PORT_MQ}\033[0m\n"

  if [[ "${DC_ORO_DATABASE_SCHEMA}" == "pdo_pgsql" ]] || [[ "${DC_ORO_DATABASE_SCHEMA}" == "postgres" ]] || [[ "${DC_ORO_DATABASE_SCHEMA}" == "postgresql" ]];then
    printf "\033[0;37m[${DC_ORO_NAME}] Database: 127.0.0.1:${DC_ORO_PORT_PGSQL}\033[0m\n"
  elif [[ "${DC_ORO_DATABASE_SCHEMA}" == "pdo_mysql" ]] || [[ "${DC_ORO_DATABASE_SCHEMA}" == "mysql" ]];then
    printf "\033[0;37m[${DC_ORO_NAME}] Database: 127.0.0.1:${DC_ORO_PORT_MYSQL}\033[0m\n"
  fi

  printf "\033[0;37m[${DC_ORO_NAME}] SSH: 127.0.0.1:${DC_ORO_PORT_SSH}\033[0m\n"

  # Show proxy hint if not running
  if [[ "$proxy_running" == "false" ]]; then
    echo "" >&2
    msg_info "Want to use custom domains and SSL? Start the proxy:"
    msg_info "  orodc proxy up -d"
    msg_info "  orodc proxy install-certs"
    msg_info ""
    msg_info "Then access via: https://${DC_ORO_NAME}.docker.local"
  fi
}
