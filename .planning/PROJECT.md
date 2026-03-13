# WinOptimizer PS1

## What This Is

A CLI-first, open-source PowerShell toolkit that transforms stock Windows 11 into a low-latency, high-throughput workstation environment. The tool encapsulates real-world kernel-level diagnosis, registry archaeology, and GPU tuning into a safe, idempotent, reversible automation layer. Designed for developers who want macOS-level UI fluidity without breaking WSL2, Hyper-V, or Docker toolchains.

## Core Value

**Safe, reversible Windows optimization that never breaks the developer virtualization stack.** If everything else fails, WSL2, Hyper-V, and Docker must continue working perfectly.

## Current State

**Version:** v1.0 Core Optimization Modules (shipped 2026-03-14)

**Delivered:**
- 5 optimization modules (Invoke-TelemetryBlock, Invoke-GpuDwmOptimize, Invoke-ServiceOptimize, Invoke-PowerPlanConfig, Invoke-SchedulerOptimize)
- 5 library helpers (Write-OptLog, Get-ActivePlanGuid, Save-RollbackEntry, Take-RegistryOwnership, Test-VirtStack)
- Safety infrastructure (System Restore Point, elevation check, PowerShell validation, virtualization validation)
- 3,492 lines of PowerShell code

**Modules Invoked Individually:** Entry point & CLI (Phase 6) not yet implemented — modules must be invoked directly

**Known Limitations:**
- No rollback functionality (rollback manifest entries created but no restore)
- No file system optimization
- Quality gates not validated

## Requirements

### Validated (v1.0)

- ✓ **SR-01**: System Restore Point creation before any changes (halts on failure) — v1.0
- ✓ **SR-02**: Administrator elevation check with self-relaunch — v1.0
- ✓ **SR-03**: PowerShell 5.1+ version validation — v1.0
- ✓ **SR-04**: Virtualization stack validation (WSL2/Hyper-V) pre and post execution — v1.0
- ✓ **TM-01**: Telemetry suppression (AllowTelemetry=0, disable AutoLogger sessions) — v1.0
- ✓ **TM-02**: Disable DiagTrack and dmwappushservice services — v1.0
- ✓ **TM-03**: Disable telemetry scheduled tasks — v1.0
- ✓ **GP-01**: Enable Hardware-Accelerated GPU Scheduling (HAGS) — v1.0
- ✓ **GP-02**: Disable Multi-Plane Overlay (MPO) — v1.0
- ✓ **GP-03**: Disable NvTelemetryContainer service — v1.0
- ✓ **SC-01**: Set Win32PrioritySeparation to 38 — v1.0
- ✓ **SC-02**: Disable CPU core parking (100% min processor state) — v1.0
- ✓ **SC-03**: Set min/max processor state to 100% on AC — v1.0
- ✓ **PP-01**: Detect and disable Modern Standby (S0) if present — v1.0
- ✓ **PP-02**: Duplicate and activate Ultimate Performance plan — v1.0
- ✓ **PP-03**: Set PCIe Link State Power Management to Off — v1.0
- ✓ **PP-04**: Disable USB Selective Suspend — v1.0
- ✓ **PP-05**: Detect OEM power services and create scheduled task countermeasure — v1.0
- ✓ **SV-01**: Disable telemetry services (7 specific services) — v1.0
- ✓ **SV-02**: Set background services to Manual (11 specific services) — v1.0
- ✓ **SV-03**: Protected services block (HvHost, vmms, WslService, etc.) — v1.0
- ✓ **RB-01**: Record all changes to JSON rollback manifest — v1.0
- ✓ **LG-01**: Structured JSONL logging for all operations — v1.0
- ✓ **LIB-01**: Write-OptLog centralized logging — v1.0
- ✓ **LIB-02**: Get-ActivePlanGuid regex extractor (locale-safe) — v1.0
- ✓ **LIB-03**: Save-RollbackEntry manifest writer — v1.0
- ✓ **LIB-04**: Take-RegistryOwnership for TrustedInstaller keys — v1.0
- ✓ **LIB-05**: Test-VirtStack WMI validation (no wsl.exe calls) — v1.0

### Active (v1.1)

