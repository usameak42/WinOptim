# WinOptimizer PS1
## Windows 11 Performance Optimization Script
### Product Requirements Document & Implementation Plan

| Field | Detail |
|---|---|
| **Version** | 1.0.0-draft |
| **Status** | Pre-Development |
| **Target Platform** | Windows 11 — PowerShell 5.1+ |
| **GPU Target** | Nvidia RTX 3070 (Optimus laptop) |
| **License** | MIT |

---

## Table of Contents

1. [Section 1 — Context Extraction: Technical Inventory](#section-1--context-extraction-technical-inventory)
   - [1.1 Execution Policy Override](#11-execution-policy-override)
   - [1.2 Ultimate Performance Plan Hidden by Modern Standby (S0)](#12-ultimate-performance-plan-hidden-by-modern-standby-s0)
   - [1.3 CPU Core Parking — Parameter Parsing Failure](#13-cpu-core-parking--parameter-parsing-failure)
   - [1.4 Windows Search — TrustedInstaller Registry Ownership](#14-windows-search--trustedinstaller-registry-ownership)
   - [1.5 ASUS Armory Crate Power Plan Reassertion](#15-asus-armory-crate-power-plan-reassertion)
   - [1.6 WSL Status — LOCAL_SYSTEM Context Error](#16-wsl-status--local_system-context-error)
   - [1.7 Scheduled Task — Multiline Parameter Parsing Failure](#17-scheduled-task--multiline-parameter-parsing-failure)
   - [1.8 Complete Registry & Service Change Inventory](#18-complete-registry--service-change-inventory)
2. [Section 2 — Product Requirements Document (PRD)](#section-2--product-requirements-document-prd)
   - [2.1 Product Vision & Scope](#21-product-vision--scope)
   - [2.2 Target User Profile](#22-target-user-profile)
   - [2.3 Core Feature Modules](#23-core-feature-modules)
   - [2.4 Security & Risk Management Requirements](#24-security--risk-management-requirements)
   - [2.5 CLI UX Requirements](#25-cli-ux-requirements)
3. [Section 3 — Implementation Plan](#section-3--implementation-plan)
   - [3.1 Repository Architecture](#31-repository-architecture)
   - [3.2 Shared Library Specifications](#32-shared-library-specifications)
   - [3.3 Entry Point Structure](#33-entry-point-structure--winoptimizerps1)
   - [3.4 Development Phases](#34-development-phases)
   - [3.5 README.md Structure](#35-readmemd-structure)
   - [3.6 Quality Gates Before v1.0.0 Release](#36-quality-gates-before-v100-release)

---

# Section 1 — Context Extraction: Technical Inventory

This section is the authoritative record of every real-world error encountered during deployment of the optimization stack, its root cause at the kernel or OS architecture level, and the exact solution applied. These discoveries form the core feature set and defensive logic of WinOptimizer PS1.

---

## 1.1 Execution Policy Override

| Field | Detail |
|---|---|
| **Error** | `Set-ExecutionPolicy Unrestricted` failed with `ExecutionPolicyOverride` scope conflict against `RemoteSigned`. |
| **Root Cause** | A Machine-level or GPO-enforced policy in `HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell` blocked global scope changes. Machine-scope policy takes precedence over all user-scope attempts. |
| **Solution** | Bypassed for the active process thread only: `Set-ExecutionPolicy Bypass -Scope Process -Force`. Injects the bypass flag into the current runspace without writing to any registry hive, leaving the machine policy untouched. |
| **Script Implication** | All script modules must self-invoke with `-Scope Process` bypass at the entry point. The global machine policy must never be modified. |

---

## 1.2 Ultimate Performance Plan Hidden by Modern Standby (S0)

| Field | Detail |
|---|---|
| **Error** | GUID `e9a42b02-d5df-448d-aa00-03f14749eb61` did not appear in `powercfg /list` or the UI after duplication attempt. |
| **Root Cause** | Laptop firmware advertises Modern Standby (S0 Low Power Idle) to the OS. When S0 is active, the Windows Power Manager kernel module (`po.sys`) explicitly suppresses high-performance plans as they are architecturally incompatible with S0's always-on network stack requirements. |
| **Solution** | Disabled Modern Standby: `reg add HKLM\System\CurrentControlSet\Control\Power /v PlatformAoAcOverride /t REG_DWORD /d 0 /f` — then rebooted and ran: `powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61` |
| **Script Implication** | Script must detect S0 state before attempting plan activation. If detected, apply `PlatformAoAcOverride` fix and prompt for reboot before continuing. Do not assume the plan exists. |

---

## 1.3 CPU Core Parking — Parameter Parsing Failure

| Field | Detail |
|---|---|
| **Error** | `powercfg -setacvalueindex $activePlan SUB_PROCESSOR CPONCORES 100` returned `Invalid Parameters`. |
| **Root Cause** | Two compounding issues: (1) `powercfg /getactivescheme` returns a formatted string, not a raw GUID — naive string assignment captures label text. (2) The `SUB_PROCESSOR` alias fails to resolve in non-English Windows locales; the alias table is locale-dependent. |
| **Solution** | Regex GUID extraction: `$activePlan = (powercfg /getactivescheme \| Select-String -Pattern '([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})').Matches.Value`. Replaced all aliases with hardcoded GUIDs: SubGroup `54533251-82be-4824-96c1-47b60b740d00`, Setting `0cc5b647-c1df-4637-891a-dec35c318583`. |
| **Script Implication** | All `powercfg` interactions must use the regex GUID extractor helper. All power subgroup and setting references must use explicit GUIDs — never locale-sensitive aliases. |

---

## 1.4 Windows Search — TrustedInstaller Registry Ownership

| Field | Detail |
|---|---|
| **Error** | Modifying `HKLM:\SOFTWARE\Microsoft\Windows Search\Gather\Windows\SystemIndex` threw `SecurityException: Requested registry access is not allowed`. |
| **Root Cause** | The key is owned by `NT SERVICE\TrustedInstaller`. Standard elevation to the Administrators group does not inherit TrustedInstaller permissions. The ACL explicitly denies write access to Administrators. |
| **Solution** | Used `System.Security.AccessControl` classes to programmatically transfer ownership to the Administrators group, grant `FullControl`, then apply the target property change. Alternative: route through ExecTI to execute as TrustedInstaller. |
| **Script Implication** | A `Take-RegistryOwnership` helper function must encapsulate the ownership transfer. All TrustedInstaller-owned keys must be processed through this helper before modification. |

---

## 1.5 ASUS Armory Crate Power Plan Reassertion

| Field | Detail |
|---|---|
| **Error** | Ultimate Performance plan reverted to ASUS Turbo plan after every reboot. |
| **Root Cause** | `ArmouryCrate.Service` and `ASUSOptimization` register a boot-time power plan callback via the Windows Power Management event infrastructure. They reassert ASUS-specific plan GUIDs at login, overriding any user-set active plan. |
| **Solution** | Created a Windows Scheduled Task (`Register-ScheduledTask`) triggered at logon with a `PT10S` delay, running `powercfg /setactive` against the custom plan GUID with `RunLevel Highest`. Targeted the current user principal to avoid `LOCAL_SYSTEM` context issues. |
| **Script Implication** | Script must detect common OEM power management services and offer the scheduled task countermeasure. OEM service list (Armory Crate, Lenovo Vantage, Dell Command, HP Omen) must be defined in `config/services.json` and be extensible. |

---

## 1.6 WSL Status — LOCAL_SYSTEM Context Error

| Field | Detail |
|---|---|
| **Error** | `wsl --status` returned `Wsl/WSL_E_LOCAL_SYSTEM_NOT_SUPPORTED` from elevated PowerShell. |
| **Root Cause** | WSL2 is a per-user feature. `LxssManager` maps WSL instances to user SID tokens. Running `wsl.exe` under `LOCAL_SYSTEM` (which elevated PowerShell inherits) provides no user SID, which WSL explicitly rejects. The error is benign — WSL is intact. |
| **Solution** | WSL validation must be performed in a standard user-context terminal. The error is cosmetic when it appears in an elevated session. |
| **Script Implication** | WSL/Hyper-V validation must use WMI queries and `Get-Service` — never `wsl.exe` binary invocation from the script's elevated context. |

---

## 1.7 Scheduled Task — Multiline Parameter Parsing Failure

| Field | Detail |
|---|---|
| **Error** | `-DontStopIfGoingOnBattery` and `-LogonType` were not recognized as cmdlet parameters. |
| **Root Cause** | PowerShell's line-continuation parser misinterpreted backtick continuation characters, causing cmdlets to be parsed as separate incomplete statements which then failed parameter validation. |
| **Solution** | Collapsed each cmdlet call to a single unbroken line. Each parameter block was run as an independent sequential statement. |
| **Script Implication** | All PowerShell functions in the script must use single-line cmdlet calls or proper splatting (`@{}`) for parameter sets. Backtick line continuation is banned in all modules. |

---

## 1.8 Complete Registry & Service Change Inventory

Every persistent change applied to the system, organized by subsystem:

| Registry Key / Setting | Value Applied | Mechanical Effect |
|---|---|---|
| `HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection` — `AllowTelemetry` | `REG_DWORD = 0` | Caps telemetry at Security level; prevents DiagTrack ETW flush events |
| `HKLM\SYSTEM\...\Autologger\AutoLogger-Diagtrack-Listener` — `Start` | `REG_DWORD = 0` | Prevents kernel from activating DiagTrack ring-buffer at boot |
| `HKLM\SYSTEM\...\Autologger\DiagLog` — `Start` | `REG_DWORD = 0` | Disables DiagLog ETW autologger session |
| `HKLM\SYSTEM\...\Autologger\SQMLogger` — `Start` | `REG_DWORD = 0` | Disables Software Quality Metrics logger |
| `HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers` — `HwSchMode` | `REG_DWORD = 2` | Enables Hardware-Accelerated GPU Scheduling (HAGS) |
| `HKLM\SOFTWARE\Microsoft\Windows\Dwm` — `OverlayTestMode` | `REG_DWORD = 5` | Disables MPO; forces DWM single-pass composition |
| `HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl` — `Win32PrioritySeparation` | `REG_DWORD = 38` | Variable quanta, short intervals, 3x foreground thread boost |
| `HKLM\System\CurrentControlSet\Control\Power` — `PlatformAoAcOverride` | `REG_DWORD = 0` | Disables Modern Standby S0; unlocks Ultimate Performance plan |
| NTFS `disableLastAccess` | `fsutil = 1` | Eliminates MFT timestamp write I/O on every file read |
| NTFS `memoryusage` | `fsutil = 2` | Increases paged pool for MFT caching |
| NTFS `mftzone` | `fsutil = 2` | Reserves 25% of volume for contiguous MFT expansion |
| Power Plan — Minimum Processor State | `AC = 100%` | Prevents CPU C-state drops; eliminates core wake latency |
| Power Plan — PCIe Link State Power Management (`501a4d13-42af-4429-9fd1-a8218c268e20`) | `AC = 0 (Off)` | Disables ASPM L1/L0s; eliminates ~1ms PCIe transition latency |
| Power Plan — USB Selective Suspend | `Disabled` | Prevents USB controller suspension; eliminates input device latency |
| Services — Disabled | `DiagTrack, dmwappushservice, MapsBroker, RetailDemo, WerSvc, wisvc, NvTelemetryContainer` | Removes ETW flush, telemetry relay, and GPU telemetry daemons |
| Services — Manual | `SysMain, WSearch, lfsvc, PeerDistSvc, SharedAccess, PrintNotify, icssvc, NcdAutoSetup, PhoneSvc, RmSvc` | Prevents automatic startup; available on-demand |
| Scheduled Task — Restore Ultimate Performance Plan | `AtLogOn + PT10S delay, RunLevel Highest` | Counteracts OEM service power plan reassertion after login |
| Pagefile | `Fixed: RAM × 1 (Initial = Maximum)` | Eliminates pagefile dynamic expansion I/O overhead |
| Timer Resolution | `0.5ms via SetTimerResolution` | Halves scheduler minimum sleep granularity for precise wakeups |

---

# Section 2 — Product Requirements Document (PRD)

## 2.1 Product Vision & Scope

**WinOptimizer PS1** is a CLI-first, open-source, single-command PowerShell toolkit that transforms a stock Windows 11 installation into a low-latency, high-throughput workstation environment — without disabling visual effects, breaking developer toolchains (WSL2, Hyper-V, Docker), or requiring the user to understand the underlying system mechanics.

The tool encapsulates real-world kernel-level diagnosis, registry archaeology, and GPU tuning into a safe, idempotent, reversible automation layer. It is designed to be the definitive answer to: *how do I make Windows 11 feel like macOS without breaking my dev environment?*

### Design Principles

- **Safe by Default** — creates a full System Restore Point and detailed log before executing any change
- **Idempotent** — running the script twice produces the same result as once; no stacking side effects
- **Reversible** — every change is recorded with its prior value; Rollback module can undo any applied module
- **Transparent** — color-coded terminal output explains what each operation does as it executes
- **Modular** — each optimization domain is an independent `.ps1` module that can be run standalone
- **Developer-safe** — virtualization stack (WSL2, Hyper-V, Docker) is validated before and after all changes
- **OEM-aware** — detects manufacturer power management software and applies targeted countermeasures

---

## 2.2 Target User Profile

| Dimension | Profile |
|---|---|
| **Primary User** | Advanced Windows 11 power user and software developer on a high-spec laptop, always plugged in, running WSL2/Hyper-V/Docker, with a dedicated Nvidia GPU |
| **Technical Level** | Comfortable with elevated PowerShell and Registry Editor. Does not want to research each tweak manually. |
| **Core Pain Points** | UI micro-stutters, background process interference, OEM software fighting power settings, telemetry I/O overhead, GPU P-state transitions during desktop composition |
| **Non-Goals** | Enterprise fleet management, multi-user environments, Windows 10 support, cloud-provisioned machines |

---

## 2.3 Core Feature Modules

Each module is an independent PowerShell function file. Modules can be run individually or orchestrated by the main entry point.

### Module 1 — Telemetry & AutoLogger Suppression (`Invoke-TelemetryBlock`)

- Set `AllowTelemetry` to `0` in DataCollection policy key
- Disable AutoLogger ETW sessions: `AutoLogger-Diagtrack-Listener`, `DiagLog`, `SQMLogger`
- Stop and disable `DiagTrack` and `dmwappushservice` services
- Disable scheduled tasks: `CompatibilityAppraiser`, `ProgramDataUpdater`, `Consolidator`, `UsbCeip`
- Record prior state of all values to rollback manifest

### Module 2 — GPU & DWM Optimization (`Invoke-GpuDwmOptimize`)

- Enable Hardware-Accelerated GPU Scheduling via `HwSchMode = 2`
- Disable Multi-Plane Overlay via DWM `OverlayTestMode = 5`
- Detect Nvidia GPU presence via WMI and output NVCP manual configuration checklist
- Disable `NvTelemetryContainer` service
- Validate HAGS activation post-reboot via registry readback

### Module 3 — CPU Scheduler & Process Priority (`Invoke-SchedulerOptimize`)

- Set `Win32PrioritySeparation` to `38` (variable quanta, short intervals, 3x foreground boost)
- Extract active power plan GUID using regex parser (locale-safe)
- Disable CPU core parking using hardcoded GUIDs: SubGroup `54533251-82be-4824-96c1-47b60b740d00`, Setting `0cc5b647-c1df-4637-891a-dec35c318583 = 100`
- Set minimum and maximum processor state to `100%` on AC power
- Detect and configure network adapter interrupt moderation

### Module 4 — Power Plan Management (`Invoke-PowerPlanConfig`)

- Detect Modern Standby (S0) state via `PlatformAoAcOverride` registry key
- Apply `PlatformAoAcOverride = 0` if S0 detected; prompt user for required reboot
- Duplicate and activate Ultimate Performance plan
- Rename plan to custom label to prevent OEM GUID collision
- Set PCIe Link State Power Management to Off (GUID: `501a4d13-42af-4429-9fd1-a8218c268e20`)
- Set USB Selective Suspend to Disabled
- Detect OEM power management services (Armory Crate, Lenovo Vantage, Dell Command, HP Omen)
- Create scheduled task to reapply plan post-login if OEM service detected

### Module 5 — File System & I/O Optimization (`Invoke-FileSystemOptimize`)

- Disable NTFS Last Access Time updates via `fsutil behavior set disableLastAccess 1`
- Set NTFS `memoryusage` to `2` (increased paged pool for MFT caching)
- Set NTFS MFT zone reservation to `2` (25% volume reservation)
- Detect system drive bus type (NVMe / SATA / HDD) via WMI
- Disable SysMain and Prefetch if NVMe detected; skip if HDD (seek optimization still needed)
- Configure Windows Search indexer throttling; exclude common developer directories
- Set pagefile to fixed size (RAM × 1) if currently dynamic

### Module 6 — Service Management (`Invoke-ServiceOptimize`)

- Process **Disabled** list: `DiagTrack`, `dmwappushservice`, `MapsBroker`, `RetailDemo`, `WerSvc`, `wisvc`, `NvTelemetryContainer`
- Process **Manual** list: `SysMain`, `WSearch`, `lfsvc`, `PeerDistSvc`, `SharedAccess`, `PrintNotify`, `icssvc`, `NcdAutoSetup`, `PhoneSvc`, `RmSvc`
- Validate protected services remain untouched: `HvHost`, `vmms`, `WslService`, `LxssManager`, `VmCompute`, all `vmic*` services
- Log prior `StartType` of each service for rollback
- Gracefully skip services not found — never halt on missing service

### Module 7 — Rollback (`Invoke-Rollback`)

- Read rollback manifest JSON from specified path
- Restore all recorded registry values in reverse chronological order
- Restore all service `StartType` values
- Remove the scheduled task if it was created by the script
- Report each restored item with before/after values

---

## 2.4 Security & Risk Management Requirements

### Pre-Execution Safety Gates

- **SR-01** — Create a named System Restore Point before any module executes. If creation fails, halt immediately — do not proceed.
- **SR-02** — Verify Administrator elevation. If not elevated, self-relaunch with elevation prompt rather than failing silently.
- **SR-03** — Verify PowerShell 5.1 or higher. Note compatibility differences if running on PowerShell 7+.
- **SR-04** — Validate WSL and Hyper-V feature state via WMI before all changes. Re-validate after all changes. Alert immediately on any state change.

### Rollback Architecture

- **RB-01** — Before modifying any registry value, write current value to JSON rollback manifest at `%TEMP%\WinOptimizer\rollback_{timestamp}.json`
- **RB-02** — Before changing any service `StartType`, capture current type in rollback manifest
- **RB-03** — Manifest schema per entry: key path, value name, original data, original type, module name, timestamp
- **RB-04** — `Invoke-Rollback` reads manifest and restores all values in reverse order
- **RB-05** — Rollback must be invocable standalone: `.\WinOptimizer.ps1 -Rollback -ManifestPath <path>`

### Logging Requirements

- **LG-01** — All operations write structured JSONL log entries to `%TEMP%\WinOptimizer\log_{timestamp}.jsonl`
- **LG-02** — Log schema: `timestamp`, `module`, `operation`, `target`, `oldValue`, `newValue`, `result` (Success/Failure/Skipped), `message`
- **LG-03** — Errors are non-terminating by default (`Write-Warning`) unless they affect safety gates SR-01 through SR-04
- **LG-04** — Log file path printed to console at script start and end

---

## 2.5 CLI UX Requirements

### Terminal Output Color Protocol

| Prefix | Color | Usage |
|---|---|---|
| `[SUCCESS]` | Green | Operation completed successfully |
| `[WARNING]` | Yellow | Non-fatal issue, skipped operation, or user attention needed |
| `[ERROR]` | Red | Fatal issue within module — logs and continues unless safety gate |
| `[INFO]` | Cyan | Informational context, no action required |
| `[ACTION]` | White Bold | Currently executing operation name |
| `[SKIP]` | DarkGray | Operation not applicable to this system configuration |

### Interactive Menu Requirements

- Display all modules with index numbers and one-line descriptions
- Allow selection: Run All, Run Selected Modules (multi-select by index), Rollback, View Log, Exit
- Display estimated time and risk level (Low / Medium) before each module executes
- Support non-interactive flag for CI/automation: `-Silent -RunAll`
- Use `Write-Progress` bars for operations with multiple sequential steps

---

# Section 3 — Implementation Plan

## 3.1 Repository Architecture

```
WinOptimizer-PS1/
├── WinOptimizer.ps1              # Entry point: menu, orchestration, elevation check
├── README.md
├── LICENSE                       # MIT
├── CONTRIBUTING.md
├── CHANGELOG.md
├── .github/
│   └── ISSUE_TEMPLATE/
│       ├── bug_report.md
│       └── feature_request.md
├── modules/
│   ├── Invoke-TelemetryBlock.ps1
│   ├── Invoke-GpuDwmOptimize.ps1
│   ├── Invoke-SchedulerOptimize.ps1
│   ├── Invoke-PowerPlanConfig.ps1
│   ├── Invoke-FileSystemOptimize.ps1
│   ├── Invoke-ServiceOptimize.ps1
│   └── Invoke-Rollback.ps1
├── lib/
│   ├── Write-OptLog.ps1           # Centralized JSONL logging
│   ├── Get-ActivePlanGuid.ps1     # Locale-safe GUID extractor
│   ├── Take-RegistryOwnership.ps1 # TrustedInstaller ACL helper
│   ├── Save-RollbackEntry.ps1     # Rollback manifest writer
│   └── Test-VirtStack.ps1         # WSL/Hyper-V WMI validation
├── config/
│   └── services.json              # Extensible service target lists + OEM entries
└── tests/
    ├── Test-Modules.ps1           # Pester test suite
    └── Test-Rollback.ps1          # Rollback integrity tests
```

---

## 3.2 Shared Library Specifications

### `lib/Get-ActivePlanGuid.ps1` — Locale-Safe GUID Extractor

```powershell
function Get-ActivePlanGuid {
    # Avoids alias resolution failures on non-English Windows locales
    $raw   = powercfg /getactivescheme
    $match = $raw | Select-String -Pattern '([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})'
    if (-not $match) { throw 'Unable to extract active power plan GUID.' }
    return $match.Matches.Value
}
```

### `lib/Save-RollbackEntry.ps1` — Rollback Manifest Writer

```powershell
function Save-RollbackEntry {
    param(
        [string]$Module,
        [string]$Type,           # 'Registry' | 'Service' | 'Fsutil' | 'Task'
        [string]$Target,         # Full registry path or service name
        [string]$ValueName,
        [string]$OriginalData,
        [string]$OriginalType    # REG_DWORD, REG_SZ, StartupType, etc.
    )
    $entry    = @{ Module=$Module; Type=$Type; Target=$Target; ValueName=$ValueName;
                   OriginalData=$OriginalData; OriginalType=$OriginalType;
                   Timestamp=(Get-Date -Format 'o') }
    $manifest = if (Test-Path $global:RollbackPath) {
                    Get-Content $global:RollbackPath | ConvertFrom-Json
                } else { @() }
    $manifest += $entry
    $manifest | ConvertTo-Json -Depth 5 | Set-Content $global:RollbackPath
}
```

### `lib/Write-OptLog.ps1` — Structured JSONL Logger

```powershell
function Write-OptLog {
    param(
        [string]$Module, [string]$Operation, [string]$Target,
        [string]$OldValue, [string]$NewValue,
        [ValidateSet('Success','Failure','Skipped','Info')] [string]$Result,
        [string]$Message
    )
    $entry = [PSCustomObject]@{
        Timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        Module    = $Module;  Operation = $Operation; Target = $Target
        OldValue  = $OldValue; NewValue  = $NewValue
        Result    = $Result;  Message   = $Message
    }
    $entry | ConvertTo-Json -Compress | Out-File -Append -FilePath $global:LogPath
}
```

---

## 3.3 Entry Point Structure — `WinOptimizer.ps1`

```powershell
#Requires -Version 5.1
Set-ExecutionPolicy Bypass -Scope Process -Force

# Elevation check — self-relaunch if not admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent())
         .IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Start-Process pwsh -Verb RunAs -ArgumentList "-File `"$PSCommandPath`""
    exit
}

# Global session state
$global:SessionId    = (Get-Date -Format "yyyyMMdd_HHmmss")
$global:OutputDir    = "$env:TEMP\WinOptimizer"
$global:LogPath      = "$global:OutputDir\log_$global:SessionId.jsonl"
$global:RollbackPath = "$global:OutputDir\rollback_$global:SessionId.json"
New-Item -ItemType Directory -Path $global:OutputDir -Force | Out-Null

# Dot-source all libraries
Get-ChildItem -Path "$PSScriptRoot\lib\*.ps1" | ForEach-Object { . $_.FullName }

# Safety Gate: System Restore Point (halts on failure)
Write-Host '[ACTION] Creating System Restore Point...' -ForegroundColor White
try {
    Enable-ComputerRestore -Drive $env:SystemDrive
    Checkpoint-Computer -Description "WinOptimizer_$global:SessionId" -RestorePointType MODIFY_SETTINGS
    Write-Host '[SUCCESS] Restore Point created.' -ForegroundColor Green
} catch {
    Write-Host '[ERROR] Restore Point creation failed. Aborting.' -ForegroundColor Red
    exit 1
}

# Virtualization stack pre-flight validation
. $PSScriptRoot\lib\Test-VirtStack.ps1
$global:VirtBaseline = Test-VirtStack

# -Silent -RunAll flag handling
if ($RunAll) { & "$PSScriptRoot\modules\Invoke-TelemetryBlock.ps1"; <# ... #>; exit }

# Interactive menu (see Section 2.5)
Show-Menu
```

---

## 3.4 Development Phases

### Phase 1 — Core Scripting & Modularity
**Estimated Duration: 1–2 weeks**

1. Scaffold repository structure as defined in Section 3.1
2. Implement all `lib/` helpers with full parameter validation and error handling
3. Implement Module 1 (Telemetry) and Module 6 (Services) as reference implementations for the module pattern
4. Implement Module 4 (Power Plan): S0 detection, `PlatformAoAcOverride`, regex GUID extraction, OEM detection, scheduled task creation
5. Implement Module 3 (Scheduler): `Win32PrioritySeparation`, core parking with hardcoded subgroup GUIDs
6. Implement Module 5 (File System): NVMe detection gate for SysMain/Prefetch, NTFS fsutil calls, pagefile config
7. Implement Module 2 (GPU/DWM): HAGS registry write, MPO disable, Nvidia telemetry service
8. Implement Module 7 (Rollback): full manifest read, reverse-order restoration, task removal
9. All modules must call `Save-RollbackEntry` before every destructive operation
10. All modules must call `Write-OptLog` after every operation with full field population

### Phase 2 — Safety Mechanisms
**Estimated Duration: 3–5 days**

1. Implement all four pre-execution safety gates (elevation, restore point, PS version, virt validation)
2. Implement `Test-VirtStack.ps1` using WMI and `Get-WindowsOptionalFeature` exclusively — no `wsl.exe` invocation
3. Run `Test-VirtStack` before and after all modules; diff results; alert on any state change
4. Implement `Take-RegistryOwnership.ps1` using `System.Security.AccessControl` for TrustedInstaller-owned keys
5. Implement `-Rollback -ManifestPath` CLI parameter in entry point
6. Write Pester tests: GUID extraction, rollback manifest write/read, service state validation, registry operations

### Phase 3 — CLI Polish & GitHub Readiness
**Estimated Duration: 3–4 days**

1. Implement interactive menu with color protocol, module index, estimated time, and risk labels
2. Implement `-Silent -RunAll` flags for non-interactive automation
3. Add `Write-Progress` bars to all multi-step operations
4. Write `README.md` per Section 3.5 structure
5. Add MIT `LICENSE`
6. Write `CONTRIBUTING.md`: PR guidelines, module addition template, test requirements, code style ban on backtick continuation
7. Write `CHANGELOG.md` with v1.0.0 initial release entry
8. Create GitHub Issue templates: `bug_report.md` (requires OS version, PS version, log file), `feature_request.md`
9. Final pass: run all Pester tests, verify rollback integrity on clean VM snapshot

---

## 3.5 README.md Structure

```markdown
# WinOptimizer PS1

> One-command Windows 11 optimization. macOS-level UI fluidity.
> Keeps your visuals. Keeps your dev stack. Destroys the bloat.

## Quick Start
irm https://raw.githubusercontent.com/[user]/WinOptimizer-PS1/main/WinOptimizer.ps1 | iex

## What It Does          (table: module / what it fixes / risk level)
## What It Protects       (WSL2, Hyper-V, Docker, Microsoft Store)
## Safety Features        (System Restore Point, JSON Rollback, JSONL Logging)
## Manual Rollback        (.\WinOptimizer.ps1 -Rollback -ManifestPath <path>)
## Requirements           (Windows 11, PowerShell 5.1+, Administrator rights)
## Tested Configurations  (hardware and OEM matrix from real deployments)
## Contributing           (link to CONTRIBUTING.md)
## License                (MIT)
```

---

## 3.6 Quality Gates Before v1.0.0 Release

| Gate | Category | Pass Criterion |
|---|---|---|
| **QG-01** | Idempotency | Run full script twice on same machine. Second run must produce zero registry changes and zero service state changes — all operations must report `[SKIP]`. |
| **QG-02** | Rollback Integrity | Apply all modules, run `Invoke-Rollback`, verify all values restored to pre-script state via registry readback and service inspection. |
| **QG-03** | Virtualization Safety | Confirm Docker Desktop, WSL2 distros, and Hyper-V VMs all start successfully after full script execution on a machine with all three active. |
| **QG-04** | OEM Compatibility | Test on ASUS (Armory Crate), Lenovo (Vantage), and Dell (Command Center) to confirm scheduled task power plan countermeasure survives reboot. |
| **QG-05** | Locale Safety | Run on Turkish-locale and German-locale Windows 11 to verify GUID extraction never fails due to localized `powercfg` output. |
| **QG-06** | Modern Standby Detection | Confirm `PlatformAoAcOverride` detection and conditional application works correctly on both S0 and S3 firmware configurations. |
| **QG-07** | Non-Interactive Mode | Run with `-Silent -RunAll` and confirm all modules execute without prompts, with complete log output. |

---

*WinOptimizer PS1 — PRD v1.0.0-draft*
*Generated from real-world Windows 11 optimization session — MIT License*
