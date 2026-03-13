# Requirements: WinOptimizer PS1

**Defined:** 2025-03-13
**Core Value:** Safe, reversible Windows optimization that never breaks the developer virtualization stack

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Safety Gates

- [x] **SAFE-01**: Script can create a named System Restore Point before any module executes (halts on failure)
- [x] **SAFE-02**: Script verifies Administrator elevation and self-relaunches if not elevated
- [x] **SAFE-03**: Script validates PowerShell 5.1+ version before execution
- [x] **SAFE-04**: Script validates WSL2 and Hyper-V feature state via WMI before all changes and re-validates after

### Telemetry Module (Invoke-TelemetryBlock)

- [ ] **TELM-01**: Script can set AllowTelemetry to 0 in DataCollection policy key
- [ ] **TELM-02**: Script can disable AutoLogger ETW sessions (AutoLogger-Diagtrack-Listener, DiagLog, SQMLogger)
- [ ] **TELM-03**: Script can stop and disable DiagTrack and dmwappushservice services
- [ ] **TELM-04**: Script can disable telemetry scheduled tasks (CompatibilityAppraiser, ProgramDataUpdater, Consolidator, UsbCeip)
- [ ] **TELM-05**: Module records prior state of all values to rollback manifest

### GPU & DWM Module (Invoke-GpuDwmOptimize)

- [ ] **GPUD-01**: Script can enable Hardware-Accelerated GPU Scheduling via HwSchMode = 2
- [ ] **GPUD-02**: Script can disable Multi-Plane Overlay via DWM OverlayTestMode = 5
- [ ] **GPUD-03**: Script can detect Nvidia GPU presence via WMI and output NVCP manual configuration checklist
- [ ] **GPUD-04**: Script can disable NvTelemetryContainer service
- [ ] **GPUD-05**: Script validates HAGS activation post-reboot via registry readback

### CPU Scheduler Module (Invoke-SchedulerOptimize)

- [ ] **SCHD-01**: Script can set Win32PrioritySeparation to 38 (variable quanta, short intervals, 3x foreground boost)
- [ ] **SCHD-02**: Script can extract active power plan GUID using regex parser (locale-safe)
- [ ] **SCHD-03**: Script can disable CPU core parking using hardcoded GUIDs (SubGroup 54533251-82be-4824-96c1-47b60b740d00, Setting 0cc5b647-c1df-4637-891a-dec35c318583 = 100)
- [ ] **SCHD-04**: Script can set minimum and maximum processor state to 100% on AC power
- [ ] **SCHD-05**: Script can detect and configure network adapter interrupt moderation

### Power Plan Module (Invoke-PowerPlanConfig)

- [ ] **PWRP-01**: Script can detect Modern Standby (S0) state via PlatformAoAcOverride registry key
- [ ] **PWRP-02**: Script can apply PlatformAoAcOverride = 0 if S0 detected and prompt user for required reboot
- [ ] **PWRP-03**: Script can duplicate and activate Ultimate Performance plan (e9a42b02-d5df-448d-aa00-03f14749eb61)
- [ ] **PWRP-04**: Script can rename plan to custom label to prevent OEM GUID collision
- [ ] **PWRP-05**: Script can set PCIe Link State Power Management to Off (GUID: 501a4d13-42af-4429-9fd1-a8218c268e20)
- [ ] **PWRP-06**: Script can set USB Selective Suspend to Disabled
- [ ] **PWRP-07**: Script can detect OEM power management services (Armory Crate, Lenovo Vantage, Dell Command, HP Omen)
- [ ] **PWRP-08**: Script can create scheduled task to reapply plan post-login if OEM service detected

### File System Module (Invoke-FileSystemOptimize)

- [ ] **FSYS-01**: Script can disable NTFS Last Access Time updates via fsutil behavior set disableLastAccess 1
- [ ] **FSYS-02**: Script can set NTFS memoryusage to 2 (increased paged pool for MFT caching)
- [ ] **FSYS-03**: Script can set NTFS MFT zone reservation to 2 (25% volume reservation)
- [ ] **FSYS-04**: Script can detect system drive bus type (NVMe / SATA / HDD) via WMI
- [ ] **FSYS-05**: Script can disable SysMain and Prefetch if NVMe detected; skip if HDD
- [ ] **FSYS-06**: Script can configure Windows Search indexer throttling and exclude common developer directories
- [ ] **FSYS-07**: Script can set pagefile to fixed size (RAM × 1) if currently dynamic

### Service Module (Invoke-ServiceOptimize)

- [ ] **SRVC-01**: Script can disable DiagTrack, dmwappushservice, MapsBroker, RetailDemo, WerSvc, wisvc, NvTelemetryContainer services
- [ ] **SRVC-02**: Script can set SysMain, WSearch, lfsvc, PeerDistSvc, SharedAccess, PrintNotify, icssvc, NcdAutoSetup, PhoneSvc, RmSvc to Manual startup
- [ ] **SRVC-03**: Script validates protected services (HvHost, vmms, WslService, LxssManager, VmCompute, vmic*) remain untouched
- [ ] **SRVC-04**: Module logs prior StartType of each service for rollback
- [ ] **SRVC-05**: Module gracefully skips services not found without halting

