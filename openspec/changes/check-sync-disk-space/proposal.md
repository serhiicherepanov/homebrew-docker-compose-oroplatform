# Change: Check Disk Space Before Mutagen/RSync Sync

## Why

When running in `mutagen` or `rsync` (SSH) sync modes, files are synchronized to Docker volumes that are mounted in containers. If the target container or volume doesn't have sufficient free disk space, the sync operation will fail partway through, leaving the environment in an inconsistent state. This causes:

- Partial sync failures that are hard to diagnose
- Wasted time syncing large projects only to fail at the end
- User frustration from unclear error messages
- Potential data corruption if sync fails mid-operation

By checking available disk space **before** starting sync operations, we can:
- Fail fast with clear error messages
- Prevent wasted time on doomed sync operations
- Provide actionable guidance (how much space is needed)
- Improve user experience with proactive validation

## What Changes

- Add disk space checking before mutagen sync starts
- Add disk space checking before rsync sync starts
- Calculate required space based on project directory size
- Check available space in target containers/volumes
- Display clear error messages with actionable guidance
- Allow bypassing checks with environment variable (for advanced users)

## Impact

- Affected specs: `file-sync` capability (mutagen and rsync modes)
- Affected code:
  - `libexec/orodc/lib/docker-utils.sh` (disk space checking functions)
  - `libexec/orodc/compose.sh` (integrate checks before sync)
  - Mutagen sync integration (if exists)
  - RSync sync integration (if exists)
- **Critical for large projects** - prevents sync failures
- **Improves UX** - clear error messages before starting long operations
