# ROADMAP: WinOptimizer PS1

**Created:** 2026-03-13
**Last Updated:** 2026-03-13
**Depth:** Standard (7 phases)
**Coverage:** 56/56 v1 requirements mapped ✓

---

## Progress Summary

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation & Libraries | 0/2 | Not started | - |
| 2. Safety Gates | 0/2 | Not started | - |
| 3. Core Modules | 0/3 | Not started | - |
| 4. Power & Scheduler | 0/2 | Not started | - |
| 5. File System & Rollback | 0/2 | Not started | - |
| 6. Entry Point & CLI | 0/2 | Not started | - |
| 7. Quality & Documentation | 0/4 | Not started | - |

---

## Phases

- [ ] **Phase 1: Foundation & Libraries** - Repository structure, library helpers, and configuration files
- [ ] **Phase 2: Safety Gates** - Pre-flight validation and safety infrastructure
- [ ] **Phase 3: Core Modules** - Telemetry, Services, and GPU/DWM optimization modules
- [ ] **Phase 4: Power & Scheduler** - Power Plan and CPU Scheduler optimization modules
- [ ] **Phase 5: File System & Rollback** - File System optimization and Rollback module
- [ ] **Phase 6: Entry Point & CLI** - Main entry point, interactive menu, and CLI interface
- [ ] **Phase 7: Quality & Documentation** - Code quality validation, tests, documentation, and quality gates

---

## Phase Details

### Phase 1: Foundation & Libraries

**Goal:** Establish repository structure, create reusable library helpers, and prepare configuration infrastructure

**Depends on:** Nothing (first phase)

**Requirements:** REPO-01, REPO-03, LIBR-01, LIBR-02, LIBR-03, LIBR-04, LIBR-05

**Success Criteria** (what must be TRUE):
1. Repository structure matches PRD Section 3.1 exactly (all directories and placeholder files exist)
2. All 5 library helper functions exist in lib/ directory with proper function signatures
3. config/services.json contains complete service lists (Disabled, Manual, OEM) for all major vendors
4. Each library helper can be imported and executed independently with test parameters

**Plans:** TBD

---

### Phase 2: Safety Gates

**Goal:** Implement pre-flight validation infrastructure that ensures safe execution environment

**Depends on:** Phase 1 (lib/ helpers required for virtualization validation)

**Requirements:** SAFE-01, SAFE-02, SAFE-03, SAFE-04

**Success Criteria** (what must be TRUE):
1. Script self-relaunches with Administrator elevation if not running as admin
2. Script validates PowerShell 5.1+ version and exits with clear error if unsupported
3. Script creates named System Restore Point before any module execution and halts on failure
4. Script validates WSL2 and Hyper-V state via WMI before and after all operations (never wsl.exe)

**Plans:** TBD

---

### Phase 3: Core Modules

**Goal:** Implement telemetry suppression, service optimization, and GPU/DWM optimization modules

**Depends on:** Phase 2 (safety gates), Phase 1 (lib/ helpers for logging and rollback)

**Requirements:** TELM-01 through TELM-05, SRVC-01 through SRVC-05, GPUD-01 through GPUD-05

**Success Criteria** (what must be TRUE):
1. Telemetry module disables all telemetry services, AutoLogger sessions, and scheduled tasks
2. Service module disables telemetry services, sets background services to Manual, and never touches protected services
3. GPU module enables HAGS, disables MPO, handles Nvidia GPU detection, and validates HAGS post-reboot
4. All modules record prior state to rollback manifest before making changes
5. All modules emit structured JSONL log entries for every operation

**Plans:** TBD

---

### Phase 4: Power & Scheduler

**Goal:** Implement power plan configuration and CPU scheduler optimization modules

**Depends on:** Phase 1 (lib/ helpers for regex GUID extraction and rollback), Phase 2 (safety gates)

**Requirements:** PWRP-01 through PWRP-08, SCHD-01 through SCHD-05

**Success Criteria** (what must be TRUE):
1. Power Plan module detects Modern Standby (S0) state and applies PlatformAoAcOverride fix if detected
2. Power Plan module duplicates and activates Ultimate Performance plan with custom name
3. Power Plan module detects OEM power services and creates scheduled task countermeasure
4. Scheduler module sets Win32PrioritySeparation to 38 using registry values
5. Scheduler module disables CPU core parking and sets processor states to 100% using hardcoded GUIDs (no locale-sensitive aliases)
6. All power plan operations use regex GUID extraction (Get-ActivePlanGuid) for locale safety

**Plans:** TBD

---

### Phase 5: File System & Rollback

**Goal:** Implement file system optimization module and complete rollback functionality

**Depends on:** Phase 1 (lib/ helpers for rollback manifest), Phase 3 (modules generate rollback data)

**Requirements:** FSYS-01 through FSYS-07, ROLL-01 through ROLL-05

**Success Criteria** (what must be TRUE):
1. File System module disables NTFS Last Access Time updates and configures NTFS memory settings
2. File System module detects system drive bus type (NVMe/SATA/HDD) and conditionally disables SysMain/Prefetch
3. File System module configures Windows Search indexer exclusions and sets pagefile to fixed size
4. Rollback module can read rollback manifest JSON from specified path
5. Rollback module restores all registry values and service StartType values in reverse chronological order
6. Rollback module removes scheduled task if created and reports each restored item with before/after values

**Plans:** TBD

---

### Phase 6: Entry Point & CLI

**Goal:** Implement main entry point with interactive menu, silent mode, and orchestration logic

**Depends on:** All previous phases (all modules must exist before entry point can invoke them)

