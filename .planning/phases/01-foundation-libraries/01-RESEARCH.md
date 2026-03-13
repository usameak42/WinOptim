# Phase 1: Foundation & Libraries - Research

**Researched:** 2026-03-13
**Domain:** PowerShell 5.1 library helper functions, JSON configuration, repository structure
**Confidence:** HIGH

## Summary

Phase 1 establishes the foundational infrastructure that all subsequent phases depend on: repository structure, 5 reusable library helpers, and configuration files. This phase is critical because improper implementation of library helpers (especially logging, rollback, and permissions) would require rewriting all later modules.

**Primary recommendation:** Implement library helpers first with full parameter validation and comment-based help, then build repository structure around them. Use PowerShell 5.1 best practices: CmdletBinding, parameter validation attributes, hashtables for complex parameters, and zero backtick line continuation.

## User Constraints (from CONTEXT.md)

### Locked Decisions

**Library Function Design:**
- Return values: Boolean `$true`/`$false` for success/failure
- Complex data parameters: Use hashtable parameters for structured data (e.g., `Write-OptLog -Properties @{...}`)
- Comment-based help: Full help blocks for all library functions (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`)

**Logging Strategy:**
- Log fields: Rich field set — Timestamp, Module, Operation, Target, Values (before/after), Result, Message, Level
- Format: JSONL (one JSON object per line) for easy parsing and review

**Service.json Structure:**
- Schema: Rich metadata format with nested categories
  - `disabled: [{name, reason}]`
  - `manual: [{name, reason}]`
  - `oem: {vendor: [{name, displayName, detectionPattern}]}`
- OEM entries: Full metadata including vendor name, service display name, and detection pattern (registry key or WMI query)
- User extensibility: Include `custom` or `other` section for user-added services; document how to extend

**Repository Organization:**
- Module file naming: Short names (e.g., `TelemetryBlock.ps1`, `GpuDwmOptimize.ps1`)
- Inline comments: Minimal — only for complex operations

### Claude's Discretion

- Function signature strictness and parameter validation — follow PowerShell best practices and each function's specific needs
- Error handling approach — balance safety with PowerShell conventions (non-terminating errors where appropriate)
- Log levels — choose appropriate levels for the use case (DEBUG/INFO/SUCCESS/WARNING/ERROR/SKIP)
- Log rotation strategy — based on typical usage patterns
- Log file location — balance security and usability needs
- #region/#endregion block organization — based on code complexity and logical grouping
- JSON schema for services.json — based on tooling and validation needs

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within Phase 1 scope (foundation and library helpers only; individual optimization modules are later phases).

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| **REPO-01** | Repository matches exact structure from PRD Section 3.1 (all directories and files exist) | See Architecture Patterns section — PRD Section 3.1 fully specifies structure |
| **REPO-03** | config/services.json contains Disabled list, Manual list, and OEM entries (Armory Crate, Lenovo Vantage, Dell Command, HP Omen) | See Standard Stack section — service lists from PRD validation |
| **LIBR-01** | Write-OptLog can write structured JSONL log entries with timestamp, module, operation, target, values, result, message | See Code Examples section — JSONL logging pattern |
| **LIBR-02** | Get-ActivePlanGuid can extract GUID from powercfg output using regex (locale-safe) | See Architecture Research PITFALL-03 — regex extraction pattern documented |
| **LIBR-03** | Save-RollbackEntry can append to JSON rollback manifest before any destructive operation | See Architecture Research rollback schema — append-only pattern |
| **LIBR-04** | Take-RegistryOwnership can transfer ownership from TrustedInstaller to Administrators via System.Security.AccessControl | See Code Examples section — RegistryAccessRule pattern from official .NET docs |
| **LIBR-05** | Test-VirtStack can validate WSL2/Hyper-V via WMI without calling wsl.exe | See Architecture Research PITFALL-06 — WMI-only validation pattern |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **PowerShell** | 5.1+ | Script runtime | Bundled with Windows 11; target platform from PRD |
| **.NET Framework** | 4.8+ (bundled) | ACL/Registry classes | Required for `System.Security.AccessControl` and `Microsoft.Win32.Registry` |
| **ConvertTo-Json** | Built-in cmdlet | JSON serialization | Native PowerShell 5.1 JSON support |
| **Select-String** | Built-in cmdlet | Regex matching | Locale-safe GUID extraction from powercfg output |
| **Get-WmiObject** | Built-in cmdlet | WMI queries | Virtualization stack validation (replaces wsl.exe) |
| **Get-Service** | Built-in cmdlet | Service management | Check service state, protected services block |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **Pester** | Latest (via PSGallery) | Testing framework | Phase 7 validation; optional for Phase 1 |
| **New-Object** | Built-in | .NET object instantiation | Creating `System.Security.AccessControl` objects |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| PowerShell 5.1 | PowerShell 7+ | Not bundled with Windows 11; compatibility differences; PRD specifies 5.1 |
| Built-in JSON cmdlets | Newtonsoft.Json | External dependency not needed for simple JSON serialization |
| WMI queries | `wsl.exe` calls | FAILS in elevated context (LOCAL_SYSTEM not supported) — documented in PITFALL-06 |
| Regex GUID extraction | String manipulation | Locale-sensitive string parsing fails on non-English Windows — documented in PITFALL-03 |

**Installation:**
No external packages required for Phase 1. All dependencies are built into Windows 11 PowerShell 5.1.

```powershell
# Optional: Install Pester for Phase 7 testing
Install-Module -Name Pester -Force -SkipPublisherCheck -MinimumVersion 5.0
```

## Architecture Patterns

### Recommended Project Structure

```
WinOptimizer/
├── WinOptimizer.ps1           # Main entry point (Phase 6)
├── lib/                       # Shared library helpers (Phase 1)
│   ├── Write-OptLog.ps1       # JSONL structured logging
│   ├── Get-ActivePlanGuid.ps1 # Locale-safe GUID extraction
│   ├── Save-RollbackEntry.ps1 # Rollback manifest append
│   ├── Take-RegistryOwnership.ps1  # TrustedInstaller ACL transfer
│   └── Test-VirtStack.ps1     # WMI-based virtualization validation
├── modules/                   # Optimization modules (Phases 3-5)
│   ├── Invoke-TelemetryBlock.ps1
│   ├── Invoke-GpuDwmOptimize.ps1
│   ├── Invoke-SchedulerOptimize.ps1
│   ├── Invoke-PowerPlanConfig.ps1
│   ├── Invoke-FileSystemOptimize.ps1
│   ├── Invoke-ServiceOptimize.ps1
│   └── Invoke-Rollback.ps1
├── config/                    # Configuration files (Phase 1)
│   └── services.json          # Service lists (Disabled, Manual, OEM)
├── tests/                     # Pester tests (Phase 7)
│   ├── Test-Modules.ps1
│   └── Test-Rollback.ps1
├── .planning/                 # Project planning (already exists)
├── README.md                  # Documentation (Phase 7)
├── CONTRIBUTING.md            # Contribution guidelines (Phase 7)
├── CHANGELOG.md               # Version history (Phase 7)
├── LICENSE                    # MIT license (Phase 7)
└── .github/                   # GitHub templates (Phase 7)
    └── ISSUES_TEMPLATE/
        ├── bug_report.md
        └── feature_request.md
```

**Source:** PRD Section 3.1 (fully specified)

### Pattern 1: Library Helper Function Structure

**What:** All 5 library helpers follow the same advanced function pattern

**When to use:** Every `.ps1` file in `lib/` directory

**Example:**
```powershell
#Requires -Version 5.1

<#
.SYNOPSIS
    Writes structured JSONL log entries for WinOptimizer operations.

.DESCRIPTION
    The Write-OptLog function creates JSONL (JSON Lines) formatted log entries
    with rich metadata including timestamp, module, operation, target, values,
    result, message, and log level. Each log entry is appended to the session
    log file for post-mortem analysis and debugging.

.PARAMETER Module
    The name of the module or function performing the operation (e.g., "Invoke-TelemetryBlock").

.PARAMETER Operation
    The PowerShell cmdlet or operation being performed (e.g., "Set-ItemProperty").

.PARAMETER Target
    The registry path, service name, or system target being modified.

.PARAMETER Values
    A hashtable containing before/after values or operation-specific data.

.PARAMETER Result
    The operation result: "Success", "Skip", "Warning", or "Error".

.PARAMETER Message
    Human-readable message describing the operation outcome.

.PARAMETER Level
    Log level: "INFO", "SUCCESS", "WARNING", "ERROR", "SKIP", "DEBUG".

.EXAMPLE
    Write-OptLog -Module "Invoke-TelemetryBlock" -Operation "Set-ItemProperty" -Target "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection\AllowTelemetry" -Values @{ OldValue = 1; NewValue = 0 } -Result "Success" -Message "Telemetry capped at Security level" -Level "INFO"

.NOTES
    Author: WinOptimizer Project
    Version: 1.0.0
#>
function Write-OptLog {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Module,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Operation,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Target,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [hashtable]$Values,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Success', 'Skip', 'Warning', 'Error')]
        [string]$Result,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR', 'SKIP', 'DEBUG')]
        [string]$Level
    )

    #region Log Entry Construction
    $logEntry = [ordered]@{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Module    = $Module
        Operation = $Operation
        Target    = $Target
        Values    = $Values
        Result    = $Result
        Message   = $Message
        Level     = $Level
    }
    #endregion

    #region JSONL Serialization
    try {
        $jsonLine = $logEntry | ConvertTo-Json -Compress
        Add-Content -Path $global:LogPath -Value $jsonLine -ErrorAction Stop
        return $true
    }
    catch {
        Write-Error "Failed to write log entry: $_"
        return $false
    }
    #endregion
}
```

**Source:** Microsoft Learn - [about_Functions_Advanced_Parameters](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_advanced_parameters) (retrieved 2026-03-13)

**Key Pattern Elements:**
1. `#Requires -Version 5.1` at top of file
2. Full comment-based help block (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, `.NOTES`)
3. `[CmdletBinding()]` attribute for advanced function behavior
4. `[OutputType([bool])]` for return type documentation
5. `[Parameter()]` attributes with `Mandatory`, `ValidateNotNullOrEmpty()`
6. `[ValidateSet()]` for enumerated values (Result, Level)
7. `[hashtable]` type for complex structured data (Values parameter)
8. `#region / #endregion` blocks for organization
9. Boolean return (`$true`/`$false`) for success/failure

