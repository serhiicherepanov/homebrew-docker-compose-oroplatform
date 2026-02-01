#!/bin/bash
set -e
if [ "$DEBUG" ]; then set -x; fi

# Determine script directory and source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/ui.sh"
source "${SCRIPT_DIR}/../lib/environment.sh"
source "${SCRIPT_DIR}/../lib/system-prompt.sh"

# Prepare project environment
prepare_project_environment

# Check if Cursor CLI is installed
# Cursor CLI command is 'agent', not 'cursor'
CURSOR_BIN=$(resolve_bin "agent" "Cursor CLI is required. Install from: https://cursor.com/docs/cli/installation")

# Main execution
main() {
  # Detect CMS type
  local cms_type=$(get_cms_type)
  msg_info "Detected CMS type: $cms_type"
  
  # Get documentation context
  local doc_context=$(get_documentation_context)
  if [[ -f "$doc_context" ]]; then
    msg_info "Using documentation: $doc_context"
  else
    msg_info "Using orodc help output as documentation"
  fi
  
  # Get project name
  local project_name=$(get_project_name)
  
  # Create AGENTS.md file in config directory (DC_ORO_CONFIG_DIR or ~/.orodc/{project_name})
  local agents_dir="${DC_ORO_CONFIG_DIR:-${HOME}/.orodc/${project_name}}"
  local agents_file="${agents_dir}/AGENTS.md"
  mkdir -p "$agents_dir"
  
  # Generate system prompt file (AGENTS.md) which references orodc agents commands
  local agents_source_dir="${SCRIPT_DIR}/../agents"
  generate_system_prompt "$cms_type" "$doc_context" "$agents_source_dir" > "$agents_file"
  msg_info "Created system prompt file: $agents_file"
  
  # Track temp files for cleanup (only help output, not AGENTS.md - it should persist)
  local temp_files=()
  if [[ ! -f "$doc_context" ]] || [[ "$doc_context" == /tmp/orodc-help.* ]]; then
    temp_files+=("$doc_context")
  fi
  
  # Cleanup temp files on exit (AGENTS.md is not in temp_files, so it will persist)
  if [[ ${#temp_files[@]} -gt 0 ]]; then
    cleanup_temp_files() {
      rm -f "${temp_files[@]}"
    }
    trap cleanup_temp_files EXIT
  fi
  
  # Execute Cursor CLI with all passed arguments
  # Cursor CLI accepts [query..] as positional arguments for initial prompt
  # System prompt is passed via .cursorrules file in project directory
  msg_info "Launching Cursor CLI with CMS type: $cms_type"
  
  # Export Docker and project context
  export_environment_context
  
  # Create .cursorrules file in config directory (not in project directory)
  # Cursor CLI reads .cursorrules from the current working directory, so we create a symlink
  local project_dir="${DC_ORO_APPDIR:-$PWD}"
  local config_dir="${DC_ORO_CONFIG_DIR:-${HOME}/.orodc/${project_name}}"
  local cursorrules_config_file="${config_dir}/.cursorrules"
  local cursorrules_project_file="${project_dir}/.cursorrules"
  
  # Ensure config directory exists
  mkdir -p "$config_dir"
  
  # Backup existing .cursorrules in project if it exists and is not a symlink
  local cursorrules_backup=""
  if [[ -f "$cursorrules_project_file" ]] && [[ ! -L "$cursorrules_project_file" ]]; then
    cursorrules_backup="${cursorrules_project_file}.orodc-backup-$(date +%s)"
    cp "$cursorrules_project_file" "$cursorrules_backup"
    msg_info "Backed up existing .cursorrules to: $cursorrules_backup"
  fi
  
  # Backup existing .cursorrules in config directory if it exists
  local cursorrules_config_backup=""
  if [[ -f "$cursorrules_config_file" ]]; then
    cursorrules_config_backup="${cursorrules_config_file}.orodc-backup-$(date +%s)"
    cp "$cursorrules_config_file" "$cursorrules_config_backup"
    msg_info "Backed up existing .cursorrules in config to: $cursorrules_config_backup"
  fi
  
  # Write system prompt to .cursorrules file in config directory
  generate_system_prompt "$cms_type" "$doc_context" "$agents_source_dir" > "$cursorrules_config_file"
  msg_info "Created .cursorrules file in config directory: $cursorrules_config_file"
  
  # Create symlink in project directory pointing to config directory
  # Remove existing file/symlink if it exists
  if [[ -e "$cursorrules_project_file" ]]; then
    rm -f "$cursorrules_project_file"
  fi
  # Create relative symlink if possible, otherwise absolute
  local symlink_target
  if [[ "$project_dir" == "$HOME"* ]] && [[ "$config_dir" == "$HOME"* ]]; then
    # Try to create relative symlink
    local rel_path=$(realpath --relative-to="$project_dir" "$cursorrules_config_file" 2>/dev/null || echo "$cursorrules_config_file")
    ln -sf "$rel_path" "$cursorrules_project_file"
  else
    # Use absolute path
    ln -sf "$cursorrules_config_file" "$cursorrules_project_file"
  fi
  msg_info "Created symlink: $cursorrules_project_file -> $cursorrules_config_file"
  
  # Pass context via environment variables (for reference)
  export CURSOR_SYSTEM_PROMPT="$(cat "$agents_file")"
  export CURSOR_CMS_TYPE="$cms_type"
  export CURSOR_DOC_CONTEXT="$doc_context"
  
  # Build Cursor CLI arguments
  # Cursor CLI uses positional arguments for user prompt
  local cursor_args=()
  
  # Change to project directory if available (Cursor CLI works in current directory)
  if [[ -n "${DC_ORO_APPDIR:-}" ]] && [[ -d "${DC_ORO_APPDIR}" ]]; then
    cd "${DC_ORO_APPDIR}" || true
  fi
  
  # If user provided arguments, pass them as positional prompt arguments
  # System prompt is already set via .cursorrules file
  if [[ $# -gt 0 ]]; then
    # User provided a prompt - pass all arguments as positional prompt
    cursor_args+=("$@")
  fi
  
  # Execute cursor with arguments
  # System prompt is set via .cursorrules file in project directory
  # User prompt (if provided) is passed as positional arguments
  
  # Print command being executed (dark gray text)
  msg_debug "Executing: $CURSOR_BIN ${cursor_args[*]}"
  msg_debug "System prompt file (config): $cursorrules_config_file"
  msg_debug "System prompt file (project symlink): $cursorrules_project_file"
  msg_debug "Working directory: $PWD"
  
  exec "$CURSOR_BIN" "${cursor_args[@]}"
}

main "$@"
