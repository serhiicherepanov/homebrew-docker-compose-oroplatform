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

  # Fix ownership for empty directories before running containers (run, exec commands)
  # This ensures that empty directories have correct owner when containers are started
  if [[ "$docker_cmd" == "run" ]] || [[ "$docker_cmd" == "exec" ]]; then
    fix_empty_directory_ownership
  fi

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

# Fix ownership for empty directories before starting containers
# ROOT CAUSE: When bind mounting an empty directory, Docker may show it as root-owned
# inside the container even if it's correctly owned on the host. This happens because
# empty directories don't have files to inherit ownership from.
# SOLUTION: Create a hidden marker file in empty directories to preserve ownership.
# This is a known Docker behavior - empty directories need at least one file to maintain
# correct ownership across bind mounts.
# Usage: fix_empty_directory_ownership
fix_empty_directory_ownership() {
  if [[ -z "${DC_ORO_APPDIR:-}" ]] || [[ ! -d "${DC_ORO_APPDIR}" ]]; then
    return 0
  fi

  # Only fix on Linux (macOS handles this differently)
  if [[ "$(uname)" != "Linux" ]]; then
    return 0
  fi

  # Check if directory is truly empty (no files at all, including hidden ones)
  local dir_contents=$(ls -A "${DC_ORO_APPDIR}" 2>/dev/null || echo "")
  if [[ -z "$dir_contents" ]]; then
    # Directory is empty - create a hidden marker file to preserve ownership
    # This prevents Docker from showing the directory as root-owned inside container
    # Container will remove this marker file on startup
    local marker_file="${DC_ORO_APPDIR}/.orodc.marker"
    
    # Get target UID/GID from environment or use current user's
    local target_uid="${DC_ORO_PHP_UID:-$(id -u)}"
    local target_gid="${DC_ORO_PHP_GID:-$(id -g)}"
    
    # Create marker file (this will be owned by current user)
    # Use explicit error handling to ensure file is created
    if ! touch "${marker_file}" 2>/dev/null; then
      # If touch fails, try with sudo
      if command -v sudo >/dev/null 2>&1; then
        sudo -n touch "${marker_file}" 2>/dev/null || {
          debug_log "docker-utils: could not create marker file ${marker_file} (permissions required)"
          return 0
        }
      else
        debug_log "docker-utils: could not create marker file ${marker_file} (permissions required)"
        return 0
      fi
    fi
    
    # Ensure marker file exists before proceeding
    if [[ ! -f "${marker_file}" ]]; then
      debug_log "docker-utils: marker file ${marker_file} was not created"
      return 0
    fi
    
    # Ensure marker file and directory have correct ownership
    local current_uid=$(stat -c '%u' "${DC_ORO_APPDIR}" 2>/dev/null || echo "")
    local current_gid=$(stat -c '%g' "${DC_ORO_APPDIR}" 2>/dev/null || echo "")
    
    # Fix ownership if needed
    if [[ -z "$current_uid" ]] || [[ -z "$current_gid" ]] || \
       [[ "$current_uid" == "0" ]] || [[ "$current_gid" == "0" ]] || \
       [[ "$current_uid" != "$target_uid" ]] || [[ "$current_gid" != "$target_gid" ]]; then
      if chown "${target_uid}:${target_gid}" "${DC_ORO_APPDIR}" "${marker_file}" 2>/dev/null; then
        debug_log "docker-utils: created marker file ${marker_file} and fixed ownership for empty directory ${DC_ORO_APPDIR} from ${current_uid}:${current_gid} to ${target_uid}:${target_gid}"
      elif command -v sudo >/dev/null 2>&1 && sudo -n chown "${target_uid}:${target_gid}" "${DC_ORO_APPDIR}" "${marker_file}" 2>/dev/null; then
        debug_log "docker-utils: created marker file ${marker_file} and fixed ownership for empty directory ${DC_ORO_APPDIR} from ${current_uid}:${current_gid} to ${target_uid}:${target_gid} (using sudo)"
      else
        debug_log "docker-utils: created marker file ${marker_file} but could not fix ownership for empty directory ${DC_ORO_APPDIR} (permissions required)"
      fi
    else
      # Ownership is correct, but ensure marker file has correct ownership too
      chown "${target_uid}:${target_gid}" "${marker_file}" 2>/dev/null || true
      debug_log "docker-utils: created marker file ${marker_file} for empty directory ${DC_ORO_APPDIR}"
    fi
  fi
}

# Handle compose up command with separate build and start phases
# Usage: handle_compose_up
# Expects: docker_services, left_flags, left_options, right_flags, right_options
handle_compose_up() {
  # Fix ownership for empty directories before starting containers
  fix_empty_directory_ownership

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