### Pattern 2: Registry Ownership Transfer (System.Security.AccessControl)

**What:** Transfer registry key ownership from TrustedInstaller to Administrators

**When to use:** Before modifying registry keys owned by TrustedInstaller (e.g., Windows Search keys)

**Example:**
```powershell
<#
.SYNOPSIS
    Transfers registry key ownership from TrustedInstaller to Administrators.

.DESCRIPTION
    The Take-RegistryOwnership function uses .NET System.Security.AccessControl
    classes to take ownership of a registry key and grant FullControl to the
    Administrators group. This is required for modifying keys owned by
    TrustedInstaller (e.g., Windows Search keys).

.PARAMETER Path
    The registry path to take ownership of (e.g., "HKLM:\SOFTWARE\Microsoft\Windows Search").

.EXAMPLE
    Take-RegistryOwnership -Path "HKLM:\SOFTWARE\Microsoft\Windows Search"

.NOTES
    Requires elevation. Use with caution - ownership changes are irreversible without manual intervention.
#>
function Take-RegistryOwnership {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    #region Security Critical
    # This function modifies registry ACLs. Test thoroughly in VM environment.
    #endregion

    try {
        #region Open Registry Key with TakeOwnership Rights
        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
            $Path.Replace('HKLM:', ''),
            [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
            [System.Security.AccessControl.RegistryRights]::TakeOwnership
        )

        if ($null -eq $key) {
            throw "Failed to open registry key: $Path"
        }
        #endregion

        #region Get Current ACL and Set Owner
        $acl = $key.GetAccessControl()
        $adminGroup = [System.Security.Principal.NTAccount]"Administrators"
        $acl.SetOwner($adminGroup)
        #endregion

        #region Apply Modified ACL
        $key.SetAccessControl($acl)
        $key.Close()
        #endregion

        #region Grant FullControl to Administrators
        $acl = Get-Acl -Path $Path
        $accessRule = New-Object System.Security.AccessControl.RegistryAccessRule(
            $adminGroup,
            [System.Security.AccessControl.RegistryRights]::FullControl,
            [System.Security.AccessControl.InheritanceFlags]::ContainerInherit,
            [System.Security.AccessControl.PropagationFlags]::None,
            [System.Security.AccessControl.AccessControlType]::Allow
        )
        $acl.SetAccessRule($accessRule)
        Set-Acl -Path $Path -AclObject $acl
        #endregion

        return $true
    }
    catch {
        Write-Error "Failed to take ownership of $Path`: $_"
        return $false
    }
}
```

**Source:** Microsoft Learn - [RegistryAccessRule Class](https://learn.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.registryaccessrule) (retrieved 2026-03-13)

**Key Pattern Elements:**
1. `[Microsoft.Win32.Registry]::LocalMachine.OpenSubKey()` for direct registry access
2. `[System.Security.AccessControl.RegistryRights]::TakeOwnership` for ownership rights
3. `[System.Security.Principal.NTAccount]` for user/group identity
4. `RegistryAccessRule` constructor with `InheritanceFlags` and `PropagationFlags`
5. `Set-Acl` for applying modified ACL
6. Comprehensive error handling with `try/catch`

### Pattern 3: Locale-Safe GUID Extraction

**What:** Extract GUID from powercfg output using regex (locale-safe)

**When to use:** All powercfg operations that require active plan GUID

**Example:**
```powershell
<#
.SYNOPSIS
    Extracts the active power plan GUID from powercfg output (locale-safe).

