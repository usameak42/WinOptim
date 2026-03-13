# Phase 3: Core Modules - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Implement telemetry suppression, service optimization, and GPU/DWM optimization modules. This phase builds three PowerShell modules that modify Windows configuration:
- Telemetry Module: Disable telemetry services, AutoLogger sessions, and scheduled tasks
- Service Module: Disable telemetry services, set background services to Manual
- GPU Module: Enable HAGS, disable MPO, handle Nvidia/AMD GPU detection, validate HAGS post-reboot

All modules must record prior state to rollback manifest before making changes and emit structured JSONL log entries for every operation.

</domain>

<decisions>
## Implementation Decisions

### Error Handling

**Service Disable Failures:** Prompt user to continue or halt on each service disable failure

**Registry Ownership Failures:** Log WARNING, skip that registry operation, continue with others

**Rollback Failures:** Any rollback failure = halt immediately (rollback is critical)

**AutoLogger Session Failures:** Skip failed session, continue disabling other sessions

**Dependent Service Failures:** Prompt user to disable parent+child or skip both

**GPU Not Found:** Log WARNING, skip entire GPU module, continue other modules

**Battery Status Unknown:** Prompt user to confirm power source

**Registry Corruption:** Log, skip, continue with other keys

**Scheduled Task Failures:** Continue disabling remaining tasks, list failed tasks at end for manual review

**Service State Mismatch:** Record both StartType and running state, log WARNING about mismatch

**HAGS Still Disabled (no reboot):** Halt, instruct user to reboot before continuing

**MPO Key Missing:** Log WARNING (expected on older Windows versions)

**Access Denied (even with admin):** Attempt elevation with alternative credentials

**Service from Config Doesn't Exist:** Mark as disabled in rollback, continue

**Service Stop Timeout:** Prompt user to force kill or skip

**Concurrent Modification Failures:** Retry operations sequentially

**Log File Write Failure:** Console-only fallback, warn user

**Rollback Manifest Corruption:** Warn user, prompt to choose: halt, continue, or recreate manifest

**WMI Query Fails:** Warn user, prompt to choose: halt module, use fallback detection methods, or skip GPU optimizations

**Multiple GPUs:** Multi-select menu with indices, user chooses which to optimize

**No GPU Found:** Warn user, prompt to choose: halt, skip GPU module, or attempt generic optimizations (MPO disable via registry)

**Unknown GPU Vendor:** Inform user, prompt to choose: apply generic optimizations, skip vendor-specific steps, or halt for manual configuration

**Virtual GPU Detected:** Skip virtual GPU (e.g., Hyper-V, VMware virtual display)

**GPU Optimization Step Failure:** Prompt user to skip failed step or halt GPU module

### User Interaction

**HAGS Reboot:** Prompt user: "Reboot now? (Y/N)" — if Y, trigger reboot; if N, warn and continue

**Console Output:** Verbose color output by default (SUCCESS/WARNING/ERROR/INFO/ACTION/SKIP)

**Progress Indication:** Progress bar for long operations (e.g., "Disabling services... 3/5")

**Confirmations:** Module-level confirmation (prompt once at module start: "Apply X optimizations?")

**Summary Display:** Detailed summary showing successes, skips, warnings, and errors with counts

**Error Message Format:** User-friendly format in console ("Failed to disable X — Access Denied")

**Warning Handling:** Prompt user: "Continue despite warnings?"

**Log File Location:** Show log file path at start and end of execution

**Recovery on Module Failure:** Prompt user: continue or rollback

**Dry-Run Mode:** No dry-run support

**Color Scheme:** Standard colors (Green=success, Yellow=warning, Red=error, Blue=info, Cyan=action, Gray=skip)

**Timing Display:** Show timing only for operations over 30 seconds

**Interactive Rollback:** Prompt for rollback only if errors occurred

**Batch Mode:** Halt on any prompt (no interactive prompts in non-interactive mode)

**Verbose Mode:** Show all operations (every registry value, service name, task being checked/modified)

**Update Checking:** Check GitHub releases, notify if update available (non-blocking)

### Idempotency Depth

**Service Checks:** Check StartType + running state — skip only if both match desired state

**Registry Checks:** Skip if key exists with correct value AND correct type (DWORD vs QWORD match)

