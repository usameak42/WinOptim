# Architecture Research: PowerShell Optimization System

**Confidence:** High — Structure defined in PRD Section 3.1

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     WinOptimizer.ps1                         │
│  (Entry Point: Elevation, Restore Point, Menu, Safety Gates) │
└──────────────────────┬──────────────────────────────────────┘
                       │
         ┌─────────────┴─────────────┐
         │                           │
    ┌────▼────┐              ┌──────▼──────┐
    │   lib/  │              │   modules/  │
    │ Helpers │              │ 7 Feature   │
    └────┬────┘              │  Modules    │
         │                   └──────┬──────┘
         │                           │
         └───────────┬───────────────┘
                     │
         ┌───────────▼───────────┐
         │     Rollback Data     │
         │   (%TEMP%\WinOptimizer) │
         └───────────────────────┘
```

## Component Boundaries

### Entry Point (`WinOptimizer.ps1`)

**Responsibilities:**
- Process-scope execution policy bypass
- Elevation check with self-relaunch
- Initialize session state (paths, timestamps)
- Create System Restore Point (SR-01 safety gate)
- Virtualization stack baseline validation (SR-04 safety gate)
- Dot-source all library helpers
- Display interactive menu
- Orchestrate module execution
- Final virtualization stack verification

**Boundaries:**
- Does NOT contain optimization logic — delegates to modules
- Does NOT modify system state directly (except Restore Point)
- Reads from: `config/services.json`
- Writes to: `%TEMP%\WinOptimizer\` (logs, rollback manifests)

### Library Layer (`lib/`)

**Shared Helpers:**

| File | Function | Responsibility |
|------|----------|----------------|
| `Write-OptLog.ps1` | `Write-OptLog` | Structured JSONL logging with timestamp, module, operation, target, values, result |
| `Get-ActivePlanGuid.ps1` | `Get-ActivePlanGuid` | Locale-safe regex extraction from `powercfg /getactivescheme` |
| `Save-RollbackEntry.ps1` | `Save-RollbackEntry` | Append to JSON rollback manifest before any destructive operation |
| `Take-RegistryOwnership.ps1` | `Take-RegistryOwnership` | Transfer ownership from TrustedInstaller to Administrators via ACL |
| `Test-VirtStack.ps1` | `Test-VirtStack` | WMI-based validation of WSL2/Hyper-V (never wsl.exe) |

**Boundaries:**
- Pure functions — no side effects except logging/rollback
- No direct system modification
- Called by modules, not entry point
- Session state: Read from `$global:LogPath`, `$global:RollbackPath`

### Module Layer (`modules/`)

**Seven Independent Modules:**

1. `Invoke-TelemetryBlock.ps1` — Registry, services, scheduled tasks
2. `Invoke-GpuDwmOptimize.ps1` — GPU scheduling, DWM composition
3. `Invoke-SchedulerOptimize.ps1` — CPU scheduler, power settings
4. `Invoke-PowerPlanConfig.ps1` — Power plans, OEM detection, scheduled tasks
5. `Invoke-FileSystemOptimize.ps1` — NTFS parameters, pagefile
6. `Invoke-ServiceOptimize.ps1` — Service startup types
7. `Invoke-Rollback.ps1` — Manifest-driven restoration

**Module Pattern:**
```powershell
#Requires -Version 5.1
[CmdletBinding()]
param()

#region Initialization
# Import libraries if not already loaded
# Check idempotency (skip if already configured)
#endregion

#region Operations
foreach ($operation in $operations) {
    # 1. Save-RollbackEntry (capture current state)
    # 2. Perform modification (registry, service, fsutil)
    # 3. Write-OptLog (record result)
    # 4. Color-coded console output
}
#endregion

#region Verification
# Validate changes applied correctly
# Warn if verification fails (non-terminating)
#endregion
```

**Boundaries:**
- Each module is standalone — can run independently
- Modules do NOT call other modules
- All state changes go through rollback logging
- Idempotent — check current state before modifying

### Configuration (`config/services.json`)

**Structure:**
```json
{
  "disabled": [
    "DiagTrack",
    "dmwappushservice",
    ...
  ],
  "manual": [
    "SysMain",
    "WSearch",
    ...
  ],
  "oem_power_services": [
    {
      "name": "ArmouryCrate.Service",
      "oem": "ASUS",
      "countermeasure": "PowerPlanReassertion"
    },
    ...
  ]
}
```

**Boundaries:**
- Read-only at runtime
- Extensible by users (add new OEM services)
- Version-controlled with repository

### Data Flow

```
┌──────────────┐
│   User runs  │
│ WinOptimizer │
└──────┬───────┘
       │
       ▼