.DESCRIPTION
    The Get-ActivePlanGuid function uses regex to extract the GUID from
    'powercfg /getactivescheme' output. This approach is locale-safe and
    works on non-English Windows installations where powercfg aliases fail.

.EXAMPLE
    $planGuid = Get-ActivePlanGuid

.NOTES
    Uses regex pattern for GUID extraction to avoid locale-sensitive alias resolution.
#>
function Get-ActivePlanGuid {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    try {
        #region Execute powercfg and Extract GUID
        $output = powercfg /getactivescheme 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "powercfg /getactivescheme failed with exit code $LASTEXITCODE"
        }

        # Regex pattern for GUID: 8-4-4-4-12 hexadecimal digits
        $guidPattern = '([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})'
        $match = Select-String -InputObject $output -Pattern $guidPattern

        if ($null -eq $match) {
            throw "Failed to extract GUID from powercfg output"
        }

        return $match.Matches.Value
        #endregion
    }
    catch {
        Write-Error "Get-ActivePlanGuid failed: $_"
        return $null
    }
}
```

**Source:** Architecture Research PITFALL-03 — validated through real-world Windows 11 optimization sessions

**Key Pattern Elements:**
1. Regex pattern `'([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})'` for GUID extraction
2. `Select-String -Pattern` for regex matching
3. Error checking on `powercfg` exit code
4. Locale-safe — no dependency on powercfg aliases

### Pattern 4: Virtualization Stack Validation (WMI-Only)

**What:** Validate WSL2 and Hyper-V state using WMI only (never wsl.exe)

**When to use:** Pre-flight and post-flight validation of virtualization stack

**Example:**
```powershell
<#
.SYNOPSIS
    Validates WSL2 and Hyper-V virtualization stack using WMI.

