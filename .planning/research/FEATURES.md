# Features Research: Windows Optimization Domain

**Confidence:** High — PRD modules battle-tested from real-world deployments

## Feature Categories

### Table Stakes (Must Have)

Users expect these from any Windows optimization tool:

| Feature | Description | Complexity | Dependencies |
|---------|-------------|------------|--------------|
| **Execution Policy Bypass** | Process-scope bypass to run without global policy changes | Low | None |
| **Elevation Check** | Self-relaunch with Administrator privileges | Low | None |
| **System Restore Point** | Named restore point before any changes (halts on failure) | Low | None |
| **Telemetry Suppression** | Disable DiagTrack, AutoLogger sessions, scheduled tasks | Medium | Registry, Services |
| **Rollback Capability** | JSON manifest of all changes with reverse-order restoration | High | Registry, Services |
| **Structured Logging** | JSONL logging with timestamp, module, operation, target, values | Low | File I/O |
| **Idempotent Operations** | Skip if already in desired state; [SKIP] output | Medium | State checking |

### Differentiators (Competitive Advantage)

Features that distinguish WinOptimizer PS1 from alternatives:

| Feature | Description | User Value |
|---------|-------------|------------|
| **Virtualization Safety** | Pre/post WSL2/Hyper-V validation via WMI (never wsl.exe) | Docker/WSL users can optimize without fear |
| **Locale-Safe GUID Extraction** | Regex parser for powercfg; hardcoded GUIDs for all settings | Works on Turkish, German, any Windows locale |
| **OEM Countermeasures** | Detect Armory Crate, Lenovo Vantage, Dell Command; create scheduled task to reassert power plan | Solves ASUS/Lenovo/Dell/HP power plan reassertion |
| **Modern Standby Detection** | Detect S0 via PlatformAoAcOverride; apply fix; prompt for reboot | Unlocks Ultimate Performance plan on S0 systems |
| **TrustedInstaller ACL Helper** | Programmatic ownership transfer for Windows Search keys | Solves registry permission errors |
| **Protected Services Block** | Hardcoded blocklist; never touch HvHost, vmms, WslService, etc. | Guarantees Hyper-V/WSL integrity |
| **Developer-First Design** | Optimizes for low-latency desktop without breaking dev toolchains | Unlike gaming optimizers that disable Hyper-V |

### Anti-Features (Deliberately NOT Building)

| Feature | Reason to Exclude |
|---------|-------------------|
| **Visual Effects Toggling** | Users want windows animations; optimizes latency, not aesthetics |
| **Service Disabling Beyond Telemetry** | Aggressive service disabling breaks features; conservative approach |
| **Registry Cleaners** | High risk, low reward; focused optimization only |
| **Game Mode / GPU Overclock** | Out of scope; use vendor tools (MSI Afterburner, NVCP) |
| **Network Optimization** | Too variable; user-specific; can break connectivity |
| **Windows 10 Support** | Different power management; modern standby not present; focus on Win11 |
| **GUI Interface** | CLI-first; simpler, faster, more scriptable |
| **Cloud/Fleet Management** | Single-user workstation focus |
| **Automatic Reboot Handling** | Safety first; user confirms reboot after S0 fix |
| **Third-Party Driver Updates** | Out of scope; use Windows Update or vendor tools |

## Module Breakdown

### Module 1 — Telemetry & AutoLogger Suppression
**Purpose:** Eliminate background I/O from telemetry flushing
**Risk:** Low
**Duration:** ~30 seconds

Operations:
- Registry: `AllowTelemetry = 0`
- AutoLogger: Disable Diagtrack-Listener, DiagLog, SQMLogger
- Services: Stop/disable DiagTrack, dmwappushservice
- Scheduled Tasks: Disable CompatibilityAppraiser, ProgramDataUpdater, Consolidator, UsbCeip

### Module 2 — GPU & DWM Optimization
**Purpose:** Enable hardware GPU scheduling, disable MPO micro-stutters
**Risk:** Medium (requires reboot for HAGS)
**Duration:** ~1 minute

Operations:
- Registry: `HwSchMode = 2` (HAGS enable)
- Registry: `OverlayTestMode = 5` (MPO disable)
- Service: Disable NvTelemetryContainer
- Validation: Post-reboot HAGS confirmation

### Module 3 — CPU Scheduler & Process Priority
**Purpose:** Eliminate thread latency, prevent core parking
**Risk:** Low
**Duration:** ~45 seconds

Operations:
- Registry: `Win32PrioritySeparation = 38`
- Power: Disable core parking (min processor state = 100%)
- Power: Min/max processor state = 100% on AC
- Network Adapter: Detect and configure interrupt moderation