- [ ] **RB-02**: Invoke-Rollback restores all values in reverse order
- [ ] **FS-01**: Disable NTFS Last Access Time updates
- [ ] **FS-02**: Set NTFS memoryusage to 2
- [ ] **FS-03**: Set NTFS MFT zone reservation to 2
- [ ] **FS-04**: Disable SysMain/Prefetch on NVMe systems
- [ ] **FS-05**: Configure Windows Search indexer exclusions
- [ ] **FS-06**: Set pagefile to fixed size (RAM × 1)
- [ ] **UX-01**: Interactive menu with color-coded output
- [ ] **UX-02**: Silent mode with -RunAll flag

### Out of Scope

- **Windows 10 support** — Windows 11 only due to Modern Standby and power plan differences
- **Enterprise/fleet management** — Single-user workstation focus
- **Mobile app or GUI** — CLI-first design
- **Game-mode specific tweaks** — Focus on workstation/developer use case
- **Non-administrator user scenarios** — Requires elevation by design
- **Cloud-provisioned machines** — Local optimization only
- **Locale-specific powercfg aliases** — Hardcoded GUIDs only

## Context

This project emerged from real-world Windows 11 optimization sessions on a high-spec laptop (Nvidia RTX 3070, Optimus). Each module addresses a specific kernel-level issue discovered through registry archaeology and error diagnosis:

1. **Execution Policy Override** — Machine-level GPO blocks global changes; solved with Process-scope bypass
2. **Ultimate Performance Plan Hidden** — Modern Standby (S0) suppresses high-performance plans; solved with PlatformAoAcOverride
3. **CPU Core Parsing Failure** — Locale-sensitive aliases fail; solved with regex GUID extraction
4. **TrustedInstaller Ownership** — Search key owned by TrustedInstaller; solved with ACL transfer helper
5. **OEM Power Plan Reassertion** — ASUS Armory Crate overrides plan at boot; solved with scheduled task countermeasure
6. **WSL Context Error** — wsl.exe fails under LOCAL_SYSTEM; solved with WMI-only validation
7. **Scheduled Task Parsing** — Backtick continuation breaks; solved with splatting ban

The tool distills these discoveries into reproducible, defensive automation that anyone can run safely.

## Constraints

- **PowerShell Version**: 5.1+ (Windows 11 bundled version) — Not compatible with PS 7+ differences
- **Platform**: Windows 11 only — Modern Standby detection and power plans differ from Windows 10
- **Elevation**: Administrator rights required — Script self-relaunches with elevation
- **GPU Target**: Nvidia RTX 3070 Optimus laptop (primary test hardware) — Extensible to other GPUs
- **License**: MIT — Open source, permissive
- **Execution Policy**: Process-scope bypass only — Never modify machine policy
- **Locale Safety**: Hardcoded GUIDs only — No locale-sensitive powercfg aliases
- **Virtualization**: Must preserve WSL2, Hyper-V, Docker — Validated pre/post execution
- **WSL Invocation**: Never call wsl.exe from elevated context — WMI and Get-Service only

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Process-scope execution policy bypass | Machine-level GPO blocks global changes; Process-scope bypass injects flag without writing to registry | ✓ Good — Validated in v1.0 |
| Regex GUID extraction for power plans | Locale-specific powercfg aliases fail on non-English Windows | ✓ Good — Validated in v1.0 |
| Hardcoded GUIDs for all power settings | Prevents alias resolution failures across locales | ✓ Good — Validated in v1.0 |
| WMI-only for virtualization validation | wsl.exe fails under LOCAL_SYSTEM (elevated context) | ✓ Good — Validated in v1.0 |
| Protected services block | HvHost, vmms, WslService, LxssManager, VmCompute, vmic* must never be touched | ✓ Good — Validated in v1.0 |
| JSON rollback manifest | Enables complete reversal of every change | ✓ Good — Entries created in v1.0, restore pending v1.1 |
| JSONL structured logging | Enables post-mortem analysis and debugging | ✓ Good — Validated in v1.0 |
| Splatted cmdlet parameters only | Backtick line continuation caused parsing failures in scheduled tasks | ✓ Good — Validated in v1.0 |
| OEM service detection in config.json | Extensible list of power management services (ASUS, Lenovo, Dell, HP) | ✓ Good — Validated in v1.0 |
| Idempotent operations | Running twice must produce same result; [SKIP] if already in desired state | ✓ Good — Validated in v1.0 |

---
*Last updated: 2026-03-14 after v1.0 milestone*