.DESCRIPTION
    The Test-VirtStack function checks the status of WSL2 and Hyper-V
    using WMI queries and Get-Service cmdlet. This approach avoids calling
    wsl.exe which fails under LOCAL_SYSTEM context (elevated PowerShell).

.EXAMPLE
    $virtStatus = Test-VirtStack

.NOTES
    NEVER calls wsl.exe from elevated context due to LOCAL_SYSTEM limitation.
#>
function Test-VirtStack {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    #region WMI Feature Detection
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
    $vmPlatformFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
    $hypervisorPresent = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty Hypervisor
    #endregion

    #region Service State Detection
    $hvHostService = Get-Service -Name HvHost -ErrorAction SilentlyContinue
    $vmmsService = Get-Service -Name vmms -ErrorAction SilentlyContinue
    $wslService = Get-Service -Name WslService -ErrorAction SilentlyContinue
    $lxssManagerService = Get-Service -Name LxssManager -ErrorAction SilentlyContinue
    #endregion

    #region Status Hashtable
    $status = [ordered]@{
        WSL_Enabled           = ($wslFeature.State -eq 'Enabled')
        VirtualMachine_Enabled = ($vmPlatformFeature.State -eq 'Enabled')
        Hypervisor_Present    = ($hypervisorPresent -eq $true)
        HvHost_Running        = ($hvHostService.Status -eq 'Running')
        vmms_Running          = ($vmmsService.Status -eq 'Running')
        WslService_Running    = ($wslService.Status -eq 'Running')
        LxssManager_Running   = ($lxssManagerService.Status -eq 'Running')
        Overall_Healthy       = $false
    }

    $status.Overall_Healthy = (
        $status.WSL_Enabled -and
        $status.VirtualMachine_Enabled -and
        $status.Hypervisor_Present -and
        $status.HvHost_Running -and
        $status.vmms_Running -and
        $status.WslService_Running -and
        $status.LxssManager_Running
    )
    #endregion

    return $status
}
```

**Source:** Architecture Research PITFALL-06 — WSL LOCAL_SYSTEM error documented

**Key Pattern Elements:**
1. `Get-WindowsOptionalFeature` for WSL feature detection
2. `Get-CimInstance` for hypervisor detection
3. `Get-Service` for virtualization service state
4. NO `wsl.exe` invocation (fails under LOCAL_SYSTEM)
5. Returns hashtable with comprehensive status

### Anti-Patterns to Avoid

- **Backtick line continuation:** Causes parsing failures in splatted cmdlets (PITFALL-07)
  - **What to do instead:** Use splatting `@{}` for multi-parameter cmdlets
- **Locale-sensitive powercfg aliases:** Fail on non-English Windows (PITFALL-03)
  - **What to do instead:** Use hardcoded GUIDs only
- **Calling wsl.exe from elevated context:** Fails with LOCAL_SYSTEM error (PITFALL-06)
  - **What to do instead:** Use WMI queries and Get-Service only
- **Modifying protected services:** Breaks virtualization stack (PITFALL-08)
  - **What to do instead:** Hardcoded blocklist (HvHost, vmms, WslService, LxssManager, VmCompute, vmic*)
- **Non-idempotent operations:** Wasteful and confusing (PITFALL-09)
  - **What to do instead:** Check current state before modifying; emit `[SKIP]` if already configured

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| **JSON serialization** | Custom JSON string concatenation | `ConvertTo-Json -Compress` | Built-in PowerShell cmdlet handles escaping, types, formatting |
| **Registry ownership** | Manual reg.exe calls with complex syntax | `System.Security.AccessControl` classes | .NET provides robust ACL manipulation with proper inheritance flags |
| **GUID extraction** | String parsing with Split/Substring | `Select-String -Pattern` regex | Regex handles locale variations, whitespace, formatting |
| **Service state** | WMI queries with complex filters | `Get-Service` cmdlet | Simple, reliable, built-in |
| **Feature detection** | Registry key checking | `Get-WindowsOptionalFeature` | Official API for Windows feature state |
| **Log file appending** | File handle management with try/catch | `Add-Content -ErrorAction Stop` | Built-in cmdlet handles file locking, encoding, errors |
| **Hashtable validation** | Manual null checking on each key | `[ValidateNotNull()]` attribute | PowerShell parameter validation attributes enforce constraints |

**Key insight:** PowerShell 5.1 includes mature cmdlets for all Phase 1 operations. Custom solutions introduce edge cases, encoding issues, and error handling complexity that built-in cmdlets already handle correctly.

## Common Pitfalls

### Pitfall 1: Missing Comment-Based Help

**What goes wrong:** Functions lack `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER` blocks, making them undiscoverable via `Get-Help`.

**Why it happens:** Developer focuses on implementation and skips documentation.

**How to avoid:** Mandate full comment-based help for all library helpers in Phase 1. Use the Pattern 1 template for all 5 functions.

**Warning signs:** Running `Get-Help Write-OptLog` returns "Help topic not found."

---

### Pitfall 2: Incorrect Parameter Validation

**What goes wrong:** Function accepts invalid parameter values (e.g., empty strings, null values, wrong log levels).

**Why it happens:** Missing `[ValidateNotNullOrEmpty()]`, `[ValidateSet()]`, or other validation attributes.

**How to avoid:**
- Use `[ValidateNotNullOrEmpty()]` on all string parameters
- Use `[ValidateSet()]` for enumerated values (Result, Level)
- Use `[ValidateNotNull()]` on hashtables and complex types
- Use `[ValidateRange()]` for numeric values
- Use `[ValidatePattern()]` for GUIDs and paths

**Warning signs:** Function throws cryptic errors downstream when invalid values are passed.

---

### Pitfall 3: Missing Region Blocks

**What goes wrong:** Code is unorganized, making navigation and maintenance difficult.

**Why it happens:** Developer writes linear code without logical grouping.

**How to avoid:** Use `#region / #endregion` blocks to organize sections:
- `#region Initialization`
- `#region Parameter Validation`
- `#region Core Operations`
- `#region Error Handling`