**Requirements:** CLIE-01 through CLIE-07

**Success Criteria** (what must be TRUE):
1. Entry point applies Process-scope execution policy bypass (never machine-level)
2. Entry point initializes session state (paths, timestamps, log file, rollback manifest)
3. Entry point displays interactive menu with all modules, index numbers, descriptions, estimated time, and risk levels
4. Entry point supports -Silent -RunAll flags for non-interactive automation
5. Entry point supports -Rollback -ManifestPath parameter to invoke rollback standalone
6. Entry point uses color-coded terminal output (SUCCESS/WARNING/ERROR/INFO/ACTION/SKIP) for all operations

**Plans:** TBD

---

### Phase 7: Quality & Documentation

**Goal:** Validate code quality standards, create test infrastructure, write documentation, and verify all quality gates

**Depends on:** All previous phases (full implementation required for quality validation)

**Requirements:** QUAL-01 through QUAL-11, REPO-02, REPO-04, REPO-05, REPO-06, REPO-07

**Success Criteria** (what must be TRUE):
1. All operations check current state first and emit [SKIP] if already in desired state (idempotency)
2. All modules call Save-RollbackEntry before every destructive operation
3. All modules call Write-OptLog after every operation with full field population
4. All .ps1 files include #Requires -Version 5.1 and functions include [CmdletBinding()]
5. Zero backtick line continuation exists in codebase (splatting @{} used instead)
6. Zero locale-sensitive powercfg aliases exist (hardcoded GUIDs only)
7. Zero wsl.exe invocation from elevated context exists (WMI and Get-Service only)
8. Protected services block is enforced (HvHost, vmms, WslService, LxssManager, VmCompute, vmic* never touched)
9. All files use 4-space indentation with inline comments and #region/#endregion blocks
10. tests/ directory contains Pester stubs for Test-Modules.ps1 and Test-Rollback.ps1
11. README.md, CONTRIBUTING.md, CHANGELOG.md, and GitHub issue templates exist and follow PRD structure
12. All quality gates pass (Idempotency, Rollback Integrity, Virtualization Safety, OEM Compatibility, Locale Safety, Modern Standby Detection, Non-Interactive Mode)

**Plans:** TBD

---

## Quality Gates

These gates must be validated in Phase 7 before project is considered complete:

- **QG-01 Idempotency**: Running the entire script twice produces zero changes on second run (all [SKIP])
- **QG-02 Rollback Integrity**: Apply all modules, run rollback, verify all values restored to original state
- **QG-03 Virtualization Safety**: Confirm Docker, WSL2, Hyper-V work perfectly after full execution
- **QG-04 OEM Compatibility**: Test on ASUS, Lenovo, Dell laptops with OEM power services
- **QG-05 Locale Safety**: Test on Turkish, German Windows 11 builds (no powercfg alias failures)
- **QG-06 Modern Standby**: Confirm S0 detection works on both S0 and S3 firmware
- **QG-07 Silent Mode**: Run `-Silent -RunAll`; confirm all modules execute without prompts

---

## Implementation Order

Per PRD Section 3.4, implementation follows this strict sequence:

1. **Repository structure scaffold** (all dirs and files)
2. **lib/** (all 5 helpers: Write-OptLog, Get-ActivePlanGuid, Save-RollbackEntry, Take-RegistryOwnership, Test-VirtStack)
3. **config/services.json** (Disabled list, Manual list, OEM entries)
4. **modules/** in this order:
   - Invoke-TelemetryBlock.ps1
   - Invoke-GpuDwmOptimize.ps1
   - Invoke-SchedulerOptimize.ps1
   - Invoke-PowerPlanConfig.ps1
   - Invoke-FileSystemOptimize.ps1
   - Invoke-Rollback.ps1
5. **WinOptimizer.ps1** (entry point)
6. **tests/** (Pester stubs)
7. **Documentation files** (README.md, CONTRIBUTING.md, CHANGELOG.md, GitHub templates)

---

## Dependencies

```
Phase 1 (Foundation)
    ↓
Phase 2 (Safety Gates) ← Requires Phase 1 lib/ helpers
    ↓
Phase 3 (Core Modules) ← Requires Phase 1 lib/, Phase 2 safety
    ↓
Phase 4 (Power & Scheduler) ← Requires Phase 1 lib/, Phase 2 safety
    ↓
Phase 5 (File System & Rollback) ← Requires Phase 1 lib/, Phase 3 modules
    ↓
Phase 6 (Entry Point & CLI) ← Requires all modules (3, 4, 5)
    ↓
Phase 7 (Quality & Docs) ← Requires full implementation
```

---

## Coverage Validation

**Total v1 requirements:** 56
**Requirements mapped:** 56 (100%) ✓

### Requirement Mapping by Category

| Category | Count | Phase |
|----------|-------|-------|
| Safety Gates | 4 | Phase 2 |
| Library Helpers | 5 | Phase 1 |
| Telemetry Module | 5 | Phase 3 |
| GPU/DWM Module | 5 | Phase 3 |
| Service Module | 5 | Phase 3 |
| Scheduler Module | 5 | Phase 4 |
| Power Plan Module | 8 | Phase 4 |
| File System Module | 7 | Phase 5 |
| Rollback Module | 5 | Phase 5 |
| Entry Point & CLI | 7 | Phase 6 |
| Code Quality | 11 | Phase 7 |
| Repository & Docs | 7 | Phase 7 |

**No orphaned requirements. No duplicates. All requirements mapped to exactly one phase.**

---

*Last updated: 2026-03-13*
*Next action: Plan Phase 1 (/gsd:plan-phase 1)*
