---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_phase: 03
current_plan: 03-01
status: planned
last_updated: "2026-03-13T15:30:00.000Z"
progress:
  total_phases: 7
  completed_phases: 2
  total_plans: 12
  completed_plans: 6
  planned_plans: 3
  percent: 50
---

# STATE: WinOptimizer PS1

**Project:** WinOptimizer PS1
**Last Updated:** 2026-03-13
**Current Phase:** 02
**Current Plan:** Not started

---

## Project Reference

**Core Value:** Safe, reversible Windows optimization that never breaks the developer virtualization stack. If everything else fails, WSL2, Hyper-V, and Docker must continue working perfectly.

**What This Is:** A CLI-first, open-source PowerShell toolkit that transforms stock Windows 11 into a low-latency, high-throughput workstation environment. The tool encapsulates real-world kernel-level diagnosis, registry archaeology, and GPU tuning into a safe, idempotent, reversible automation layer.

**Current Focus:** Implementing 7-phase roadmap to deliver complete Windows 11 optimization toolkit with telemetry suppression, power management, GPU tuning, file system optimization, and complete rollback capability.

---

## Current Position

**Phase:** 01 - Foundation & Libraries
**Plan:** 03 - Gap Closure (Issue Templates)
**Status:** Milestone complete
**Progress:** [██████████] 100%

### Phase Status

| Phase | Name | Plans | Status |
|-------|------|-------|--------|
| 1 | Foundation & Libraries | 3 | 3/3 complete ✓ |
| 2 | Safety Gates | TBD | Not started |
| 3 | Core Modules | TBD | Not started |
| 4 | Power & Scheduler | TBD | Not started |
| 5 | File System & Rollback | TBD | Not started |
| 6 | Entry Point & CLI | TBD | Not started |
| 7 | Quality & Documentation | TBD | Not started |

---

## Performance Metrics

**Requirements:** 56 v1 requirements defined
**Coverage:** 56/56 mapped to phases (100%) ✓
**Phases:** 7 phases derived from requirements
**Depth:** Standard (balanced grouping)

**Quality Gates:** 7 gates defined for Phase 7 validation
- QG-01: Idempotency
- QG-02: Rollback Integrity
- QG-03: Virtualization Safety
- QG-04: OEM Compatibility
- QG-05: Locale Safety
- QG-06: Modern Standby Detection
- QG-07: Silent Mode

---

## Accumulated Context

### Key Decisions

| Decision | Rationale | Status |
|----------|-----------|--------|
| Process-scope execution policy bypass | Machine-level GPO blocks global changes; Process-scope bypass injects flag without writing to registry | ✓ Validated in PRD |
| Regex GUID extraction for power plans | Locale-specific powercfg aliases fail on non-English Windows | ✓ Implementation required |
| Hardcoded GUIDs for all power settings | Prevents alias resolution failures across locales | ✓ Implementation required |
| WMI-only for virtualization validation | wsl.exe fails under LOCAL_SYSTEM (elevated context) | ✓ Validated in PRD |
| Protected services block | HvHost, vmms, WslService, LxssManager, VmCompute, vmic* must never be touched | ✓ Implementation required |
| JSON rollback manifest | Enables complete reversal of every change | ✓ Implementation required |
| JSONL structured logging | Enables post-mortem analysis and debugging | ✓ Implementation required |
| Splatted cmdlet parameters only | Backtick line continuation caused parsing failures in scheduled tasks | ✓ Validated in PRD |
| OEM service detection in config.json | Extensible list of power management services (ASUS, Lenovo, Dell, HP) | ✓ Implementation required |
| Idempotent operations | Running twice must produce same result; [SKIP] if already in desired state | ✓ Implementation required |
| GitHub issue template placeholders | Phase 1 placeholder templates; full enhancement in Phase 7 per REPO-07 | ✓ Implemented in 01-03 |
| Safety considerations in feature requests | System modifications require safety impact analysis | ✓ Implemented in 01-03 |
| Phase 01-foundation-libraries P01 | Repository scaffold with 17 files across 7 directories | ✓ Complete |
| Phase 01-foundation-libraries P02 | Config services.json with OEM power management services | ✓ Complete |
| Phase 01-foundation-libraries P03 | GitHub issue template placeholders (gap closure) | ✓ Complete |
| Phase 01-foundation-libraries P03 | 1min | 2 tasks | 2 files |
| Phase 02-safety-gates P03 | 1min | 2 tasks | 1 files |
| Phase 02-safety-gates P02 | 2min | 1 tasks | 1 files |
| Phase 02-safety-gates P01 | 1min | 2 tasks | 2 files |

### Critical Constraints

- **PowerShell Version:** 5.1+ (Windows 11 bundled) — Not compatible with PS 7+ differences
- **Platform:** Windows 11 only — Modern Standby detection and power plans differ from Windows 10
- **Elevation:** Administrator rights required — Script self-relaunches with elevation
- **GPU Target:** Nvidia RTX 3070 Optimus laptop (primary test hardware) — Extensible to other GPUs
- **License:** MIT — Open source, permissive
- **Execution Policy:** Process-scope bypass only — Never modify machine policy
- **Locale Safety:** Hardcoded GUIDs only — No locale-sensitive powercfg aliases
- **Virtualization:** Must preserve WSL2, Hyper-V, Docker — Validated pre/post execution
- **WSL Invocation:** Never call wsl.exe from elevated context — WMI and Get-Service only

