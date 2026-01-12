#!/bin/bash
set -e
if [ "$DEBUG" ]; then set -x; fi

# Determine script directory and source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/environment.sh"

# Check if running in interactive mode
is_interactive() {
  [ -t 0 ] && [ -t 1 ]
}


# Update .env.orodc file
update_env_file() {
  local key="$1"
  local value="$2"
  local env_file="${DC_ORO_APPDIR}/.env.orodc"
  
  if [[ ! -f "$env_file" ]]; then
    touch "$env_file"
  fi
  
  # Remove existing line if present
  if grep -q "^${key}=" "$env_file" 2>/dev/null; then
    if [[ "$(uname)" == "Darwin" ]]; then
      sed -i '' "/^${key}=/d" "$env_file"
    else
      sed -i "/^${key}=/d" "$env_file"
    fi
  fi
  
  # Add new line
  echo "${key}=${value}" >> "$env_file"
}

# Manage domains - interactive mode
manage_domains_interactive() {
  local env_file="${DC_ORO_APPDIR}/.env.orodc"
  local current_hosts="${DC_ORO_EXTRA_HOSTS:-}"
  local domains=()
  
  # Parse current domains
  if [[ -n "$current_hosts" ]]; then
    IFS=',' read -ra domains <<< "$current_hosts"
  fi
  
  echo "" >&2
  msg_highlight "Domain Management for: ${DC_ORO_NAME}" >&2
  echo "" >&2
  
  if [[ ${#domains[@]} -gt 0 ]]; then
    msg_info "Current extra domains:" >&2
    local i=1
    for domain in "${domains[@]}"; do
      domain=$(echo "$domain" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      if [[ -n "$domain" ]]; then
        echo "  $i) $domain" >&2
        i=$((i + 1))
      fi
    done
  else
    msg_info "No extra domains configured." >&2
  fi
  
  echo "" >&2
  
  # Interactive loop
  while true; do
    echo -n "Add domain (or 'remove <domain>' to delete, 'done' to finish): " >&2
    read -r input
    
    if [[ -z "$input" ]]; then
      continue
    fi
    
    if [[ "$input" == "done" ]] || [[ "$input" == "q" ]]; then
      break
    fi
    
    if [[ "$input" =~ ^remove\ (.+)$ ]]; then
      # Remove domain
      local domain_to_remove="${BASH_REMATCH[1]}"
      domain_to_remove=$(echo "$domain_to_remove" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      
      local new_domains=()
      for domain in "${domains[@]}"; do
        domain=$(echo "$domain" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ "$domain" != "$domain_to_remove" ]] && [[ -n "$domain" ]]; then
          new_domains+=("$domain")
        fi
      done
      domains=("${new_domains[@]}")
      
      msg_ok "Removed domain: $domain_to_remove" >&2
    else
      # Add domain
      local new_domain=$(echo "$input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      
      if [[ -z "$new_domain" ]]; then
        continue
      fi
      
      # Check if already exists
      local exists=false
      for domain in "${domains[@]}"; do
        domain=$(echo "$domain" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ "$domain" == "$new_domain" ]]; then
          exists=true
          break
        fi
      done
      
      if [[ "$exists" == "false" ]]; then
        domains+=("$new_domain")
        msg_ok "Added domain: $new_domain" >&2
      else
        msg_warning "Domain already exists: $new_domain" >&2
      fi
    fi
    
    echo "" >&2
    if [[ ${#domains[@]} -gt 0 ]]; then
      msg_info "Current domains:" >&2
      for domain in "${domains[@]}"; do
        domain=$(echo "$domain" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -n "$domain" ]]; then
          echo "  - $domain" >&2
        fi
      done
      echo "" >&2
    fi
  done
  
  # Update .env.orodc
  if [[ ${#domains[@]} -gt 0 ]]; then
    local domains_str=$(IFS=','; echo "${domains[*]}")
    update_env_file "DC_ORO_EXTRA_HOSTS" "$domains_str"
    msg_ok "Updated domains in .env.orodc" >&2
  else
    # Remove if empty
    if grep -q "^DC_ORO_EXTRA_HOSTS=" "$env_file" 2>/dev/null; then
      if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "/^DC_ORO_EXTRA_HOSTS=/d" "$env_file"
      else
        sed -i "/^DC_ORO_EXTRA_HOSTS=/d" "$env_file"
      fi
      msg_ok "Removed domains from .env.orodc" >&2
    fi
  fi
  
  return 0
}

# Manage domains - non-interactive mode
manage_domains_noninteractive() {
  local action="${1:-list}"
  shift || true
  
  case "$action" in
    list)
      local current_hosts="${DC_ORO_EXTRA_HOSTS:-}"
      if [[ -n "$current_hosts" ]]; then
        echo "$current_hosts" | tr ',' '\n'
      else
        echo ""
      fi
      ;;
    add)
      local domain="$1"
      if [[ -z "$domain" ]]; then
        msg_error "Domain name required"
        exit 1
      fi
      
      local current_hosts="${DC_ORO_EXTRA_HOSTS:-}"
      local domains=()
      
      if [[ -n "$current_hosts" ]]; then
        IFS=',' read -ra domains <<< "$current_hosts"
      fi
      
      # Check if already exists
      for existing in "${domains[@]}"; do
        existing=$(echo "$existing" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ "$existing" == "$domain" ]]; then
          msg_warning "Domain already exists: $domain"
          exit 0
        fi
      done
      
      domains+=("$domain")
      local domains_str=$(IFS=','; echo "${domains[*]}")
      update_env_file "DC_ORO_EXTRA_HOSTS" "$domains_str"
      msg_ok "Added domain: $domain"
      ;;
    remove)
      local domain="$1"
      if [[ -z "$domain" ]]; then
        msg_error "Domain name required"
        exit 1
      fi
      
      local current_hosts="${DC_ORO_EXTRA_HOSTS:-}"
      local domains=()
      
      if [[ -n "$current_hosts" ]]; then
        IFS=',' read -ra domains <<< "$current_hosts"
      fi
      
      local new_domains=()
      local found=false
      for existing in "${domains[@]}"; do
        existing=$(echo "$existing" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ "$existing" != "$domain" ]] && [[ -n "$existing" ]]; then
          new_domains+=("$existing")
        else
          found=true
        fi
      done
      
      if [[ "$found" == "false" ]]; then
        msg_warning "Domain not found: $domain"
        exit 1
      fi
      
      if [[ ${#new_domains[@]} -gt 0 ]]; then
        local domains_str=$(IFS=','; echo "${new_domains[*]}")
        update_env_file "DC_ORO_EXTRA_HOSTS" "$domains_str"
      else
        local env_file="${DC_ORO_APPDIR}/.env.orodc"
        if grep -q "^DC_ORO_EXTRA_HOSTS=" "$env_file" 2>/dev/null; then
          if [[ "$(uname)" == "Darwin" ]]; then
            sed -i '' "/^DC_ORO_EXTRA_HOSTS=/d" "$env_file"
          else
            sed -i "/^DC_ORO_EXTRA_HOSTS=/d" "$env_file"
          fi
        fi
      fi
      
      msg_ok "Removed domain: $domain"
      ;;
    set)
      local domains_str="$1"
      if [[ -z "$domains_str" ]]; then
        msg_error "Domain list required"
        exit 1
      fi
      
      update_env_file "DC_ORO_EXTRA_HOSTS" "$domains_str"
      msg_ok "Set domains: $domains_str"
      ;;
    *)
      msg_error "Unknown action: $action"
      msg_info "Available actions: list, add, remove, set"
      exit 1
      ;;
  esac
}

# Configure URL - interactive mode
configure_url_interactive() {
  local current_url="${DC_ORO_URL:-https://${DC_ORO_NAME}.docker.local}"
  
  echo "" >&2
  msg_highlight "Configure Application URL for: ${DC_ORO_NAME}" >&2
  echo "" >&2
  msg_info "Current URL: $current_url" >&2
  echo "" >&2
  echo -n "Enter new URL [default: $current_url]: " >&2
  read -r new_url
  
  if [[ -z "$new_url" ]]; then
    new_url="$current_url"
  fi
  
  # Validate URL format
  if [[ ! "$new_url" =~ ^https?:// ]]; then
    msg_error "Invalid URL format. URL must start with http:// or https://"
    return 1
  fi
  
  update_env_file "DC_ORO_URL" "$new_url"
  msg_ok "Updated URL: $new_url" >&2
  return 0
}

# Configure URL - non-interactive mode
configure_url_noninteractive() {
  local url="$1"
  
  if [[ -z "$url" ]]; then
    # Show current URL
    echo "${DC_ORO_URL:-https://${DC_ORO_NAME}.docker.local}"
    return 0
  fi
  
  # Validate URL format
  if [[ ! "$url" =~ ^https?:// ]]; then
    msg_error "Invalid URL format. URL must start with http:// or https://"
    exit 1
  fi
  
  update_env_file "DC_ORO_URL" "$url"
  msg_ok "Updated URL: $url"
}

# Main function
main() {
  local subcommand="${1:-}"
  shift || true
  local exit_code=0
  
  if ! check_in_project; then
    exit 1
  fi
  
  set +e
  case "$subcommand" in
    domains)
      if is_interactive; then
        manage_domains_interactive
        exit_code=$?
      else
        manage_domains_noninteractive "$@"
        exit_code=$?
      fi
      ;;
    url)
      if is_interactive; then
        configure_url_interactive
        exit_code=$?
      else
        configure_url_noninteractive "$@"
        exit_code=$?
      fi
      ;;
    *)
      msg_error "Unknown configuration command: ${subcommand:-<none>}"
      echo "" >&2
      msg_info "Available commands:" >&2
      echo "  orodc conf domains [list|add|remove|set] [args...]" >&2
      echo "  orodc conf url [url]" >&2
      set -e
      exit 1
      ;;
  esac
  set -e
  exit $exit_code
}

main "$@"