**Warning signs:** Scrolling through 200+ line function without clear sections.

---

### Pitfall 4: Incorrect Return Types

**What goes wrong:** Function returns inconsistent types (sometimes boolean, sometimes object, sometimes string).

**Why it happens:** No explicit return type definition; ad-hoc return statements.

**How to avoid:**
- Always specify `[OutputType([type])]` attribute
- Return `$true`/`$false` for success/failure (CONTEXT.md decision)
- Use `-OutputType` in comment-based help
- Be explicit about return values in `.DESCRIPTION`

**Warning signs:** Callers must check return type before using value.

---

### Pitfall 5: Missing Error Handling

**What goes wrong:** Unhandled exceptions propagate to entry point, causing script termination.

**Why it happens:** Developer assumes operations never fail.

**How to avoid:**
- Wrap all external operations in `try/catch` blocks
- Catch specific exceptions (`System.Security.SecurityException`, `System.IO.IOException`)
- Write-Error with context (what operation failed, what target)
- Return `$false` on error for boolean functions

**Warning signs:** Script terminates with unhelpful error message when registry key is locked.

---

### Pitfall 6: Hardcoded Paths

**What goes wrong:** Log file paths, rollback manifest paths hardcoded in functions.

**Why it happens:** Function doesn't read from global session state.

**How to avoid:**
- Entry point initializes `$global:LogPath`, `$global:RollbackPath`
- Library helpers read from `$global:` scope
- Never hardcode `$env:TEMP\WinOptimizer` in functions

**Warning signs:** Cannot change log file location without modifying library helpers.

---

### Pitfall 7: Missing Idempotency Checks

**What goes wrong:** Library helpers don't check current state before modifying (e.g., `Save-RollbackEntry` appends duplicate entries).

**Why it happens:** Focus on "make it work" without considering "run it twice."

**How to avoid:**
- For `Write-OptLog`: Always append (logging is inherently idempotent)
- For `Save-RollbackEntry`: Check if entry already exists before appending
- For `Take-RegistryOwnership`: Check current owner before transferring
- For `Get-ActivePlanGuid`: Pure function (no state modification)
- For `Test-VirtStack`: Pure function (no state modification)

**Warning signs:** Running operation twice creates duplicate log/rollback entries.

---

### Pitfall 8: Poor Hashtable Parameter Design

**What goes wrong:** Hashtable parameters accept any keys, leading to silent failures when required keys missing.

**Why it happens:** No documentation of expected hashtable structure.

**How to avoid:**
- Document expected hashtable keys in `.PARAMETER` section
- Use `.EXAMPLE` to show correct hashtable structure
- Optionally validate hashtable keys in function body:
  ```powershell
  $requiredKeys = @('OldValue', 'NewValue')
  foreach ($key in $requiredKeys) {
      if (-not $Values.ContainsKey($key)) {
          throw "Missing required key: $key"
      }
  }
  ```

**Warning signs:** Function fails with "Cannot index into a null array" when hashtable key missing.

---

### Pitfall 9: Inconsistent Log Levels

**What goes wrong:** Wrong log level used (e.g., ERROR for informational messages, INFO for critical failures).

**Why it happens:** No clear definition of when to use each level.

**How to avoid:**
- **DEBUG:** Diagnostic info for troubleshooting (development only)
- **INFO:** Normal operation messages (e.g., "Processing service X")
- **SUCCESS:** Operation completed successfully
- **WARNING:** Non-critical issue (e.g., "Service X not found, skipping")
- **ERROR:** Operation failed but script continuing
- **SKIP:** Idempotency skip (already in desired state)

**Warning signs:** Log file is noisy with wrong levels, making post-mortem analysis difficult.

---

### Pitfall 10: Missing PSScriptRoot or $PWD Handling

**What goes wrong:** Functions assume current working directory is script root, causing path resolution failures.

**Why it happens:** Relative paths used without checking `$PWD`.

**How to avoid:**
- For config files: Use `$PSScriptRoot\..\config\services.json` in entry point
- For library helpers: Read from `$global:` variables set by entry point
- Never assume `$PWD` is project root

**Warning signs:** `config/services.json not found` when running from different directory.

## Code Examples

Verified patterns from official sources:

### Example 1: Function with Hashtable Parameter and Validation

