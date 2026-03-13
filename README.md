# WinOptimizer PS1

> Safe, reversible Windows 11 optimization for developer workstations

A CLI-first, open-source PowerShell toolkit that transforms stock Windows 11 into a low-latency, high-throughput workstation environment. The tool encapsulates real-world kernel-level diagnosis, registry archaeology, and GPU tuning into a safe, idempotent, reversible automation layer.

## Core Value

**Safe, reversible Windows optimization that never breaks the developer virtualization stack.**

If everything else fails, WSL2, Hyper-V, and Docker must continue working perfectly.

## What This Does

WinOptimizer PS1 addresses specific kernel-level issues discovered through real-world Windows 11 optimization sessions:

1. **Execution Policy Override** — Machine-level GPO blocks global changes; solved with Process-scope bypass
2. **Ultimate Performance Plan Hidden** — Modern Standby (S0) suppresses high-performance plans; solved with PlatformAoAcOverride
3. **CPU Core Parsing Failure** — Locale-sensitive aliases fail; solved with regex GUID extraction
4. **TrustedInstaller Ownership** — Search key owned by TrustedInstaller; solved with ACL transfer helper
5. **OEM Power Plan Reassertion** — ASUS Armory Crate overrides plan at boot; solved with scheduled task countermeasure
6. **WSL Context Error** — wsl.exe fails under LOCAL_SYSTEM; solved with WMI-only validation
7. **Scheduled Task Parsing** — Backtick continuation breaks; solved with splatting ban

## Requirements

- **Operating System:** Windows 11 only (not Windows 10)
- **PowerShell:** 5.1+ (built into Windows 11)
- **Privileges:** Administrator rights (script self-relaunches with elevation)
- **Hardware:** Nvidia RTX 3070 Optimus laptop (primary target; extensible to other GPUs)

## Installation

```powershell
# Clone the repository
git clone https://github.com/yourusername/WinOptim.git
cd WinOptim

# Run the optimizer (will prompt for elevation)
.\WinOptimizer.ps1
```

## Modules

WinOptimizer PS1 consists of 7 optimization modules:

### Invoke-TelemetryBlock (TELM-01 through TELM-05)

Suppresses Windows telemetry and data collection:
- Sets `AllowTelemetry` registry value to 0
- Disables AutoLogger sessions (AutoLogger-Diagtrack-Listener, CloudExperienceHost)
- Stops and disables DiagTrack and dmwappushservice services
- Disables telemetry scheduled tasks
- **Rollback:** Restores registry values, re-enables services, re-enables scheduled tasks

### Invoke-GpuDwmOptimize (GPUD-01 through GPUD-05)

Optimizes GPU and Desktop Window Manager for reduced latency:
- Enables Hardware-Accelerated GPU Scheduling (HAGS)
- Disables Multi-Plane Overlay (MPO)
- Disables NvTelemetryContainer service
- Configures GPU and DWM registry settings
- **Rollback:** Disables HAGS, re-enables MPO, re-enables NvTelemetryContainer, restores registry values

### Invoke-ServiceOptimize (SRVC-01 through SRVC-05)

Disables unnecessary background services:
- Disables 7 telemetry services (DiagTrack, dmwappushservice, etc.)
- Sets 11 background services to Manual startup type
- Implements protected services block (never touches HvHost, vmms, WslService, etc.)
- **Rollback:** Re-enables services, restores original startup types

### Invoke-PowerPlanConfig (PWRP-01 through PWRP-08)

Configures high-performance power settings:
- Detects and overrides Modern Standby (S0) via PlatformAoAcOverride
- Duplicates Ultimate Performance plan (fallback to High Performance)
- Renames plan to "WinOptimizer Ultimate"
- Sets PCIe Link State Power Management to Off
- Disables USB Selective Suspend
- Detects OEM power services (ASUS, Lenovo, Dell, HP)
- Creates scheduled task countermeasures for OEM interference
- **Rollback:** Restores S0 registry, deletes custom plan, re-enables OEM services, removes scheduled task

### Invoke-SchedulerOptimize (SCHD-01 through SCHD-05)

Optimizes CPU scheduler for foreground responsiveness:
- Sets Win32PrioritySeparation to 38 (variable quanta, short intervals, 3x foreground boost)
- Disables CPU core parking (user choice: all cores/logical cores/AC only/skip)
- Sets processor min/max state to 100% on AC power
- Detects network adapters via WMI
- Configures interrupt moderation per adapter (user prompt per adapter)
- **Rollback:** Restores Win32PrioritySeparation, restores core parking, restores processor states, restores interrupt moderation

### Invoke-FileSystemOptimize (FSYS-01 through FSYS-06)

*Coming in v1.1*

### Invoke-Rollback (ROLL-01, ROLL-02)

*Coming in v1.1*

## Safety Features

### Idempotency
- Running twice produces `[SKIP]` for already-configured settings
- Registry values checked before modification
- Existing power plans handled gracefully (reuse/delete/cancel)

### Rollback Manifest
- All changes recorded to `%TEMP%\WinOptimizer\rollback-manifest.jsonl`
- Includes original values, data types, and change order
- Rollback reverses changes in reverse application order

### Structured Logging
- JSONL logging to `%TEMP%\WinOptimizer\WinOptimizer.log`
- Complete audit trail for post-mortem analysis

### Virtualization Safety
- Validates WSL2, Hyper-V, and Docker before execution
- Re-validates after execution (must pass to succeed)
- Never touches protected services (HvHost, vmms, WslService, LxssManager, VmCompute, vmic*)

### Locale Safety
- Hardcoded GUIDs only (no locale-sensitive powercfg aliases)
- Works on non-English Windows installations

## Usage Examples

### Run All Optimizations
```powershell
.\WinOptimizer.ps1
```

### Run Specific Module
```powershell
.\modules\Invoke-TelemetryBlock.ps1
```

### View Rollback Manifest
```powershell
Get-Content $env:TEMP\WinOptimizer\rollback-manifest.jsonl | ConvertFrom-Json
```

### View Logs
```powershell
Get-Content $env:TEMP\WinOptimizer\WinOptimizer.log
```

## Quality Gates

All optimizations must pass these quality gates:

1. **Idempotency** — Running twice produces same result
2. **Rollback Integrity** — All changes reversible
3. **Virtualization Safety** — WSL2/Hyper-V/Docker preserved
4. **OEM Compatibility** — Detects and counters OEM interference
5. **Locale Safety** — Works on non-English systems
6. **Modern Standby Detection** — Handles S0 systems correctly
7. **Non-Interactive Mode** — Supports `-RunAll` flag for automation

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes (follow PowerShell best practices)
4. Submit a pull request

## License

MIT License — See LICENSE file for details

## Acknowledgments

This project emerged from real-world Windows 11 optimization sessions on high-spec laptops. Each module addresses a specific kernel-level issue discovered through registry archaeology and error diagnosis.

The tool distills these discoveries into reproducible, defensive automation that anyone can run safely.

---

**Version:** v1.0.0
**Status:** Production Ready (Phases 1-4 complete)
**PowerShell:** 5.1+
**Platform:** Windows 11 only