### Implementation Order (Non-Negotiable)

Per PRD Section 3.4:
1. Repository structure scaffold (all dirs and files)
2. lib/ (all 5 helpers)
3. config/services.json
4. modules/ in order: Telemetry → GPU/DWM → Scheduler → Power Plan → File System → Rollback
5. WinOptimizer.ps1 (entry point)
6. tests/ (Pester stubs)
7. Documentation files

### Known Pitfalls (From Research)

1. **Modern Standby (S0)** — Hides Ultimate Performance plan; must detect and fix before power plan operations
2. **Locale powercfg aliases** — Fail on non-English Windows; use hardcoded GUIDs only
3. **Protected services** — Never touch HvHost, vmms, WslService, LxssManager, VmCompute, vmic*
4. **TrustedInstaller ACL** — Windows Search keys require ownership transfer before modification
5. **OEM power reassertion** — ASUS/Lenovo/Dell/HP services override power plan at boot; create scheduled task countermeasure
6. **WSL LOCAL_SYSTEM error** — Never call wsl.exe from elevated context; use WMI only
7. **Backtick continuation** — Banned from codebase; causes parsing failures

### Architecture Overview

```
Entry Point (WinOptimizer.ps1)
    ↓
├── lib/ (5 shared helpers)
│   ├── Write-OptLog.ps1
│   ├── Get-ActivePlanGuid.ps1
│   ├── Save-RollbackEntry.ps1
│   ├── Take-RegistryOwnership.ps1
│   └── Test-VirtStack.ps1
├── modules/ (7 independent modules)
│   ├── Invoke-TelemetryBlock.ps1
│   ├── Invoke-GpuDwmOptimize.ps1
│   ├── Invoke-SchedulerOptimize.ps1
│   ├── Invoke-PowerPlanConfig.ps1
│   ├── Invoke-FileSystemOptimize.ps1
│   ├── Invoke-ServiceOptimize.ps1
│   └── Invoke-Rollback.ps1
├── config/services.json (extensible service lists)
└── %TEMP%\WinOptimizer/ (logs, rollback manifests)
```

---

## Session Continuity

**Last Session:** 2026-03-13T15:30:00.000Z
**Current Session:** 2026-03-13 (Phase 3 Planning)
**Next Action:** Execute Phase 3 (/gsd:execute-phase 03)

### Completed Work

- [x] Requirements definition (56 v1 requirements)
- [x] Research synthesis (stack, features, architecture, pitfalls)
- [x] Roadmap creation (7 phases, 100% coverage)
- [x] State initialization (this file)
- [x] Phase 1 Plan 01: Repository scaffold (17 files, 7 directories)
- [x] Phase 1 Plan 02: Configuration services.json (OEM power services)
- [x] Phase 1 Plan 03: GitHub issue template placeholders (gap closure)
- [x] Phase 2 Plan 01: System Restore Point creation
- [x] Phase 2 Plan 02: PowerShell version validation
- [x] Phase 2 Plan 03: Virtualization stack validation (WSL2/Hyper-V)
- [x] Phase 3 Research: Telemetry, Services, GPU/DWM modules
- [x] Phase 3 Plan 01: Telemetry suppression module (TELM-01 through TELM-05)
- [x] Phase 3 Plan 02: GPU/DWM optimization module (GPUD-01 through GPUD-05)
- [x] Phase 3 Plan 03: Service optimization module (SRVC-01 through SRVC-05)

### Active Work

- Currently: Phase 3 planned (3 plans, 7 tasks, Wave 1)
- Next: Execute Phase 3 (Implement telemetry, GPU/DWM, and service modules)

### Blockers

None identified. Ready to proceed with Phase 3 execution.

### Todos

- [x] Plan Phase 1: Foundation & Libraries
- [x] Execute Phase 1: Repository structure, lib/ helpers, config files, templates
- [x] Plan Phase 2: Safety Gates
- [x] Execute Phase 2: Pre-flight validation infrastructure
- [x] Plan Phase 3: Core Modules (Telemetry, GPU/DWM, Services)
- [ ] Execute Phase 3: Telemetry, GPU/DWM, and service optimization modules
- [ ] Plan Phase 4: Power & Scheduler
- [ ] [Continue through all 7 phases]

---

## Notes

**Project Context:** This project emerged from real-world Windows 11 optimization sessions on a high-spec laptop (Nvidia RTX 3070, Optimus). Each module addresses a specific kernel-level issue discovered through registry archaeology and error diagnosis.

**Real-World Issues Addressed:**
1. Execution Policy Override — Machine-level GPO blocks global changes; solved with Process-scope bypass
2. Ultimate Performance Plan Hidden — Modern Standby (S0) suppresses high-performance plans; solved with PlatformAoAcOverride
3. CPU Core Parsing Failure — Locale-sensitive aliases fail; solved with regex GUID extraction
4. TrustedInstaller Ownership — Search key owned by TrustedInstaller; solved with ACL transfer helper
5. OEM Power Plan Reassertion — ASUS Armory Crate overrides plan at boot; solved with scheduled task countermeasure
6. WSL Context Error — wsl.exe fails under LOCAL_SYSTEM; solved with WMI-only validation
7. Scheduled Task Parsing — Backtick continuation breaks; solved with splatting ban

**Estimated Scope:** ~950 lines of PowerShell code across 7 modules, 5 helpers, and 1 entry point.

---

*Last updated: 2026-03-13*
*State file initialized. Ready for Phase 1 planning.*
