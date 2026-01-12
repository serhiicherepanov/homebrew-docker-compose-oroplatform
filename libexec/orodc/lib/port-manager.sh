#!/bin/bash
# Port Manager Library
# Wrapper for orodc-find_free_port utility

# Find and export all service ports in batch mode
# Usage: find_and_export_ports "project_name" "config_dir"
find_and_export_ports() {
  local project_name="$1"
  local config_dir="$2"

  # Always set ports with prefix first (base ports)
  export DC_ORO_PORT_NGINX="${DC_ORO_PORT_NGINX:-${DC_ORO_PORT_PREFIX}80}"
  export DC_ORO_PORT_XHGUI="${DC_ORO_PORT_XHGUI:-${DC_ORO_PORT_PREFIX}81}"
  export DC_ORO_PORT_MYSQL="${DC_ORO_PORT_MYSQL:-${DC_ORO_PORT_PREFIX}06}"
  export DC_ORO_PORT_PGSQL="${DC_ORO_PORT_PGSQL:-${DC_ORO_PORT_PREFIX}32}"
  export DC_ORO_PORT_SEARCH="${DC_ORO_PORT_SEARCH:-${DC_ORO_PORT_PREFIX}92}"
  export DC_ORO_PORT_MQ="${DC_ORO_PORT_MQ:-${DC_ORO_PORT_PREFIX}72}"
  export DC_ORO_PORT_REDIS="${DC_ORO_PORT_REDIS:-${DC_ORO_PORT_PREFIX}79}"
  export DC_ORO_PORT_MAIL_WEBGUI="${DC_ORO_PORT_MAIL_WEBGUI:-${DC_ORO_PORT_PREFIX}25}"
  export DC_ORO_PORT_SSH="${DC_ORO_PORT_SSH:-${DC_ORO_PORT_PREFIX}22}"

  # Try to find free ports using orodc-find_free_port if available
  if ! command -v orodc-find_free_port >/dev/null 2>&1; then
    debug_log "find_and_export_ports: orodc-find_free_port not found, using prefix-based ports"
    return 0
  fi

  debug_log "find_and_export_ports: project=${project_name}, config_dir=${config_dir}, prefix=${DC_ORO_PORT_PREFIX}"

  # Use batch port resolution for better performance
  BATCH_PORTS=$(orodc-find_free_port --batch "${project_name}" "$config_dir" \
    nginx "${DC_ORO_PORT_PREFIX}80" \
    xhgui "${DC_ORO_PORT_PREFIX}81" \
    database "${DC_ORO_PORT_PREFIX}06" \
    database "${DC_ORO_PORT_PREFIX}32" \
    search "${DC_ORO_PORT_PREFIX}92" \
    mq "${DC_ORO_PORT_PREFIX}72" \
    redis "${DC_ORO_PORT_PREFIX}79" \
    mail "${DC_ORO_PORT_PREFIX}25" \
    ssh "${DC_ORO_PORT_PREFIX}22" 2>&1)
  
  local exit_code=$?
  
  if [[ $exit_code -ne 0 ]] || [[ -z "$BATCH_PORTS" ]]; then
    debug_log "find_and_export_ports: orodc-find_free_port failed, using prefix-based ports"
    debug_log "find_and_export_ports: exit_code=$exit_code, output='$BATCH_PORTS'"
    return 0
  fi

  debug_log "find_and_export_ports: batch results='$BATCH_PORTS'"

  # Parse batch results and override with found free ports
  while IFS=':' read -r service port; do
    [[ -z "$service" ]] && continue
    [[ -z "$port" ]] && continue
    
    debug_log "find_and_export_ports: setting DC_ORO_PORT_${service^^}=$port"
    
    case "$service" in
      nginx)
        export DC_ORO_PORT_NGINX="$port"
        ;;
      xhgui)
        export DC_ORO_PORT_XHGUI="$port"
        ;;
      database)
        if [[ -z "$DC_ORO_PORT_MYSQL" ]] || [[ "$DC_ORO_PORT_MYSQL" == "${DC_ORO_PORT_PREFIX}06" ]]; then
          export DC_ORO_PORT_MYSQL="$port"
        else
          export DC_ORO_PORT_PGSQL="$port"
        fi
        ;;
      search)
        export DC_ORO_PORT_SEARCH="$port"
        ;;
      mq)
        export DC_ORO_PORT_MQ="$port"
        ;;
      redis)
        export DC_ORO_PORT_REDIS="$port"
        ;;
      mail)
        export DC_ORO_PORT_MAIL_WEBGUI="$port"
        ;;
      ssh)
        export DC_ORO_PORT_SSH="$port"
        ;;
    esac
  done <<< "$BATCH_PORTS"
  
  debug_log "find_and_export_ports: final ports - MQ=${DC_ORO_PORT_MQ}, SEARCH=${DC_ORO_PORT_SEARCH}, REDIS=${DC_ORO_PORT_REDIS}"
}

# Find a single port for a specific service
# Usage: find_single_port "project_name" "config_dir" "service_name" "default_port"
# Returns: port number
find_single_port() {
  local project_name="$1"
  local config_dir="$2"
  local service_name="$3"
  local default_port="$4"

  orodc-find_free_port "$project_name" "$config_dir" "$service_name" "$default_port"
}
