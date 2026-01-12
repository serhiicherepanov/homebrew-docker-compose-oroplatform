#!/bin/bash
# Port Manager Library
# Wrapper for orodc-find_free_port utility

# Find and export all service ports in batch mode
# Usage: find_and_export_ports "project_name" "config_dir"
find_and_export_ports() {
  local project_name="$1"
  local config_dir="$2"

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
    ssh "${DC_ORO_PORT_PREFIX}22")

  # Parse batch results and export individual port variables
  while IFS=':' read -r service port; do
    case "$service" in
      nginx)
        export DC_ORO_PORT_NGINX="$port"
        ;;
      xhgui)
        export DC_ORO_PORT_XHGUI="$port"
        ;;
      database)
        if [[ -z "$DC_ORO_PORT_MYSQL" ]]; then
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
