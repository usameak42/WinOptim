# WinOptimizer PS1

## What This Is

A CLI-first, open-source PowerShell toolkit that transforms stock Windows 11 into a low-latency, high-throughput workstation environment. The tool encapsulates real-world kernel-level diagnosis, registry archaeology, and GPU tuning into a safe, idempotent, reversible automation layer. Designed for developers who want macOS-level UI fluidity without breaking WSL2, Hyper-V, or Docker toolchains.

## Core Value

**Safe, reversible Windows optimization that never breaks the developer virtualization stack.** If everything else fails, WSL2, Hyper-V, and Docker must continue working perfectly.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] **SR-01**: System Restore Point creation before any changes (halts on failure)
- [ ] **SR-02**: Administrator elevation check with self-relaunch
- [ ] **SR-03**: PowerShell 5.1+ version validation
- [ ] **SR-04**: Virtualization stack validation (WSL2/Hyper-V) pre and post execution
- [ ] **TM-01**: Telemetry suppression (AllowTelemetry=0, disable AutoLogger sessions)
- [ ] **TM-02**: Disable DiagTrack and dmwappushservice services
- [ ] **TM-03**: Disable telemetry scheduled tasks
- [ ] **GP-01**: Enable Hardware-Accelerated GPU Scheduling (HAGS)
- [ ] **GP-02**: Disable Multi-Plane Overlay (MPO)
- [ ] **GP-03**: Disable NvTelemetryContainer service
- [ ] **SC-01**: Set Win32PrioritySeparation to 38
- [ ] **SC-02**: Disable CPU core parking (100% min processor state)
- [ ] **SC-03**: Set min/max processor state to 100% on AC
- [ ] **PP-01**: Detect and disable Modern Standby (S0) if present
- [ ] **PP-02**: Duplicate and activate Ultimate Performance plan
- [ ] **PP-03**: Set PCIe Link State Power Management to Off
- [ ] **PP-04**: Disable USB Selective Suspend
- [ ] **PP-05**: Detect OEM power services and create scheduled task countermeasure
- [ ] **FS-01**: Disable NTFS Last Access Time updates
- [ ] **FS-02**: Set NTFS memoryusage to 2
- [ ] **FS-03**: Set NTFS MFT zone reservation to 2
- [ ] **FS-04**: Disable SysMain/Prefetch on NVMe systems
- [ ] **FS-05**: Configure Windows Search indexer exclusions
- [ ] **FS-06**: Set pagefile to fixed size (RAM × 1)
- [ ] **SV-01**: Disable telemetry services (7 specific services)
- [ ] **SV-02**: Set background services to Manual (11 specific services)
- [ ] **SV-03**: Protected services block (HvHost, vmms, WslService, etc.)
- [ ] **RB-01**: Record all changes to JSON rollback manifest
- [ ] **RB-02**: Invoke-Rollback restores all values in reverse order
- [ ] **LG-01**: Structured JSONL logging for all operations
- [ ] **UX-01**: Interactive menu with color-coded output
- [ ] **UX-02**: Silent mode with -RunAll flag
- [ ] **LIB-01**: Write-OptLog centralized logging
- [ ] **LIB-02**: Get-ActivePlanGuid regex extractor (locale-safe)
- [ ] **LIB-03**: Save-RollbackEntry manifest writer
- [ ] **LIB-04**: Take-RegistryOwnership for TrustedInstaller keys
- [ ] **LIB-05**: Test-VirtStack WMI validation (no wsl.exe calls)

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
| Process-scope execution policy bypass | Machine-level GPO blocks global changes; Process-scope bypass injects flag without writing to registry | ✓ Good — PRD validated solution |
| Regex GUID extraction for power plans | Locale-specific powercfg aliases fail on non-English Windows | — Pending — Implementation required |
| Hardcoded GUIDs for all power settings | Prevents alias resolution failures across locales | — Pending — Implementation required |
| WMI-only for virtualization validation | wsl.exe fails under LOCAL_SYSTEM (elevated context) | ✓ Good — PRD validated solution |
| Protected services block | HvHost, vmms, WslService, LxssManager, VmCompute, vmic* must never be touched | — Pending — Implementation validation |
| JSON rollback manifest | Enables complete reversal of every change | — Pending — Implementation required |
| JSONL structured logging | Enables post-mortem analysis and debugging | — Pending — Implementation required |
| Splatted cmdlet parameters only | Backtick line continuation caused parsing failures in scheduled tasks | ✓ Good — PRD validated solution |
| OEM service detection in config.json | Extensible list of power management services (ASUS, Lenovo, Dell, HP) | — Pending — Implementation required |
| Idempotent operations | Running twice must produce same result; [SKIP] if already in desired state | — Pending — Implementation required |

---
*Last updated: 2025-03-13 after initialization*