### Module 4 — Power Plan Management
**Purpose:** Ultimate Performance plan, disable ASPM, USB suspend
**Risk:** Medium (may require reboot for S0 systems)
**Duration:** ~2 minutes

Operations:
- Registry: Detect `PlatformAoAcOverride` (S0 detection)
- Registry: Apply `PlatformAoAcOverride = 0` if S0 detected
- Power: Duplicate Ultimate Performance plan, activate
- Power: PCIe Link State = Off
- Power: USB Selective Suspend = Disabled
- OEM Detection: Check for Armory Crate, Lenovo Vantage, Dell Command, HP Omen
- Scheduled Task: Create logon task to reassert power plan (if OEM detected)

### Module 5 — File System & I/O Optimization
**Purpose:** Eliminate MFT timestamp writes, optimize NTFS caching
**Risk:** Low
**Duration:** ~1 minute

Operations:
- NTFS: `disableLastAccess = 1`
- NTFS: `memoryusage = 2` (increased paged pool)
- NTFS: `mftzone = 2` (25% MFT reservation)
- WMI: Detect bus type (NVMe / SATA / HDD)
- Services: Disable SysMain/Prefetch if NVMe
- Registry: Windows Search indexer exclusions
- Pagefile: Set fixed size (RAM × 1)

### Module 6 — Service Management
**Purpose:** Stop telemetry and background daemons
**Risk:** Low
**Duration:** ~30 seconds

Operations:
- Disable: DiagTrack, dmwappushservice, MapsBroker, RetailDemo, WerSvc, wisvc, NvTelemetryContainer
- Manual: SysMain, WSearch, lfsvc, PeerDistSvc, SharedAccess, PrintNotify, icssvc, NcdAutoSetup, PhoneSvc, RmSvc
- Protected: Validate HvHost, vmms, WslService, LxssManager, VmCompute, vmic* never touched

### Module 7 — Rollback
**Purpose:** Complete reversal of all changes
**Risk:** None (restorative)
**Duration:** ~1 minute

Operations:
- Read JSON rollback manifest
- Restore registry values (reverse order)
- Restore service StartType values
- Remove scheduled task (if created)
- Report before/after values

## Dependency Graph

```
Execution Policy Bypass (must be first)
    ↓
Elevation Check (must be second)
    ↓
System Restore Point (must be third)
    ↓
Virtualization Stack Baseline (must be fourth)
    ↓
┌───────────────┬───────────────┬───────────────┬───────────────┐
│   Module 1    │   Module 2    │   Module 3    │   Module 4    │
│  Telemetry    │  GPU/DWM      │  Scheduler    │  Power Plan   │
└───────────────┴───────────────┴───────────────┴───────────────┘
    ↓                  ↓                  ↓                  ↓
┌───────────────┬───────────────┬───────────────┬───────────────┐
│   Module 5    │   Module 6    │   Module 7    │  Entry Point  │
│ File System   │  Services     │  Rollback     │  Orchestration│
└───────────────┴───────────────┴───────────────┴───────────────┘
    ↓
Virtualization Stack Verification (must be last)
```

## Complexity Notes

| Module | Lines of Code (est.) | Complexity | Why |
|--------|---------------------|------------|-----|
| Write-OptLog | ~20 | Low | Simple JSONL append |
| Get-ActivePlanGuid | ~10 | Low | Regex extraction |
| Save-RollbackEntry | ~15 | Low | JSON manifest append |
| Take-RegistryOwnership | ~30 | Medium | ACL manipulation |
| Test-VirtStack | ~25 | Medium | WMI queries, no wsl.exe |
| Invoke-TelemetryBlock | ~80 | Medium | Multi-step (registry, services, tasks) |
| Invoke-GpuDwmOptimize | ~60 | Medium | Registry + service + validation |
| Invoke-SchedulerOptimize | ~70 | Medium | Registry + powercfg with GUIDs |
| Invoke-PowerPlanConfig | ~120 | High | S0 detection, OEM detection, task creation |
| Invoke-FileSystemOptimize | ~90 | Medium | WMI + fsutil + conditional logic |
| Invoke-ServiceOptimize | ~100 | Low | Repetitive service config |
| Invoke-Rollback | ~80 | Medium | JSON parsing + reverse restoration |
| WinOptimizer (entry) | ~150 | Medium | Menu, safety gates, orchestration |

**Total Estimated:** ~950 lines of PowerShell

---
*Features synthesized from WinOptimizer PRD Section 2.3*
*Confidence: High — All modules specified in detail*
