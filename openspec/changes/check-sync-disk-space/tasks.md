## 1. Disk Space Calculation

- [x] 1.1 Add function `calculate_project_size()` in `libexec/orodc/lib/docker-utils.sh` to calculate size of `${DC_ORO_APPDIR}` directory
- [x] 1.2 Use `du -sb` or similar to get accurate byte count of project directory
- [x] 1.3 Add safety margin (e.g., 20% overhead) to calculated size for sync operations
- [x] 1.4 Handle edge cases (empty directory, very large projects, symlinks)

## 2. Container Disk Space Checking

- [x] 2.1 Add function `check_container_disk_space()` in `libexec/orodc/lib/docker-utils.sh` to check available space in container
- [x] 2.2 Use `docker exec` to run `df -k` or `df -B1` in target container
- [x] 2.3 Parse output to extract available space in bytes
- [x] 2.4 Handle containers that are not yet running (check volume space instead)
- [x] 2.5 Support checking multiple containers (fpm, cli, websocket) that mount the volume

## 3. Volume Disk Space Checking

- [x] 3.1 Add function `check_volume_disk_space()` in `libexec/orodc/lib/docker-utils.sh` to check available space in Docker volume
- [x] 3.2 Use temporary container or volume inspection to check space
- [x] 3.3 Handle volume that doesn't exist yet (estimate based on host disk space)
- [x] 3.4 Parse Docker volume inspection output to get available space

## 4. Mutagen Mode Integration

- [x] 4.1 Add function `check_mutagen_sync_disk_space()` that checks space before mutagen sync
- [x] 4.2 Calculate project size and required space
- [x] 4.3 Check available space in Docker volume `${DC_ORO_NAME}_appcode`
- [x] 4.4 Integrate check into mutagen sync start flow (before `mutagen sync create`)
- [x] 4.5 Display clear error message if insufficient space (show required vs available)
- [x] 4.6 Allow bypass with `DC_ORO_SKIP_DISK_CHECK=1` environment variable

## 5. RSync Mode Integration

- [x] 5.1 Add function `check_rsync_sync_disk_space()` that checks space before rsync sync
- [x] 5.2 Calculate project size and required space
- [x] 5.3 Check available space in target container via SSH (or volume if container not running)
- [x] 5.4 Integrate check into rsync sync start flow (before `orodc-sync` starts)
- [x] 5.5 Display clear error message if insufficient space (show required vs available)
- [x] 5.6 Allow bypass with `DC_ORO_SKIP_DISK_CHECK=1` environment variable

## 6. Error Handling and UX

- [x] 6.1 Format disk space values in human-readable format (GB, MB, KB)
- [x] 6.2 Show both required and available space in error messages
- [x] 6.3 Provide actionable guidance (e.g., "Need 2.5GB, have 1.2GB available")
- [x] 6.4 Use `msg_error()` for insufficient space errors
- [x] 6.5 Use `msg_info()` for space check progress messages
- [x] 6.6 Handle edge cases gracefully (permission errors, container not accessible)

## 7. Integration Points

- [x] 7.1 Integrate disk space check into `handle_compose_up()` before starting containers for mutagen/rsync modes
- [x] 7.2 Ensure check happens after volume creation but before sync starts
- [x] 7.3 Ensure check doesn't block `default` mode (no sync needed)
- [x] 7.4 Add check to mutagen sync lifecycle management (if exists)
- [x] 7.5 Add check to rsync sync lifecycle management (if exists)

## 8. Validation

- [ ] 8.1 Test with small project (< 100MB) - should pass quickly
- [ ] 8.2 Test with large project (> 5GB) - should calculate correctly
- [ ] 8.3 Test with insufficient space scenario - should show clear error
- [ ] 8.4 Test bypass flag `DC_ORO_SKIP_DISK_CHECK=1` - should skip checks
- [ ] 8.5 Test mutagen mode - check happens before sync starts
- [ ] 8.6 Test rsync mode - check happens before sync starts
- [ ] 8.7 Test default mode - no checks performed (no sync)
- [ ] 8.8 Test with containers not running - should check volume space
- [ ] 8.9 Test with volume not existing - should estimate from host space