```powershell
<#
.SYNOPSIS
    Saves a rollback entry to the manifest before destructive operations.

.DESCRIPTION
    The Save-RollbackEntry function appends a rollback entry to the JSON manifest
    file. This enables complete restoration of system state via Invoke-Rollback.
    The function reads the existing manifest, appends the new entry, and writes
    the entire manifest back to disk (PowerShell single-threaded execution prevents
    race conditions).

.PARAMETER Type
    The type of rollback entry: "Registry", "Service", "ScheduledTask", "FileSystem".

.PARAMETER Target
    The registry path, service name, task name, or file system path being modified.

.PARAMETER ValueName
    For registry entries: The value name being modified. Not used for other types.

.PARAMETER OriginalData
    The original value before modification (string, numeric, or array).

.PARAMETER OriginalType
    For registry entries: The registry data type (REG_DWORD, REG_SZ, REG_QWORD, etc.).

.PARAMETER OriginalStartType
    For service entries: The original StartType value (Automatic, Manual, Disabled).

.EXAMPLE
    Save-RollbackEntry -Type "Registry" -Target "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -ValueName "AllowTelemetry" -OriginalData "1" -OriginalType "REG_DWORD"

.NOTES
    Must be called BEFORE every destructive operation (Set-ItemProperty, Set-Service, fsutil).
#>
function Save-RollbackEntry {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Registry', 'Service', 'ScheduledTask', 'FileSystem')]
        [string]$Type,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Target,

        [Parameter(Mandatory = $false)]
        [string]$ValueName,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        $OriginalData,

        [Parameter(Mandatory = $false)]
        [ValidateSet('REG_DWORD', 'REG_SZ', 'REG_QWORD', 'REG_MULTI_SZ', 'REG_EXPAND_SZ')]
        [string]$OriginalType,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Automatic', 'Manual', 'Disabled')]
        [string]$OriginalStartType
    )

    try {
        #region Read Existing Manifest or Initialize Empty Array
        if (Test-Path $global:RollbackPath) {
            $manifest = Get-Content -Path $global:RollbackPath | ConvertFrom-Json
        }
        else {
            $manifest = @()
        }
        #endregion

        #region Construct Rollback Entry
        $entry = [ordered]@{
            Module        = $global:CurrentModule
            Type          = $Type
            Target        = $Target
            Timestamp     = Get-Date -Format "o"
        }

        # Add type-specific fields
        if ($Type -eq 'Registry') {
            $entry.ValueName = $ValueName
            $entry.OriginalData = $OriginalData
            $entry.OriginalType = $OriginalType
        }
        elseif ($Type -eq 'Service') {
            $entry.OriginalStartType = $OriginalStartType
        }
        #endregion

        #region Append Entry and Write Manifest
        $manifest += $entry
        $manifest | ConvertTo-Json -Depth 10 | Set-Content -Path $global:RollbackPath
        #endregion

        return $true
    }
    catch {
        Write-Error "Failed to save rollback entry: $_"
        return $false
    }
}
```

**Source:** Architecture Research rollback schema + Microsoft Learn parameter validation patterns

---

### Example 2: config/services.json Structure

