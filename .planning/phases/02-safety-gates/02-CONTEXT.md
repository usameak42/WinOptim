# Phase 2: Safety Gates - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning

## Phase Boundary

Implement pre-flight validation infrastructure that ensures safe execution environment before any optimization modules run. This phase delivers Administrator elevation detection and self-relaunch, PowerShell version validation, System Restore Point creation, and WSL2/Hyper-V state validation via WMI (no wsl.exe). These are safety gates that must pass before any optimization modules execute.

**Dependencies:** Phase 1 library helpers (Test-VirtStack, Write-OptLog, Save-RollbackEntry)

## Implementation Decisions

### Restore Point

- Naming format: Descriptive (exact format at Claude's discretion - suggested: WinOptimizer-Before-Optimization-YYYYMMDD)
- Check for recent restore points within last hour before creating new one
- If recent point exists but > 24 hours old: Warn user about age
- Show confirmation message when restore point is successfully created
- Use Checkpoint-Computer cmdlet (not WMI)
- Show progress bar during restore point creation (can take 10-30 seconds)
- On creation failure: Show error details + prompt user whether to continue or exit
- In silent mode (-Silent): Still prompt interactively if restore point creation fails
- Log restore point creation to JSONL log file (Write-OptLog)
- Add "Restore-Point" field to rollback manifest with name and timestamp

### Version Validation

- Allow PowerShell 7+ (pwsh) but show interactive prompt: "Detected PowerShell 7.x. This script is designed for PowerShell 5.1. Proceed? (Y/N)"
- For PowerShell < 5.1: Fatal error with message "ERROR: PowerShell 5.1+ required. Current version: X.X is not supported. Exiting."
- Error messages should be clear and technical

### Elevation Behavior

- Detect admin status using [Security.Principal.WindowsPrincipal]::IsInRole("Administrator")
- Relaunch using Start-Process with -Verb RunAs
- Pass only known arguments: -Silent, -RunAll, -Rollback (not all args for safety)
- Use -NoProfile and -ExecutionPolicy Bypass switches when relaunching
- Show descriptive message before relaunch: "WinOptimizer requires Administrator privileges. Restarting with elevation..."
- Use color-coded output (Yellow/Warning) for pre-relaunch message
- Double-check elevation status after relaunch (validate the elevated process)
- Exit code 5 (ERROR_ACCESS_DENIED) if elevation fails or user cancels UAC
- Log elevation check and relaunch action to JSONL log file
- Add "Elevated: true" field to rollback manifest

### Virtualization Check

- Check timing: Before ANY modules run (safety gate) AND after all modules complete
- If WSL2 or Hyper-V detected as active: Show warning (red color) and continue execution
- Display per-feature status: "WSL2: Active, Hyper-V: Active" (or similar)
- If NO virtualization detected: Show confirmation message "No virtualization features detected"
- Detection method: WMI (Get-WmiObject Win32_ComputerSystem) + check all related services
  - Hyper-V: vmms, vmic*, VmCompute
  - WSL2: WslService, LxssManager
- Post-execution check: Compare against pre-execution status and warn if changed
- Log virtualization detection results to JSONL log file
- Add "Virtualization" field to rollback manifest with WSL2/Hyper-V status
- If detection encounters error (can't determine state): Fatal error and halt execution

### Claude's Discretion

- Exact restore point naming format (descriptive, informative, suggested format: WinOptimizer-Before-Optimization-YYYYMMDD)
- Color shades for terminal output (specific RGB values not required)
- WMI query structure for virtualization detection
- Service state check implementation (Running vs Stopped detection)

## Specific Ideas

- Use Test-VirtStack from Phase 1 lib/ helpers as basis for virtualization validation
- All safety gates should emit structured JSONL log entries via Write-OptLog
- Rollback manifest should capture safety gate results (Restore-Point, Elevated, Virtualization) for audit trail
- In silent mode, restore point failure should still prompt user - safety net is critical

## Deferred Ideas

None — discussion stayed within phase scope.

---

*Phase: 02-safety-gates*
*Context gathered: 2026-03-13*
