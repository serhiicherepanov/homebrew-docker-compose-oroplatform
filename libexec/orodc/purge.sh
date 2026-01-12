#!/bin/bash
set -e
if [ "$DEBUG" ]; then set -x; fi

# Determine script directory and source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/environment.sh"

# Check that we're in a project
check_in_project || exit 1

msg_warning "This will remove all containers, volumes, and networks for this project"
if ! confirm_yes_no "Are you sure you want to purge everything?"; then
  msg_info "Purge cancelled"
  exit 0
fi

# Stop and remove containers with spinner
purge_cmd="${DOCKER_COMPOSE_BIN_CMD} down -v --remove-orphans"
run_with_spinner "Stopping and removing containers" "$purge_cmd" || exit $?

# Remove entire configuration directory (includes compose.yml and all other files)
# Try multiple possible locations to ensure we delete the correct directory
config_dirs_to_remove=()
config_dir_abs=""

# Primary location from DC_ORO_CONFIG_DIR
if [[ -n "${DC_ORO_CONFIG_DIR:-}" ]] && [[ -d "${DC_ORO_CONFIG_DIR}" ]]; then
  config_dir_abs=$(realpath "${DC_ORO_CONFIG_DIR}" 2>/dev/null || echo "${DC_ORO_CONFIG_DIR}")
  config_dirs_to_remove+=("${config_dir_abs}")
fi

# Alternative locations (in case DC_ORO_CONFIG_DIR was not set correctly)
if [[ -n "${DC_ORO_NAME:-}" ]]; then
  alt_dir1="${HOME}/.docker-compose-oroplatform/${DC_ORO_NAME}"
  alt_dir2="${HOME}/.orodc/${DC_ORO_NAME}"
  
  if [[ -d "${alt_dir1}" ]]; then
    alt_dir1_abs=$(realpath "${alt_dir1}" 2>/dev/null || echo "${alt_dir1}")
    if [[ "${alt_dir1_abs}" != "${config_dir_abs}" ]]; then
      config_dirs_to_remove+=("${alt_dir1_abs}")
    fi
  fi
  if [[ -d "${alt_dir2}" ]]; then
    alt_dir2_abs=$(realpath "${alt_dir2}" 2>/dev/null || echo "${alt_dir2}")
    if [[ "${alt_dir2_abs}" != "${config_dir_abs}" ]]; then
      config_dirs_to_remove+=("${alt_dir2_abs}")
    fi
  fi
fi

# Remove all found directories
for dir in "${config_dirs_to_remove[@]}"; do
  if [[ -d "${dir}" ]]; then
    run_with_spinner "Removing configuration directory" "rm -rf \"${dir}\"" || exit $?
    
    # Verify deletion succeeded
    if [[ -d "${dir}" ]]; then
      msg_error "Failed to remove configuration directory: ${dir}"
      exit 1
    fi
  fi
done

# Remove environment from registry
if [[ -n "${DC_ORO_NAME:-}" ]]; then
  unregister_environment "${DC_ORO_NAME}" 2>/dev/null || true
fi

msg_ok "Project purged successfully"
