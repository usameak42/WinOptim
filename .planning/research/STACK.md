# Stack Research: Windows PowerShell Optimization

**Confidence:** High — PRD validated through real-world deployment

## Core Technology Stack

| Component | Technology | Version | Rationale |
|-----------|-----------|---------|-----------|
| **Scripting Language** | PowerShell | 5.1+ | Bundled with Windows 11; core to Windows administration |
| **Target Platform** | Windows 11 | Current | Modern Standby (S0) power management differs from Windows 10 |
| **Execution Policy** | Process-scope Bypass | — | Machine-level GPO blocks global changes; Process-scope safer |
| **Registry Interface** | .NET Registry Provider | — | Native PowerShell provider for HKLM/HKCU manipulation |
| **ACL Modification** | System.Security.AccessControl | — | Required for TrustedInstaller ownership transfer |
| **Service Management** | Get-Service / Set-Service | — | Built-in PowerShell cmdlets |
| **WMI Queries** | Get-WmiObject / Get-CimInstance | — | Required for WSL/Hyper-V validation (no wsl.exe from elevated context) |
| **Power Configuration** | powercfg.exe | — | Native Windows power plan management |
| **Scheduled Tasks** | Register-ScheduledTask | — | Windows Task Scheduler cmdlet for OEM countermeasures |
| **File System** | fsutil.exe | — | NTFS parameter modification |
| **Testing Framework** | Pester | — | PowerShell testing framework for validation |

## Critical Technical Constraints

### Locale Safety
- **No locale-sensitive aliases** — All `powercfg` subgroups must use hardcoded GUIDs
- **Regex GUID extraction** — `powercfg /getactivescheme` returns formatted string, not raw GUID

### Elevation Context
- **LOCAL_SYSTEM limitation** — `wsl.exe` fails under elevated PowerShell (Wsl/WSL_E_LOCAL_SYSTEM_NOT_SUPPORTED)
- **Use WMI instead** — `Get-WindowsOptionalFeature` and `Get-Service` for virtualization detection

### Protected Services
Never modify these services under any circumstances:
- `HvHost`
- `vmms`
- `WslService`
- `LxssManager`
- `VmCompute`
- `vmic*` (all Hyper-V VM Integration services)

### Code Style Constraints
- **Zero backtick line continuation** — Causes parsing failures in splatted cmdlets
- **Use splatting `@{}`** for multi-parameter cmdlets
- **4-space indentation** — Consistent formatting
- **`#region / #endregion` blocks** — Organize sections within files

## OEM Service Detection Targets

Configured in `config/services.json`:

| OEM | Service Name | Detection Strategy |
|-----|--------------|-------------------|
| ASUS | ArmouryCrate.Service, ASUSOptimization | Service existence check |
| Lenovo | LenovoVantage | Service existence check |
| Dell | DellCommandCenter | Service existence check |
| HP | HP Omen Gaming Hub | Service existence check |

## Known Hardcoded GUIDs

### Power Subgroups
- Processor: `54533251-82be-4824-96c1-47b60b740d00`
- PCIe: `501a4d13-42af-4429-9fd1-a8218c268e20`

### Power Settings
- Core Parking: `0cc5b647-c1df-4637-891a-dec35c318583`
- Minimum Processor State: `89401c4a-b84f-45dd-ae36-27db45ac9b45`
- Maximum Processor State: `bc5038f7-23e0-4960-96da-33abaf5935ec`

### Ultimate Performance Plan
- GUID: `e9a42b02-d5df-448d-aa00-03f14749eb61`

## What NOT to Use

| Technology | Reason |
|------------|--------|
| PowerShell 7+ | Not bundled with Windows 11; compatibility differences |
| Windows 10 | Modern Standby and power plans differ significantly |
| Non-admin user context | Script requires elevation by design |
| Global execution policy changes | Machine-level GPO blocks; use Process-scope only |
| Locale-sensitive aliases | Fails on non-English Windows installations |
| `wsl.exe` from elevated context | LOCAL_SYSTEM context not supported by WSL2 |
| Backtick line continuation | Causes parsing failures; use splatting |
| Third-party optimization tools | Closed-source, irreversible, break dev toolchains |

---
*Stack synthesized from WinOptimizer PRD Section 1-3*
*Confidence: High — Real-world validated*