```json
{
  "disabled": [
    {
      "name": "DiagTrack",
      "reason": "Microsoft telemetry data collection service"
    },
    {
      "name": "dmwappushservice",
      "reason": "Windows Push Messaging User Data Service (telemetry)"
    },
    {
      "name": "MapsBroker",
      "reason": "Downloaded Maps Manager - unused for development workstations"
    },
    {
      "name": "RetailDemo",
      "reason": "Retail Demo mode service - not needed"
    },
    {
      "name": "WerSvc",
      "reason": "Windows Error Reporting - can be disabled"
    },
    {
      "name": "wisvc",
      "reason": "Windows Insider Service - not needed"
    },
    {
      "name": "NvTelemetryContainer",
      "reason": "Nvidia telemetry container service"
    }
  ],
  "manual": [
    {
      "name": "SysMain",
      "reason": "Superfetch/Prefetch - conditionally disabled in File System module for NVMe"
    },
    {
      "name": "WSearch",
      "reason": "Windows Search - configured with exclusions, not fully disabled"
    },
    {
      "name": "lfsvc",
      "reason": "Geolocation Service - rarely needed"
    },
    {
      "name": "PeerDistSvc",
      "reason": "BranchCache - not needed for single-user workstation"
    },
    {
      "name": "SharedAccess",
      "reason": "Internet Connection Sharing - rarely needed"
    },
    {
      "name": "PrintNotify",
      "reason": "Print spooler notification - not needed if no printer"
    },
    {
      "name": "icssvc",
      "reason": "Windows Mobile Hotspot - rarely needed"
    },
    {
      "name": "NcdAutoSetup",
      "reason": "Network Connection Auto-Setup - not needed"
    },
    {
      "name": "PhoneSvc",
      "reason": "Phone Service - not needed"
    },
    {
      "name": "RmSvc",
      "reason": "Radio Management - rarely needed"
    }
  ],
  "oem": {
    "asus": [
      {
        "name": "ArmouryCrate.Service",
        "displayName": "ASUS Armoury Crate Service",
        "detectionPattern": {
          "type": "Service",
          "query": "Get-Service ArmouryCrate.Service -ErrorAction SilentlyContinue"
        },
        "countermeasure": "PowerPlanReassertion",
        "description": "Reasserts ASUS power plan at boot; requires scheduled task countermeasure"
      },
      {
        "name": "ASUSOptimization",
        "displayName": "ASUS Optimization Service",
        "detectionPattern": {
          "type": "Service",
          "query": "Get-Service ASUSOptimization -ErrorAction SilentlyContinue"
        },
        "countermeasure": "PowerPlanReassertion",
        "description": "ASUS power management override service"
      }
    ],
    "lenovo": [
      {
        "name": "LenovoVantage",
        "displayName": "Lenovo Vantage Service",
        "detectionPattern": {
          "type": "Service",
          "query": "Get-Service LenovoVantage -ErrorAction SilentlyContinue"
        },
        "countermeasure": "PowerPlanReassertion",
        "description": "Lenovo power management override service"
      }
    ],
    "dell": [
      {
        "name": "DellCommandCenter",
        "displayName": "Dell Command Center",
        "detectionPattern": {
          "type": "Service",
          "query": "Get-Service DellCommandCenter -ErrorAction SilentlyContinue"
        },
        "countermeasure": "PowerPlanReassertion",
        "description": "Dell power management override service"
      }
    ],
    "hp": [
      {
        "name": "HP Omen Gaming Hub",
        "displayName": "HP Omen Gaming Hub Service",
        "detectionPattern": {
          "type": "Service",
          "query": "Get-Service 'HP Omen Gaming Hub' -ErrorAction SilentlyContinue"
        },
        "countermeasure": "PowerPlanReassertion",
        "description": "HP power management override service"
      }
    ]
  },
  "protected": [
    {
      "name": "HvHost",
      "reason": "Hyper-V Host Service - CRITICAL for virtualization"
    },
    {
      "name": "vmms",
      "reason": "Hyper-V Virtual Machine Management - CRITICAL for virtualization"
    },
    {
      "name": "WslService",
      "reason": "WSL Service - CRITICAL for WSL2"
    },
    {
      "name": "LxssManager",
      "reason": "WSL Lxss Manager - CRITICAL for WSL2"
    },
    {
      "name": "VmCompute",
      "reason": "Hyper-V Compute Service - CRITICAL for virtualization"
    },
    {
      "name": "vmic*",
      "reason": "All Hyper-V VM Integration Services - CRITICAL for VM functionality"
    }
  ],
  "metadata": {
    "version": "1.0.0",
    "lastUpdated": "2026-03-13",
    "description": "Windows service configuration for WinOptimizer - Disabled, Manual, OEM, and Protected service lists",
    "extensibility": "Users can add custom entries to disabled/manual lists. Protected list MUST NOT be modified."
  }
}
```

**Source:** PRD Section 3.1 + Architecture Research OEM service detection

**Key Schema Elements:**
1. Rich metadata: `name`, `reason` for all entries
2. OEM entries: `displayName`, `detectionPattern`, `countermeasure`, `description`
3. Protected blocklist: Services that must NEVER be touched
4. Metadata section: Version, last updated, extensibility documentation
5. Nested structure: `oem.{vendor}` for organization

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| **Comment-based help optional** | **Mandatory full help blocks** | Community standard since PS 3.0 | Functions discoverable via `Get-Help`; better IDE support |
| **Simple parameter validation** | **Rich validation attributes** | PS 4.0+ | Compile-time validation; better error messages |
| **String return values** | **Typed output with `[OutputType()]`** | PS 5.0+ | Static analysis support; better IDE autocomplete |
| **Global variables for config** | **Session state in `$global:` scope** | PS 5.1 best practice | Explicit dependencies; easier testing |
| **Backtick line continuation** | **Splatting `@{}`** | Documented failure mode | Avoids parsing failures in scheduled tasks |
| **Locale-sensitive aliases** | **Hardcoded GUIDs** | Windows 11 globalization | Works on all Windows locales |

**Deprecated/outdated:**
- **`Get-WmiObject`** (deprecated) → Use `Get-CimInstance` (but `Get-WmiObject` still works in PS 5.1)
- **`Add-Type` for simple classes** → Use `[ordered]@{}` hashtables for structured data
- **Manual JSON parsing** → Use `ConvertTo-Json` and `ConvertFrom-Json`
- **Script-level error handling** → Use `try/catch` with specific exception types

## Open Questions

1. **Log rotation strategy**
   - **What we know:** JSONL log files grow with each operation. Typical session generates 50-200 log entries.
   - **What's unclear:** Maximum log file size before rotation? Number of backup logs to retain?
   - **Recommendation:** Implement in Phase 1 (Write-OptLog) or defer to Phase 7?
     - **Option A:** Simple approach — no rotation (logs in %TEMP%, cleared on reboot)
     - **Option B:** Rotation after 10MB, retain 5 backups (more complex, better for debugging)
     - **Phase 1 recommendation:** Start with Option A (simple). Defer rotation to Phase 7 if needed based on usage patterns.