### Rollback Module (Invoke-Rollback)

- [ ] **ROLL-01**: Script can read rollback manifest JSON from specified path
- [ ] **ROLL-02**: Script can restore all recorded registry values in reverse chronological order
- [ ] **ROLL-03**: Script can restore all service StartType values from manifest
- [ ] **ROLL-04**: Script can remove scheduled task if it was created by the script
- [ ] **ROLL-05**: Module reports each restored item with before/after values

### Library Helpers

- [x] **LIBR-01**: Write-OptLog can write structured JSONL log entries with timestamp, module, operation, target, values, result, message
- [x] **LIBR-02**: Get-ActivePlanGuid can extract GUID from powercfg output using regex (locale-safe)
- [x] **LIBR-03**: Save-RollbackEntry can append to JSON rollback manifest before any destructive operation
- [x] **LIBR-04**: Take-RegistryOwnership can transfer ownership from TrustedInstaller to Administrators via System.Security.AccessControl
- [x] **LIBR-05**: Test-VirtStack can validate WSL2/Hyper-V via WMI without calling wsl.exe

### Entry Point & CLI

- [ ] **CLIE-01**: Entry point applies Process-scope execution policy bypass
- [ ] **CLIE-02**: Entry point initializes session state (paths, timestamps, log file, rollback manifest)
- [ ] **CLIE-03**: Entry point displays interactive menu with all modules, index numbers, and descriptions
- [ ] **CLIE-04**: Entry point supports -Silent -RunAll flags for non-interactive automation
- [ ] **CLIE-05**: Entry point supports -Rollback -ManifestPath parameter to invoke rollback standalone
- [ ] **CLIE-06**: Menu displays estimated time and risk level (Low / Medium) before each module executes
- [ ] **CLIE-07**: Entry point uses color-coded terminal output (SUCCESS/WARNING/ERROR/INFO/ACTION/SKIP)

### Idempotency & Code Quality

- [ ] **QUAL-01**: Every operation checks current state first and emits [SKIP] if already in desired state
- [ ] **QUAL-02**: Every module calls Save-RollbackEntry before every Set-ItemProperty, Set-Service, and fsutil call
- [ ] **QUAL-03**: Every module calls Write-OptLog after every operation with full field population
- [ ] **QUAL-04**: All .ps1 files include #Requires -Version 5.1 at the top
- [ ] **QUAL-05**: All functions include [CmdletBinding()] attribute
- [ ] **QUAL-06**: Zero backtick line continuation — use splatting `@{}` for all multi-parameter cmdlets
- [ ] **QUAL-07**: Zero locale-sensitive powercfg aliases — hardcoded GUIDs only
- [ ] **QUAL-08**: Zero wsl.exe invocation from elevated context — WMI and Get-Service only
- [ ] **QUAL-09**: Protected services block enforced — HvHost, vmms, WslService, LxssManager, VmCompute, vmic* never in modification lists
- [ ] **QUAL-10**: #region / #endregion blocks organize sections within each file
- [ ] **QUAL-11**: 4-space indentation with inline comments on all non-obvious operations

### Repository Structure & Documentation

- [x] **REPO-01**: Repository matches exact structure from PRD Section 3.1 (all directories and files exist)
- [ ] **REPO-02**: README.md follows structure defined in PRD Section 3.5
- [x] **REPO-03**: config/services.json contains Disabled list, Manual list, and OEM entries (Armory Crate, Lenovo Vantage, Dell Command, HP Omen)
- [ ] **REPO-04**: tests/ directory contains Pester stubs for Test-Modules.ps1 and Test-Rollback.ps1
- [ ] **REPO-05**: CONTRIBUTING.md documents PR guidelines, module addition template, test requirements, code style ban on backtick continuation
- [ ] **REPO-06**: CHANGELOG.md includes v1.0.0 initial release entry
- [ ] **REPO-07**: .github/ISSUE_TEMPLATE/ contains bug_report.md and feature_request.md

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

(None currently — all features from PRD scoped to v1)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Windows 10 support | Modern Standby and power plans differ significantly; Windows 11 only |
| Enterprise/fleet management | Single-user workstation focus; different security model |
| Mobile app or GUI | CLI-first design; simpler, faster, more scriptable |
| Game-mode specific tweaks | Focus on workstation/developer use case, not gaming |
| Non-administrator user scenarios | Requires elevation by design for system modifications |
| Cloud-provisioned machines | Local optimization only; different constraints |
| Locale-specific powercfg aliases | Hardcoded GUIDs only for locale safety |
| Visual effects toggling | Users want animations; optimizes latency, not aesthetics |
| Aggressive service disabling | Conservative approach; avoid breaking features |
| Registry cleaners | High risk, low reward; focused optimization only |
| GPU overclocking / vendor tools | Out of scope; use MSI Afterburner, NVCP, etc. |
| Network optimization | Too variable; user-specific; can break connectivity |
| Automatic reboot handling | Safety first; user confirms reboot after S0 fix |
| Third-party driver updates | Out of scope; use Windows Update or vendor tools |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

