# Design: Disk Space Checking for Sync Operations

## Overview

This design document describes the implementation of disk space checking before starting file synchronization operations in `mutagen` and `rsync` (SSH) sync modes.

## Problem Statement

When syncing files to Docker volumes or containers, if the target doesn't have sufficient free disk space, the sync operation will fail partway through. This causes:
- Partial sync failures
- Wasted time on large projects
- Unclear error messages
- Potential data corruption

## Solution Approach

### 1. Calculate Required Space

**Project Size Calculation:**
- Use `du -sb ${DC_ORO_APPDIR}` to get exact byte count
- Add safety margin (20% overhead) for:
  - Temporary files during sync
  - File system metadata
  - Sync operation overhead
- Formula: `required_space = project_size * 1.2`

**Implementation:**
```bash
calculate_project_size() {
  local project_dir="${DC_ORO_APPDIR}"
  local size_bytes
  size_bytes=$(du -sb "${project_dir}" 2>/dev/null | awk '{print $1}')
  echo "$size_bytes"
}
```

### 2. Check Available Space

**For Mutagen Mode:**
- Target: Docker volume `${DC_ORO_NAME}_appcode`
- Method: Use temporary container to check volume space
- Command: `docker run --rm -v ${DC_ORO_NAME}_appcode:/check alpine df -B1 /check`

**For RSync Mode:**
- Target: Container filesystem (via SSH) or volume
- Method: If container running, use `docker exec`; otherwise check volume
- Command: `docker exec ${container} df -B1 ${DC_ORO_APPDIR}`

**Implementation:**
```bash
check_volume_disk_space() {
  local volume_name="${DC_ORO_NAME}_appcode"
  local available_bytes
  available_bytes=$(docker run --rm -v "${volume_name}:/check" alpine df -B1 /check 2>/dev/null | tail -1 | awk '{print $4}')
  echo "$available_bytes"
}

check_container_disk_space() {
  local container_name="$1"
  local mount_path="${DC_ORO_APPDIR}"
  local available_bytes
  available_bytes=$(docker exec "${container_name}" df -B1 "${mount_path}" 2>/dev/null | tail -1 | awk '{print $4}')
  echo "$available_bytes"
}
```

### 3. Integration Points

**Mutagen Mode:**
- Check happens after volume creation
- Check happens before `mutagen sync create` or `mutagen sync resume`
- Location: In mutagen sync start function (if exists) or in `handle_compose_up()`

**RSync Mode:**
- Check happens after volume creation
- Check happens before `orodc-sync` daemon starts
- Location: In rsync sync start function (if exists) or in `handle_compose_up()`

**Default Mode:**
- No checks needed (native Docker volumes, no sync)

### 4. Error Handling

**Insufficient Space:**
- Display error with `msg_error()`
- Show required space vs available space in human-readable format
- Exit with non-zero code to prevent sync from starting

**Edge Cases:**
- Volume doesn't exist: Estimate from host disk space (where Docker stores volumes)
- Container not running: Check volume space instead
- Permission errors: Show warning but don't block (may be false positive)
- Very large projects: Ensure calculation doesn't overflow

### 5. Bypass Mechanism

**Environment Variable:**
- `DC_ORO_SKIP_DISK_CHECK=1` - Skip all disk space checks
- Useful for advanced users or CI/CD environments
- Documented in error messages and help text

## Implementation Details

### Function Structure

```bash
# Main check function
check_sync_disk_space() {
  local mode="${DC_ORO_MODE:-default}"
  
  # Skip if default mode (no sync)
  [[ "$mode" == "default" ]] && return 0
  
  # Skip if bypass flag set
  [[ "${DC_ORO_SKIP_DISK_CHECK:-}" == "1" ]] && return 0
  
  # Calculate required space
  local required_bytes
  required_bytes=$(calculate_project_size)
  required_bytes=$((required_bytes * 120 / 100))  # Add 20% overhead
  
  # Check available space based on mode
  local available_bytes
  if [[ "$mode" == "mutagen" ]]; then
    available_bytes=$(check_volume_disk_space)
  elif [[ "$mode" == "ssh" ]]; then
    available_bytes=$(check_rsync_target_space)
  fi
  
  # Compare and error if insufficient
  if [[ "$available_bytes" -lt "$required_bytes" ]]; then
    local required_human=$(bytes_to_human "$required_bytes")
    local available_human=$(bytes_to_human "$available_bytes")
    msg_error "Insufficient disk space for sync"
    msg_error "Required: ${required_human}, Available: ${available_human}"
    msg_error "Set DC_ORO_SKIP_DISK_CHECK=1 to bypass this check"
    return 1
  fi
  
  return 0
}
```

### Helper Functions

```bash
# Convert bytes to human-readable format
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
```

## Testing Strategy

1. **Small Project Test:** < 100MB project should pass quickly
2. **Large Project Test:** > 5GB project should calculate correctly
3. **Insufficient Space Test:** Simulate low disk space, verify error message
4. **Bypass Test:** Verify `DC_ORO_SKIP_DISK_CHECK=1` skips checks
5. **Mode Tests:** Verify checks only run for mutagen/rsync modes
6. **Edge Case Tests:** Volume doesn't exist, container not running, permission errors

## Performance Considerations

- Disk space checks are fast (< 1 second typically)
- Project size calculation may take longer for very large projects (use `du -sb` which is efficient)
- Checks happen once before sync starts, not during sync
- Minimal overhead compared to sync operation time

## Security Considerations

- No user data is exposed in error messages
- Only disk space information is displayed
- Bypass mechanism allows advanced users to skip checks if needed
- No network operations required (all checks are local)