**AutoLogger Checks:** Check only telemetry-related sessions (targeted, faster)

**Idempotency Logging:** Log every check with result ("Checking service X... already disabled [SKIP]")

**Task Checks:** Check State + Enabled property — skip if both indicate disabled

**HAGS Checks:** Check registry value + GPU driver capability validation

**MPO Checks:** Check registry value + verify MPO is actually disabled in system

**Rollback Data:** Always save to rollback manifest (duplicate entries overwrite)

### GPU Detection

**Multiple GPUs:** Multi-select menu with index numbers, full GPU names displayed, discrete GPU pre-selected by default

**No GPU Found:** Warn user, prompt to choose: halt, skip GPU module, or attempt generic optimizations (MPO disable via registry without vendor checks)

**Unknown GPU Vendor:** Inform user, prompt to choose: apply generic optimizations only, skip vendor-specific steps, or halt for manual configuration

**Nvidia GPU:** Prompt user: "Apply Nvidia-specific optimizations?" (full Nvidia optimization vs HAGS only)

**Driver Version Checking:** Check driver version, warn if below minimum threshold

**Intel Integrated GPU:** Prompt user: "Optimize integrated GPU?" (usually skipped alongside discrete)

**WMI Fallback Detection:** Claude's discretion (not specified by user)

**Virtual GPU:** Skip virtual GPU with log warning

**Hybrid GPU Mode:** Prompt user for hybrid GPU handling (e.g., Optimus, Switchable)

**HAGS Capability Validation:** Inform user, prompt to choose: query driver for HAGS support, try-catch (attempt enable, catch error if unsupported), or enable HAGS for all GPUs (assume support)

**MPO Detection:** Try to disable MPO, log WARNING if key doesn't exist

**GPU Display:** Show full GPU name from WMI (e.g., "NVIDIA GeForce RTX 3080")

**Default Selection:** Pre-select discrete GPU in multi-GPU menu

**AMD GPU:** Prompt user: "Apply AMD-specific optimizations?" or "Skip vendor-specific?"

**HAGS-Only Mode:** Prompt user per optimization step

**GPU Detection Timing:** Detect GPU once at module start, verify GPU still exists before critical steps

### Rollback Manifest Structure

**Entry Fields:** type, path, oldValue, newValue, timestamp, module (6 core fields)

**Organization:** Grouped by module (telemetry, services, gpu) with nested entries

**Complex Values:** Store arrays/objects as base64-encoded string

**File Format:** JSON with pretty-print (human-readable)

### JSONL Logging Format

**Log Entry Fields:** timestamp, module, operation, status, level (INFO/WARN/ERROR/SUCCESS/ACTION/SKIP), target, details, duration (8 fields)

**Error Details:** Simple string field with full error message

**Log Rotation:** Create new log file each run (timestamp in filename)

**Log Entry Format:** Pretty JSON (one object per line with indentation, human-readable)

### Service Identification

**Service Property:** Use both ServiceName and DisplayName, match against either property

**Config File Storage:** config/services.json stores both ServiceName and DisplayName properties

**Localization:** Store English DisplayName as reference, match against ServiceName

**Matching:** Case-insensitive match on both properties

### Scheduled Task Handling

**Task Action:** Prompt user at runtime with explanation:
- Disable only: Sets State=0, fully reversible
- Delete task: Removes task, cleaner but irreversible
- Hybrid: Disable custom tasks, delete system telemetry tasks

**Already Disabled:** Still attempt to disable (idempotent operation)

**System vs Custom:** Distinguish by task author/creator

**Task Rollback:** Hybrid restore — re-enable if disabled, recreate if deleted

</decisions>

<specifics>
## Specific Ideas

- "I want to be prompted before anything changes, but not for every single operation"
- "Logs should be detailed enough to debug issues, but console output should be human-readable"
- "Multiple GPUs are common — let the user choose which ones to optimize"
- "GPU vendor matters — Nvidia and AMD have specific optimizations"
- "Rollback is critical — if rollback fails, halt immediately"

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope (telemetry suppression, service optimization, GPU/DWM optimization modules).

</deferred>

---

*Phase: 03-core-modules*
*Context gathered: 2026-03-13*