### Phase 1: Foundation & Libraries

| Requirement | Phase | Status |
|-------------|-------|--------|
| REPO-01 | Phase 1 | Complete |
| REPO-03 | Phase 1 | Complete |
| LIBR-01 | Phase 1 | Complete |
| LIBR-02 | Phase 1 | Complete |
| LIBR-03 | Phase 1 | Complete |
| LIBR-04 | Phase 1 | Complete |
| LIBR-05 | Phase 1 | Complete |

### Phase 2: Safety Gates

| Requirement | Phase | Status |
|-------------|-------|--------|
| SAFE-01 | Phase 2 | Complete |
| SAFE-02 | Phase 2 | Complete |
| SAFE-03 | Phase 2 | Complete |
| SAFE-04 | Phase 2 | Complete |

### Phase 3: Core Modules

| Requirement | Phase | Status |
|-------------|-------|--------|
| TELM-01 | Phase 3 | Pending |
| TELM-02 | Phase 3 | Pending |
| TELM-03 | Phase 3 | Pending |
| TELM-04 | Phase 3 | Pending |
| TELM-05 | Phase 3 | Pending |
| GPUD-01 | Phase 3 | Pending |
| GPUD-02 | Phase 3 | Pending |
| GPUD-03 | Phase 3 | Pending |
| GPUD-04 | Phase 3 | Pending |
| GPUD-05 | Phase 3 | Pending |
| SRVC-01 | Phase 3 | Pending |
| SRVC-02 | Phase 3 | Pending |
| SRVC-03 | Phase 3 | Pending |
| SRVC-04 | Phase 3 | Pending |
| SRVC-05 | Phase 3 | Pending |

### Phase 4: Power & Scheduler

| Requirement | Phase | Status |
|-------------|-------|--------|
| SCHD-01 | Phase 4 | Pending |
| SCHD-02 | Phase 4 | Pending |
| SCHD-03 | Phase 4 | Pending |
| SCHD-04 | Phase 4 | Pending |
| SCHD-05 | Phase 4 | Pending |
| PWRP-01 | Phase 4 | Pending |
| PWRP-02 | Phase 4 | Pending |
| PWRP-03 | Phase 4 | Pending |
| PWRP-04 | Phase 4 | Pending |
| PWRP-05 | Phase 4 | Pending |
| PWRP-06 | Phase 4 | Pending |
| PWRP-07 | Phase 4 | Pending |
| PWRP-08 | Phase 4 | Pending |

### Phase 5: File System & Rollback

| Requirement | Phase | Status |
|-------------|-------|--------|
| FSYS-01 | Phase 5 | Pending |
| FSYS-02 | Phase 5 | Pending |
| FSYS-03 | Phase 5 | Pending |
| FSYS-04 | Phase 5 | Pending |
| FSYS-05 | Phase 5 | Pending |
| FSYS-06 | Phase 5 | Pending |
| FSYS-07 | Phase 5 | Pending |
| ROLL-01 | Phase 5 | Pending |
| ROLL-02 | Phase 5 | Pending |
| ROLL-03 | Phase 5 | Pending |
| ROLL-04 | Phase 5 | Pending |
| ROLL-05 | Phase 5 | Pending |

### Phase 6: Entry Point & CLI

| Requirement | Phase | Status |
|-------------|-------|--------|
| CLIE-01 | Phase 6 | Pending |
| CLIE-02 | Phase 6 | Pending |
| CLIE-03 | Phase 6 | Pending |
| CLIE-04 | Phase 6 | Pending |
| CLIE-05 | Phase 6 | Pending |
| CLIE-06 | Phase 6 | Pending |
| CLIE-07 | Phase 6 | Pending |

### Phase 7: Quality & Documentation

| Requirement | Phase | Status |
|-------------|-------|--------|
| QUAL-01 | Phase 7 | Pending |
| QUAL-02 | Phase 7 | Pending |
| QUAL-03 | Phase 7 | Pending |
| QUAL-04 | Phase 7 | Pending |
| QUAL-05 | Phase 7 | Pending |
| QUAL-06 | Phase 7 | Pending |
| QUAL-07 | Phase 7 | Pending |
| QUAL-08 | Phase 7 | Pending |
| QUAL-09 | Phase 7 | Pending |
| QUAL-10 | Phase 7 | Pending |
| QUAL-11 | Phase 7 | Pending |
| REPO-02 | Phase 7 | Pending |
| REPO-04 | Phase 7 | Pending |
| REPO-05 | Phase 7 | Pending |
| REPO-06 | Phase 7 | Pending |
| REPO-07 | Phase 7 | Pending |

**Coverage:**
- v1 requirements: 56 total
- Mapped to phases: 56 (100%) ✓
- Unmapped: 0
- Orphaned: 0

---
*Requirements defined: 2025-03-13*
*Last updated: 2026-03-13 after roadmap creation*
