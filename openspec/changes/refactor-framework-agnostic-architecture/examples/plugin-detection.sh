#!/usr/bin/env bash
# Example implementation of plugin detection logic

set -euo pipefail

# Detect by composer packages
detect_composer_packages() {
  local manifest="$1"
  local packages match
  
  [[ ! -f "composer.json" ]] && return 1
  
  packages=$(jq -r '.detection.rules[] | select(.type=="composer_packages") | .packages[]' "$manifest")
  match=$(jq -r '.detection.rules[] | select(.type=="composer_packages") | .match // "any"' "$manifest")
  
  local found=0
  local total=0
  
  for package in $packages; do
    ((total++))
    if grep -q "\"${package}\"" composer.json; then
      ((found++))
      log "  ✓ Found composer package: ${package}"
      
      [[ "$match" == "any" ]] && return 0
    fi
  done
  
  if [[ "$match" == "all" ]] && [[ $found -eq $total ]]; then
    return 0
  fi
  
  return 1
}

# Detect by file existence
detect_file_exists() {
  local manifest="$1"
  local files match
  
  files=$(jq -r '.detection.rules[] | select(.type=="file_exists") | .files[]' "$manifest")
  match=$(jq -r '.detection.rules[] | select(.type=="file_exists") | .match // "all"' "$manifest")
  
  local found=0
  local total=0
  
  for file in $files; do
    ((total++))
    if [[ -e "$file" ]]; then
      ((found++))
      log "  ✓ Found file: ${file}"
      
      [[ "$match" == "any" ]] && return 0
    else
      log "  ✗ Missing file: ${file}"
      [[ "$match" == "all" ]] && return 1
    fi
  done
  
  if [[ "$match" == "all" ]] && [[ $found -eq $total ]]; then
    return 0
  fi
  
  return 1
}

# Detect by directory structure
detect_directory_structure() {
  local manifest="$1"
  local directories match
  
  directories=$(jq -r '.detection.rules[] | select(.type=="directory_structure") | .directories[]' "$manifest")
  match=$(jq -r '.detection.rules[] | select(.type=="directory_structure") | .match // "all"' "$manifest")
  
  local found=0
  local total=0
  
  for dir in $directories; do
    ((total++))
    if [[ -d "$dir" ]]; then
      ((found++))
      log "  ✓ Found directory: ${dir}"
      
      [[ "$match" == "any" ]] && return 0
    else
      log "  ✗ Missing directory: ${dir}"
      [[ "$match" == "all" ]] && return 1
    fi
  done
  
  if [[ "$match" == "all" ]] && [[ $found -eq $total ]]; then
    return 0
  fi
  
  return 1
}

# Detect by file content patterns
detect_file_content() {
  local manifest="$1"
  
  # Get all file_content rules
  local rule_count=$(jq '.detection.rules | map(select(.type=="file_content")) | length' "$manifest")
  
  for ((i=0; i<rule_count; i++)); do
    local file=$(jq -r ".detection.rules[] | select(.type==\"file_content\") | .file" "$manifest" | sed -n "$((i+1))p")
    local patterns=$(jq -r ".detection.rules[] | select(.type==\"file_content\" and .file==\"${file}\") | .patterns[]" "$manifest")
    local match=$(jq -r ".detection.rules[] | select(.type==\"file_content\" and .file==\"${file}\") | .match // \"any\"" "$manifest")
    
    [[ ! -f "$file" ]] && continue
    
    local found=0
    local total=0
    
    for pattern in $patterns; do
      ((total++))
      if grep -q "$pattern" "$file"; then
        ((found++))
        log "  ✓ Found pattern '${pattern}' in ${file}"
        
        [[ "$match" == "any" ]] && return 0
      fi
    done
    
    if [[ "$match" == "all" ]] && [[ $found -eq $total ]]; then
      return 0
    fi
  done
  
  return 1
}

