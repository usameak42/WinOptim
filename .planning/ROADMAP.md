# ROADMAP: WinOptimizer PS1

**Created:** 2026-03-13
**Last Updated:** 2026-03-14
**Depth:** Standard (7 phases)
**Coverage:** 56/56 v1 requirements mapped ✓

---

## Milestones

- ✅ **v1.0 Core Optimization Modules** — Phases 1-4 (shipped 2026-03-14)
- 📋 **v1.1 Complete Toolkit** — Phases 5-7 (planned)

---

## Progress Summary

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation & Libraries | 3/3 | Complete | 2026-03-13 |
| 2. Safety Gates | 3/3 | Complete | 2026-03-13 |
| 3. Core Modules | 3/3 | Complete | 2026-03-13 |
| 4. Power & Scheduler | 2/2 | Complete | 2026-03-14 |
| 5. File System & Rollback | 0/2 | Not started | - |
| 6. Entry Point & CLI | 0/2 | Not started | - |
| 7. Quality & Documentation | 0/4 | Not started | - |

---

## Phases

<details>
<summary>✅ v1.0 Core Optimization Modules (Phases 1-4) — SHIPPED 2026-03-14</summary>

**See:** `.planning/milestones/v1.0-ROADMAP.md` for full details

- [x] Phase 1: Foundation & Libraries (3/3 plans) — Repository structure, library helpers, configuration files
- [x] Phase 2: Safety Gates (3/3 plans) — Pre-flight validation infrastructure
- [x] Phase 3: Core Modules (3/3 plans) — Telemetry, Services, and GPU/DWM optimization modules
- [x] Phase 4: Power & Scheduler (2/2 plans) — Power Plan and CPU Scheduler optimization modules

**Delivered:** 5 modules, 5 library helpers, safety infrastructure, 3,492 LOC

</details>

### 📋 Phase 5: File System & Rollback (Planned)

**Goal:** Implement file system optimization module and complete rollback functionality

**Depends on:** Phase 1 (lib/ helpers for rollback manifest), Phase 3 (modules generate rollback data)

**Requirements:** FSYS-01 through FSYS-07, ROLL-01 through ROLL-05

**Plans:** TBD

---

### 📋 Phase 6: Entry Point & CLI (Planned)

**Goal:** Implement main entry point with interactive menu, silent mode, and orchestration logic

**Depends on:** All previous phases (all modules must exist before entry point can invoke them)

**Requirements:** CLIE-01 through CLIE-07

**Plans:** TBD

---

### 📋 Phase 7: Quality & Documentation (Planned)

**Goal:** Validate code quality standards, create test infrastructure, write documentation, and verify all quality gates

**Depends on:** All previous phases (full implementation required for quality validation)

**Requirements:** QUAL-01 through QUAL-11, REPO-02, REPO-04, REPO-05, REPO-06

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

1. **Repository structure scaffold** (all dirs and files) ✅
2. **lib/** (all 5 helpers) ✅
3. **config/services.json** ✅
4. **modules/** in this order:
   - Invoke-TelemetryBlock.ps1 ✅
   - Invoke-GpuDwmOptimize.ps1 ✅
   - Invoke-ServiceOptimize.ps1 ✅
   - Invoke-PowerPlanConfig.ps1 ✅
   - Invoke-SchedulerOptimize.ps1 ✅
   - Invoke-FileSystemOptimize.ps1 (Phase 5)
   - Invoke-Rollback.ps1 (Phase 5)
5. **WinOptimizer.ps1** (entry point) (Phase 6)
6. **tests/** (Pester stubs) (Phase 7)
7. **Documentation files** (Phase 7)

---

## Dependencies

```
Phase 1 (Foundation) ✅
    ↓
Phase 2 (Safety Gates) ✅ ← Requires Phase 1 lib/ helpers
    ↓
Phase 3 (Core Modules) ✅ ← Requires Phase 1 lib/, Phase 2 safety
    ↓
Phase 4 (Power & Scheduler) ✅ ← Requires Phase 1 lib/, Phase 2 safety
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

| Category | Count | Phase | Status |
|----------|-------|-------|--------|
| Safety Gates | 4 | Phase 2 | ✅ Complete |
| Library Helpers | 5 | Phase 1 | ✅ Complete |
| Telemetry Module | 5 | Phase 3 | ✅ Complete |
| GPU/DWM Module | 5 | Phase 3 | ✅ Complete |
| Service Module | 5 | Phase 3 | ✅ Complete |
| Scheduler Module | 5 | Phase 4 | ✅ Complete |
| Power Plan Module | 8 | Phase 4 | ✅ Complete |
| File System Module | 7 | Phase 5 | 📋 Planned |
| Rollback Module | 5 | Phase 5 | 📋 Planned |
| Entry Point & CLI | 7 | Phase 6 | 📋 Planned |
| Code Quality | 11 | Phase 7 | 📋 Planned |
| Repository & Docs | 7 | Phase 7 | 📋 Planned |

**No orphaned requirements. No duplicates. All requirements mapped to exactly one phase.**

---

*Last updated: 2026-03-14*
*Next action: Plan Phase 5 (/gsd:plan-phase 5) or start next milestone (/gsd:new-milestone)*