2. **JSON schema validation for services.json**
   - **What we know:** config/services.json has rich schema. User extensibility is required.
   - **What's unclear:** Should Phase 1 include JSON schema validation? Or trust user input?
   - **Recommendation:** Defer schema validation to Phase 7.
     - **Reason:** Adds complexity (external JSON schema validator dependency or custom validation script). Schema is well-documented in comments; users who modify it understand JSON structure.

3. **Library helper error handling granularity**
   - **What we know:** Functions should return `$true`/`$false` for success/failure.
   - **What's unclear:** Should functions emit specific error types (custom exceptions) or generic `Write-Error`?
   - **Recommendation:** Use generic `Write-Error` with descriptive messages in Phase 1.
     - **Reason:** Simpler. Custom exception types add complexity without clear benefit for current use case. Can add in Phase 7 if error categorization needed for testing.

## Sources

### Primary (HIGH confidence)

- **Microsoft Learn - about_Functions_Advanced_Parameters**
  - URL: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_advanced_parameters
  - Retrieved: 2026-03-13
  - Topics: CmdletBinding, parameter attributes, validation attributes, switch parameters
  - Used for: Library helper function patterns, parameter validation best practices

- **Microsoft Learn - RegistryAccessRule Class**
  - URL: https://learn.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.registryaccessrule
  - Retrieved: 2026-03-13
  - Topics: RegistryAccessRule constructor, InheritanceFlags, PropagationFlags, AccessControlType
  - Used for: Take-RegistryOwnership implementation pattern

- **WinOptimizer PRD (Internal)**
  - File: `/mnt/d/Coding/WinOptim/WinOptimizer_PRD.md`
  - Sections: 1.0 (Scope), 3.1 (Repository Structure), 3.4 (Implementation Order)
  - Used for: Repository structure, service lists, hardcoded GUIDs, OEM detection patterns

- **Architecture Research (Internal)**
  - File: `/mnt/d/Coding/WinOptim/.planning/research/ARCHITECTURE.md`
  - Created: 2026-03-13
  - Topics: Component boundaries, data flow, state management, rollback manifest schema
  - Used for: Library helper responsibilities, session state management, rollback schema

- **Pitfalls Research (Internal)**
  - File: `/mnt/d/Coding/WinOptim/.planning/research/PITFALLS.md`
  - Created: 2026-03-13
  - Topics: 10 documented pitfalls with real-world error cases
  - Used for: PITFALL-01 through PITFALL-10 prevention strategies

- **Stack Research (Internal)**
  - File: `/mnt/d/Coding/WinOptim/.planning/research/STACK.md`
  - Created: 2026-03-13
  - Topics: PowerShell 5.1 constraints, OEM service lists, hardcoded GUIDs, protected services
  - Used for: Service configuration data, power plan GUIDs, virtualization validation approach

- **Requirements (Internal)**
  - File: `/mnt/d/Coding/WinOptim/.planning/REQUIREMENTS.md`
  - Sections: Phase 1 requirements (REPO-01, REPO-03, LIBR-01 through LIBR-05)
  - Used for: Phase 1 success criteria, requirement traceability

- **User Decisions (Internal)**
  - File: `/mnt/d/Coding/WinOptim/.planning/phases/01-foundation-libraries/01-CONTEXT.md`
  - Sections: Implementation Decisions, Claude's Discretion
  - Used for: Library function design constraints, logging strategy, service.json schema

### Secondary (MEDIUM confidence)

- **PowerShell 5.1 Best Practices (Training Data)**
  - Topics: Comment-based help, splatting, error handling, hashtables
  - Confidence: MEDIUM (not verified with official docs in this research cycle)
  - Used for: Code organization patterns, splatting recommendations

- **JSON Logging Patterns (Training Data)**
  - Topics: JSONL format, structured logging, log levels
  - Confidence: MEDIUM (industry standard, but no specific Microsoft Learn source)
  - Used for: Log entry schema, log level definitions

### Tertiary (LOW confidence)

- **WebSearch Results**
  - Query: "PowerShell 5.1 module project structure best practices 2025"
  - Result: Search service returned empty results
  - Confidence: LOW (search not functional)
  - **Note:** No web search sources used due to technical issues. Research relies on official Microsoft Learn docs fetched via webReader, internal research files, and established PowerShell best practices.

## Metadata

**Confidence breakdown:**
- **Standard stack:** HIGH - Microsoft Learn official docs + internal PRD validation
- **Architecture:** HIGH - PRD fully specifies structure; internal architecture research validates approach
- **Pitfalls:** CRITICAL - All 10 pitfalls documented from real-world Windows 11 optimization sessions
- **Code examples:** HIGH - Based on official Microsoft Learn patterns + internal research
- **Service configuration:** HIGH - OEM services validated in PRD real-world testing

**Research date:** 2026-03-13
**Valid until:** 2026-04-13 (30 days - stable domain, PowerShell 5.1 is mature technology)

**Research limitations:**
- Web search functionality was not working; relied on official Microsoft Learn docs via webReader
- Some best practices based on training data (marked as MEDIUM confidence)
- JSON schema validation approach deferred to Phase 7 (open question)

**Next steps:**
- Review Phase 1 RESEARCH.md and address open questions before planning
- Confirm log rotation strategy (simple vs. complex)
- Confirm services.json schema validation approach (Phase 1 vs. Phase 7)
- Proceed to Phase 1 planning once open questions resolved
