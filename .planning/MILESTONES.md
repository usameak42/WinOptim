# WinOptimizer PS1 — Milestones

## v1.0: Core Optimization Modules

**Status:** ✅ SHIPPED 2026-03-14
**Phases:** 1-4
**Plans:** 11 total
**Timeline:** ~8 hours (2026-03-13 18:20 → 2026-03-14 01:57)

### What Was Delivered

Safe, reversible Windows 11 optimization toolkit with telemetry suppression, GPU/DWM optimization, service optimization, power plan configuration, and CPU scheduler optimization.

**Core Modules:**
- Invoke-TelemetryBlock.ps1 (492 lines) — Telemetry suppression
- Invoke-GpuDwmOptimize.ps1 (521 lines) — GPU/DWM optimization
- Invoke-ServiceOptimize.ps1 (540 lines) — Service optimization
- Invoke-PowerPlanConfig.ps1 (505 lines) — Power plan configuration
- Invoke-SchedulerOptimize.ps1 (518 lines) — CPU scheduler optimization

**Library Helpers:**
- Write-OptLog, Get-ActivePlanGuid, Save-RollbackEntry, Take-RegistryOwnership, Test-VirtStack

**Safety Infrastructure:**
- System Restore Point creation
- Administrator elevation detection
- PowerShell version validation
- Virtualization stack validation (WSL2/Hyper-V)

### Key Accomplishments

1. **Telemetry Suppression:** Disabled Windows telemetry via registry, AutoLogger sessions, services, and scheduled tasks
2. **GPU/DWM Optimization:** Enabled Hardware-Accelerated GPU Scheduling, disabled Multi-Plane Overlay
3. **Service Optimization:** Disabled telemetry services, set background services to Manual, protected virtualization services
4. **Power Plan Configuration:** Modern Standby detection/override, Ultimate Performance plan duplication, PCIe/USB power settings, OEM countermeasures
5. **CPU Scheduler Tuning:** Win32PrioritySeparation=38 for 3x foreground boost, CPU core parking disablement, processor state configuration, network interrupt moderation

### Technical Decisions

- Process-scope execution policy bypass (machine-level GPO blocks global changes)
- Regex GUID extraction for power plans (locale-specific aliases fail)
- Hardcoded GUIDs for all power settings (prevents alias resolution failures)
- WMI-only for virtualization validation (wsl.exe fails under LOCAL_SYSTEM)
- Protected services block (HvHost, vmms, WslService, LxssManager, VmCompute, vmic*)
- JSON rollback manifest + JSONL structured logging
- Splatted cmdlet parameters only (backtick continuation banned)

### Issues Resolved

1. Execution Policy Override — Machine-level GPO blocks global changes; solved with Process-scope bypass
2. Ultimate Performance Plan Hidden — Modern Standby (S0) suppresses high-performance plans; solved with PlatformAoAcOverride
3. CPU Core Parsing Failure — Locale-sensitive aliases fail; solved with regex GUID extraction
4. TrustedInstaller Ownership — Search key owned by TrustedInstaller; solved with ACL transfer helper
5. OEM Power Plan Reassertion — ASUS Armory Crate overrides plan at boot; solved with scheduled task countermeasure
6. WSL Context Error — wsl.exe fails under LOCAL_SYSTEM; solved with WMI-only validation
7. Scheduled Task Parsing — Backtick continuation breaks; solved with splatting ban

### Known Limitations

- No entry point & CLI (modules must be invoked individually)
- No rollback functionality (rollback manifest entries created but no restore)
- No file system optimization
- Quality gates not validated

### Metrics

| Metric | Value |
|--------|-------|
| Lines of Code | 3,492 PowerShell lines |
| Files Changed | 14 files |
| Git Range | c98585e → 4e4e21a |
| Commits | 48 commits |
| Requirements Completed | 39/56 (70%) |

---

*For full details, see:*
- `.planning/milestones/v1.0-ROADMAP.md`
- `.planning/milestones/v1.0-REQUIREMENTS.md`