┌──────────────────┐
│ Safety Gates     │
│ - Elevation      │
│ - PS Version     │
│ - Restore Point  │
│ - Virt Baseline  │
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ Menu Selection   │
└──────┬───────────┘
       │
       ▼
┌────────────────────┐
│ Module Execution   │
└──────┬─────────────┘
       │
       ├─────────────────────────────────────────────┐
       │                                             │
       ▼                                             ▼
┌──────────────────┐                      ┌──────────────────┐
│ Save-Rollback    │                      │ Write-OptLog     │
│ (Before Change)  │                      │ (After Change)   │
└──────────────────┘                      └──────────────────┘
       │                                             │
       ▼                                             ▼
┌──────────────────┐                      ┌──────────────────┐
│ Modify System    │                      │ JSONL Log File   │
│ (Registry/Svc)   │                      │ (%TEMP%\WinOpt)  │
└──────────────────┘                      └──────────────────┘
       │
       ▼
┌──────────────────┐
│ JSON Rollback    │
│ Manifest         │
└──────────────────┘
```

## Suggested Build Order

### Phase 1: Foundation (Core Scripting & Modularity)
1. Repository structure scaffold (all dirs, empty files)
2. `lib/` helpers — implement all 5 with full validation
3. `config/services.json` — Disabled, Manual, OEM lists
4. Module 1 (Telemetry) and Module 6 (Services) — reference implementations

### Phase 2: Power Management (Complex Logic)
5. Module 4 (Power Plan) — S0 detection, OEM detection, scheduled task creation
6. Module 3 (Scheduler) — Win32PrioritySeparation, core parking with GUIDs

### Phase 3: I/O Optimization
7. Module 5 (File System) — NVMe detection gate, SysMain conditional, NTFS fsutil

### Phase 4: GPU & Safety
8. Module 2 (GPU/DWM) — HAGS, MPO, Nvidia telemetry
9. Module 7 (Rollback) — Manifest read, reverse restoration

### Phase 5: Integration
10. Entry point (`WinOptimizer.ps1`) — Menu, safety gates, orchestration
11. Pester tests (`tests/`)

### Phase 6: Polish
12. README.md, CONTRIBUTING.md, CHANGELOG.md, LICENSE
13. GitHub Issue templates
14. Final quality gate testing

## Critical Integration Points

| Component | Integration Point | Risk |
|-----------|------------------|------|
| Entry Point → Libraries | Dot-sourcing order matters (libraries before modules) | Low |
| Modules → Rollback | Must call `Save-RollbackEntry` BEFORE every modification | High |
| Modules → Logging | Must call `Write-OptLog` AFTER every operation | Medium |
| All → Virtualization | `Test-VirtStack` must use WMI, never wsl.exe | High |
| PowerPlan → OEM | Scheduled task must use current user principal, not LOCAL_SYSTEM | Medium |
| Rollback → Entry Point | `-Rollback -ManifestPath` parameter must bypass menu | Low |
| Protected Services | Hardcoded blocklist enforced in all modules | Critical |

## State Management

**Session State (Entry Point):**
```powershell
$global:SessionId    = "yyyyMMdd_HHmmss"
$global:OutputDir    = "$env:TEMP\WinOptimizer"
$global:LogPath      = "$global:OutputDir\log_$global:SessionId.jsonl"
$global:RollbackPath = "$global:OutputDir\rollback_$global:SessionId.json"
$global:VirtBaseline = (Test-VirtStack)
```

**Rollback Manifest Schema:**
```json
[
  {
    "Module": "Invoke-TelemetryBlock",
    "Type": "Registry",
    "Target": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\DataCollection",
    "ValueName": "AllowTelemetry",
    "OriginalData": "1",
    "OriginalType": "REG_DWORD",
    "Timestamp": "2025-03-13T10:30:45.1234567-07:00"
  }
]
```

**Log Entry Schema:**
```json
{
  "Timestamp": "2025-03-13 10:30:45",
  "Module": "Invoke-TelemetryBlock",
  "Operation": "Set-ItemProperty",
  "Target": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\DataCollection\\AllowTelemetry",
  "OldValue": "1",
  "NewValue": "0",
  "Result": "Success",
  "Message": "Telemetry capped at Security level"
}
```

## Build Order Rationale

**Why libraries first?** Modules depend on helpers; circular dependency risk.

**Why Telemetry + Services as reference?** Simplest modules (registry + services only); establish pattern.

**Why Power Plan before Scheduler?** Scheduler needs active plan GUID; Power Plan configures it.

**Why File System before GPU?** File System has conditional logic (NVMe gate); GPU is straightforward registry.

**Why Rollback last?** Requires understanding all rollback entry types from other modules.

**Why Entry Point before tests?** Need full orchestration to test integration.

---
*Architecture synthesized from WinOptimizer PRD Section 3.1-3.3*
*Confidence: High — Structure fully specified*