# Detect by JSON field value
detect_json_field() {
  local manifest="$1"
  
  local rule_count=$(jq '.detection.rules | map(select(.type=="json_field")) | length' "$manifest")
  
  for ((i=0; i<rule_count; i++)); do
    local file=$(jq -r ".detection.rules[] | select(.type==\"json_field\") | .file" "$manifest" | sed -n "$((i+1))p")
    local field=$(jq -r ".detection.rules[] | select(.type==\"json_field\" and .file==\"${file}\") | .field" "$manifest")
    local expected=$(jq -r ".detection.rules[] | select(.type==\"json_field\" and .file==\"${file}\") | .value" "$manifest")
    local operator=$(jq -r ".detection.rules[] | select(.type==\"json_field\" and .file==\"${file}\") | .operator // \"equals\"" "$manifest")
    
    [[ ! -f "$file" ]] && continue
    
    local actual=$(jq -r ".${field}" "$file" 2>/dev/null || echo "")
    
    case "$operator" in
      equals)
        if [[ "$actual" == "$expected" ]]; then
          log "  ✓ Field '${field}' in ${file} equals '${expected}'"
          return 0
        fi
        ;;
      contains)
        if [[ "$actual" == *"$expected"* ]]; then
          log "  ✓ Field '${field}' in ${file} contains '${expected}'"
          return 0
        fi
        ;;
      regex)
        if [[ "$actual" =~ $expected ]]; then
          log "  ✓ Field '${field}' in ${file} matches regex '${expected}'"
          return 0
        fi
        ;;
    esac
  done
  
  return 1
}

# Main detection function
detect_plugin() {
  local manifest="$1"
  local plugin_name=$(jq -r '.name' "$manifest")
  local priority=$(jq -r '.detection.priority // 50' "$manifest")
  
  log "Checking plugin: ${plugin_name} (priority: ${priority})"
  
  # All rules must pass (AND logic)
  local rule_types=$(jq -r '.detection.rules[].type' "$manifest" | sort -u)
  
  for rule_type in $rule_types; do
    case "$rule_type" in
      composer_packages)
        detect_composer_packages "$manifest" || return 1
        ;;
      npm_packages)
        # Similar to composer_packages but for package.json
        ;;
      file_exists)
        detect_file_exists "$manifest" || return 1
        ;;
      directory_structure)
        detect_directory_structure "$manifest" || return 1
        ;;
      file_content)
        detect_file_content "$manifest" || return 1
        ;;
      json_field)
        detect_json_field "$manifest" || return 1
        ;;
      *)
        log "  ⚠ Unknown rule type: ${rule_type}"
        ;;
    esac
  done
  
  log "✅ Plugin ${plugin_name} matched!"
  return 0
}

# Discovery and selection
discover_and_select_plugin() {
  local plugins=()
  local matched_plugins=()
  
  # Find all plugin manifests
  log "Discovering plugins..."
  
  # Homebrew plugins
  for formula_dir in "${HOMEBREW_PREFIX}"/share/dcx-plugin-*; do
    [[ -d "$formula_dir" ]] || continue
    for plugin_dir in "$formula_dir"/*; do
      if [[ -f "${plugin_dir}/plugin.json" ]]; then
        plugins+=("${plugin_dir}/plugin.json")
      fi
    done
  done
  
  # Built-in plugins
  for plugin_dir in "${DCX_SHARE_DIR}"/plugins/*; do
    if [[ -f "${plugin_dir}/plugin.json" ]]; then
      plugins+=("${plugin_dir}/plugin.json")
    fi
  done
  
  log "Found ${#plugins[@]} plugin(s)"
  
  # Detect plugins
  for manifest in "${plugins[@]}"; do
    if detect_plugin "$manifest"; then
      local priority=$(jq -r '.detection.priority // 50' "$manifest")
      matched_plugins+=("${priority}:${manifest}")
    fi
  done
  
  # Sort by priority (descending)
  if [[ ${#matched_plugins[@]} -gt 0 ]]; then
    IFS=$'\n' matched_plugins=($(sort -rn <<<"${matched_plugins[*]}"))
    
    # Select highest priority plugin
    local selected="${matched_plugins[0]#*:}"
    local plugin_name=$(jq -r '.name' "$selected")
    local plugin_priority=$(jq -r '.detection.priority // 50' "$selected")
    
    log ""
    log "🎯 Selected plugin: ${plugin_name} (priority: ${plugin_priority})"
    
    export DCX_PLUGIN="$plugin_name"
    export DCX_PLUGIN_MANIFEST="$selected"
  else
    log "⚠ No plugins matched, using generic"
    export DCX_PLUGIN="generic"
  fi
}

# Example usage
log() {
  echo "$*" >&2
}

# Run discovery
discover_and_select_plugin

