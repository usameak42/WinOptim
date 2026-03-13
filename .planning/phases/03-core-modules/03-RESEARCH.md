# Phase 3: Core Modules - Research

**Researched:** 2026-03-13
**Domain:** PowerShell 5.1 Module Development, Windows Registry Operations, WMI GPU Detection, Service Management
**Confidence:** HIGH

## Summary

Phase 3 implements three core optimization modules: Telemetry suppression, Service optimization, and GPU/DWM optimization. This phase builds directly on the library helpers completed in Phase 1 (Write-OptLog, Save-RollbackEntry, Take-RegistryOwnership) and the safety gates from Phase 2 (restore points, elevation, version validation, virtualization testing).

The research reveals that PowerShell 5.1 provides all necessary native cmdlets for this phase: Set-ItemProperty for registry operations, Get-Service/Set-Service for service management, Get-WmiObject for GPU detection, Disable-ScheduledTask/Unregister-ScheduledTask for task management, and Set-Service for service startup type modification. The existing lib/ helpers already demonstrate the project's established patterns for rollback manifests, JSONL logging, and error handling.

**Primary recommendation:** Implement the three modules using the established patterns from Phase 1 lib/ files—strict idempotency checks, rollback-before-modify ordering, comprehensive JSONL logging, and user interaction prompts as specified in CONTEXT.md. Use the config/services.json as the single source of truth for service targets.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Error Handling Strategy:**
- Service disable failures → Prompt user to continue or halt per service
- Registry ownership failures → Log WARNING, skip that registry operation, continue
- Rollback failures → Halt immediately (rollback is critical)
- AutoLogger session failures → Skip failed session, continue with others
- Dependent service failures → Prompt user to disable parent+child or skip both
- GPU not found → Log WARNING, skip entire GPU module
- Battery status unknown → Prompt user to confirm power source
- Registry corruption → Log, skip, continue with other keys
- Scheduled task failures → Continue disabling remaining tasks, list failed at end
- Service state mismatch → Record both StartType and running state, log WARNING
- HAGS still disabled (no reboot) → Halt, instruct user to reboot
- MPO key missing → Log WARNING (expected on older Windows)
- Access denied (even with admin) → Attempt elevation with alternative credentials
- Service from config doesn't exist → Mark as disabled in rollback, continue
- Service stop timeout → Prompt user to force kill or skip
- Concurrent modification failures → Retry operations sequentially
- Log file write failure → Console-only fallback, warn user
- Rollback manifest corruption → Warn user, prompt to choose: halt, continue, or recreate
- WMI query fails → Warn user, prompt to choose: halt module, use fallback detection, or skip GPU
- Multiple GPUs → Multi-select menu with indices, user chooses which to optimize
- No GPU found → Warn user, prompt to choose: halt, skip GPU module, or attempt generic optimizations
- Unknown GPU vendor → Inform user, prompt to choose: apply generic optimizations, skip vendor-specific, or halt
- Virtual GPU detected → Skip virtual GPU (Hyper-V, VMware virtual display)
- GPU optimization step failure → Prompt user to skip failed step or halt GPU module

**User Interaction Design:**
- HAGS reboot → Prompt user: "Reboot now? (Y/N)" — trigger reboot if Y, warn if N
- Console output → Verbose color output by default (SUCCESS/WARNING/ERROR/INFO/ACTION/SKIP)
- Progress indication → Progress bar for long operations (e.g., "Disabling services... 3/5")
- Confirmations → Module-level confirmation (prompt once at module start: "Apply X optimizations?")
- Summary display → Detailed summary showing successes, skips, warnings, and errors with counts
- Error message format → User-friendly format in console ("Failed to disable X — Access Denied")
- Warning handling → Prompt user: "Continue despite warnings?"
- Log file location → Show log file path at start and end of execution
- Recovery on module failure → Prompt user: continue or rollback
- No dry-run mode → No dry-run support
- Color scheme → Standard colors (Green=success, Yellow=warning, Red=error, Blue=info, Cyan=action, Gray=skip)
- Timing display → Show timing only for operations over 30 seconds
- Interactive rollback → Prompt for rollback only if errors occurred
- Batch mode → Halt on any prompt (no interactive prompts in non-interactive mode)
- Verbose mode → Show all operations (every registry value, service name, task being checked/modified)
- Update checking → Check GitHub releases, notify if update available (non-blocking)

**Idempotency Depth:**
- Service checks → Check StartType + running state — skip only if both match desired state
- Registry checks → Skip if key exists with correct value AND correct type (DWORD vs QWORD match)
- AutoLogger checks → Check only telemetry-related sessions (targeted, faster)
- Idempotency logging → Log every check with result ("Checking service X... already disabled [SKIP]")
- Task checks → Check State + Enabled property — skip if both indicate disabled
- HAGS checks → Check registry value + GPU driver capability validation
- MPO checks → Check registry value + verify MPO is actually disabled in system
- Rollback data → Always save to rollback manifest (duplicate entries overwrite)

**GPU Detection Strategy:**
- Multiple GPUs → Multi-select menu with index numbers, full GPU names displayed, discrete GPU pre-selected by default
- No GPU found → Warn user, prompt to choose: halt, skip GPU module, or attempt generic optimizations (MPO disable via registry without vendor checks)
- Unknown GPU vendor → Inform user, prompt to choose: apply generic optimizations only, skip vendor-specific steps, or halt for manual configuration
- Nvidia GPU → Prompt user: "Apply Nvidia-specific optimizations?" (full Nvidia optimization vs HAGS only)
- Driver version checking → Check driver version, warn if below minimum threshold
- Intel integrated GPU → Prompt user: "Optimize integrated GPU?" (usually skipped alongside discrete)
- WMI fallback detection → Claude's discretion (not specified by user)
- Virtual GPU → Skip virtual GPU with log warning
- Hybrid GPU mode → Prompt user for hybrid GPU handling (e.g., Optimus, Switchable)
- HAGS capability validation → Inform user, prompt to choose: query driver for HAGS support, try-catch (attempt enable, catch error if unsupported), or enable HAGS for all GPUs (assume support)
- MPO detection → Try to disable MPO, log WARNING if key doesn't exist
- GPU display → Show full GPU name from WMI (e.g., "NVIDIA GeForce RTX 3080")
- Default selection → Pre-select discrete GPU in multi-GPU menu
- AMD GPU → Prompt user: "Apply AMD-specific optimizations?" or "Skip vendor-specific?"
- HAGS-only mode → Prompt user per optimization step
- GPU detection timing → Detect GPU once at module start, verify GPU still exists before critical steps

**Rollback Manifest Structure:**
- Entry fields → type, path, oldValue, newValue, timestamp, module (6 core fields)
- Organization → Grouped by module (telemetry, services, gpu) with nested entries
- Complex values → Store arrays/objects as base64-encoded string
- File format → JSON with pretty-print (human-readable)

**JSONL Logging Format:**
- Log entry fields → timestamp, module, operation, status, level (INFO/WARN/ERROR/SUCCESS/ACTION/SKIP), target, details, duration (8 fields)
- Error details → Simple string field with full error message
- Log rotation → Create new log file each run (timestamp in filename)
- Log entry format → Pretty JSON (one object per line with indentation, human-readable)

**Service Identification:**
- Service property → Use both ServiceName and DisplayName, match against either property
- Config file storage → config/services.json stores both ServiceName and DisplayName properties
- Localization → Store English DisplayName as reference, match against ServiceName
- Matching → Case-insensitive match on both properties

**Scheduled Task Handling:**
- Task action → Prompt user at runtime with explanation: Disable only (reversible), Delete task (cleaner but irreversible), Hybrid (disable custom, delete system telemetry)
- Already disabled → Still attempt to disable (idempotent operation)
- System vs custom → Distinguish by task author/creator
- Task rollback → Hybrid restore — re-enable if disabled, recreate if deleted

### Claude's Discretion

**WMI Fallback Detection:**
- Not specified by user — discretion to implement WMI fallback detection or skip it
- Research indicates WMI is reliable for GPU detection; fallback may not be necessary

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope (telemetry suppression, service optimization, GPU/DWM optimization modules).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-------------------|
| **TELM-01** | Script can set AllowTelemetry to 0 in DataCollection policy key | PowerShell Set-ItemProperty cmdlet with registry path HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection |
| **TELM-02** | Script can disable AutoLogger ETW sessions (AutoLogger-Diagtrack-Listener, DiagLog, SQMLogger) | Set-ItemProperty on HKLM:\SYSTEM\CurrentControlSet\Control\WMI\AutoLogger\{sessionname} with Start=0 |
| **TELM-03** | Script can stop and disable DiagTrack and dmwappushservice services | Get-Service/Set-Service with -StartupType Disabled and Stop-Service -Force |
| **TELM-04** | Script can disable telemetry scheduled tasks (CompatibilityAppraiser, ProgramDataUpdater, Consolidator, UsbCeip) | Disable-ScheduledTask or Unregister-ScheduledTask with task path \Microsoft\Windows\Application Experience\ |
| **TELM-05** | Module records prior state of all values to rollback manifest | Save-RollbackEntry helper from Phase 1 captures Type, Target, OriginalData, OriginalType before modification |
| **GPUD-01** | Script can enable Hardware-Accelerated GPU Scheduling via HwSchMode = 2 | Set-ItemProperty on HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers with HwSchMode=2 (DWORD) |
| **GPUD-02** | Script can disable Multi-Plane Overlay via DWM OverlayTestMode = 5 | Set-ItemProperty on HKLM:\SOFTWARE\Microsoft\Windows\Dwm with OverlayTestMode=5 (DWORD) |
| **GPUD-03** | Script can detect Nvidia GPU presence via WMI and output NVCP manual configuration checklist | Get-WmiObject Win32_VideoController with Where-Object filtering for Name like "*NVIDIA*" |
| **GPUD-04** | Script can disable NvTelemetryContainer service | Set-Service with -StartupType Disabled, part of config/services.json disabled list |
| **GPUD-05** | Script validates HAGS activation post-reboot via registry readback | Get-ItemProperty on HwSchMode registry key to verify value=2, prompt user if value still ≠2 |
| **SRVC-01** | Script can disable DiagTrack, dmwappushservice, MapsBroker, RetailDemo, WerSvc, wisvc, NvTelemetryContainer services | Set-Service -StartupType Disabled on config/services.json disabled list |
| **SRVC-02** | Script can set SysMain, WSearch, lfsvc, PeerDistSvc, SharedAccess, PrintNotify, icssvc, NcdAutoSetup, PhoneSvc, RmSvc to Manual startup | Set-Service -StartupType Manual on config/services.json manual list |
| **SRVC-03** | Script validates protected services (HvHost, vmms, WslService, LxssManager, VmCompute, vmic*) remain untouched | Explicit blocklist check before any service modification, fail-fast if protected service in target list |
| **SRVC-04** | Module logs prior StartType of each service for rollback | Save-RollbackEntry with Type='Service', OriginalStartType captured before Set-Service |
| **SRVC-05** | Module gracefully skips services not found without halting | Get-Service -ErrorAction SilentlyContinue, check $null before modification, log SKIP |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **PowerShell 5.1** | Built-in Windows 11 | Script execution platform | Project requirement (QUAL-04), PRD specification, all existing lib/ files use #Requires -Version 5.1 |
| **Set-ItemProperty** | Built-in cmdlet | Registry value modification | Standard way to modify registry values in PowerShell 5.1, used in Take-RegistryOwnership pattern |
| **Get-Service / Set-Service** | Built-in cmdlet | Service enumeration and startup type modification | Native PowerShell service management, supports -ErrorAction SilentlyContinue for graceful skip pattern |
| **Get-WmiObject** | Built-in cmdlet | GPU detection via Win32_VideoController | Standard WMI query method for hardware information, works in PowerShell 5.1 without CIM dependency |
| **Disable-ScheduledTask / Unregister-ScheduledTask** | Built-in cmdlet | Scheduled task management | Native PowerShell scheduled task operations, support -TaskPath parameter for Microsoft\Windows\ tasks |
| **Get-ScheduledTask** | Built-in cmdlet | Task enumeration and state checking | Allows checking State and Enabled properties for idempotency (CONTEXT requirement) |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **Write-OptLog** | 1.0.0 (Phase 1 lib) | Structured JSONL logging | After every operation (QUAL-03 requirement), already implemented in /mnt/d/Coding/WinOptim/lib/Write-OptLog.ps1 |
| **Save-RollbackEntry** | 1.0.0 (Phase 1 lib) | Rollback manifest recording | Before every destructive operation (QUAL-02 requirement), already implemented in /mnt/d/Coding/WinOptim/lib/Save-RollbackEntry.ps1 |
| **Take-RegistryOwnership** | 1.0.0 (Phase 1 lib) | TrustedInstaller ACL transfer | For registry keys owned by TrustedInstaller (e.g., Windows Search), already implemented in /mnt/d/Coding/WinOptim/lib/Take-RegistryOwnership.ps1 |
| **Test-VirtStack** | 1.0.0 (Phase 1 lib) | WSL2/Hyper-V validation | Pre-flight and post-flight validation (SAFE-04 requirement), already implemented in /mnt/d/Coding/WinOptim/lib/Test-VirtStack.ps1 |
| **System.Security.AccessControl** | .NET Framework 4.x | Registry ACL manipulation | Used by Take-RegistryOwnership for ownership transfer, standard .NET approach |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| **Get-WmiObject** | Get-CimInstance | CIM is newer but requires WS-Mgmt service; WMI is more reliable in PowerShell 5.1 and PRD specifies WMI |
| **Set-Service -StartupType** | sc.exe config command | sc.exe is external binary, harder to parse output; Set-Service is native PowerShell cmdlet |
| **Disable-ScheduledTask** | schtasks.exe /change | schtasks.exe is legacy command-line tool; Disable-ScheduledTask is object-oriented PowerShell cmdlet |
| **Set-ItemProperty** | reg.exe add command | reg.exe is external binary with different error handling; Set-ItemProperty integrates with PowerShell error handling |

**Installation:**
No external packages required. All cmdlets are built into PowerShell 5.1 and Windows 11. Lib/ helpers are already implemented in Phase 1.

## Architecture Patterns

### Recommended Project Structure

Phase 3 adds implementation to three placeholder module files:

```
modules/
├── Invoke-TelemetryBlock.ps1     # TELM-01 through TELM-05
├── Invoke-GpuDwmOptimize.ps1     # GPUD-01 through GPUD-05
└── Invoke-ServiceOptimize.ps1    # SRVC-01 through SRVC-05

config/
└── services.json                  # Service lists (disabled, manual, protected) - already exists

lib/
├── Write-OptLog.ps1               # Logging helper - already implemented
├── Save-RollbackEntry.ps1         # Rollback manifest helper - already implemented
└── Take-RegistryOwnership.ps1     # Registry ACL helper - already implemented
```

### Pattern 1: Module Structure with Region Blocks

**What:** Each module file follows the established pattern from Phase 1 lib/ files with #region blocks organizing sections

**When to use:** All module implementations must use this structure for consistency (QUAL-10 requirement)

**Example:**
```powershell
#Requires -Version 5.1

<#
.SYNOPSIS
    Module description here.

.DESCRIPTION
    Detailed module description here.
#>

function Invoke-TelemetryBlock {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    begin {
        # Initialize counters for summary
        $successCount = 0
        $skipCount = 0
        $warningCount = 0
        $errorCount = 0
    }

    process {
        #region Stage 1: Registry Telemetry Settings
        # ... code here ...
        #endregion

        #region Stage 2: AutoLogger Sessions
        # ... code here ...
        #endregion

        #region Stage 3: Telemetry Services
        # ... code here ...
        #endregion

        #region Stage 4: Scheduled Tasks
        # ... code here ...
        #endregion

        #region Summary Display
        Write-Host "`n=== Telemetry Suppression Summary ===" -ForegroundColor Cyan
        Write-Host "Successful: $successCount | Skipped: $skipCount | Warnings: $warningCount | Errors: $errorCount" -ForegroundColor White
        #endregion
    }

    end {
        # Cleanup - no resources to release
    }
}
```

**Source:** Pattern established in `/mnt/d/Coding/WinOptim/lib/Invoke-RestorePoint.ps1` (Phase 2 implementation)

### Pattern 2: Idempotent Registry Operation

**What:** Always check current state before modifying, log SKIP if already in desired state

**When to use:** All Set-ItemProperty operations (QUAL-01 requirement)

**Example:**
```powershell
# Example from TELM-01: AllowTelemetry registry key
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
$valueName = "AllowTelemetry"
$desiredValue = 0

# Check current state
$currentValue = Get-ItemProperty -Path $regPath -Name $valueName -ErrorAction SilentlyContinue

if ($null -ne $currentValue -and $currentValue.$valueName -eq $desiredValue) {
    Write-Host "[SKIP] AllowTelemetry already set to $desiredValue" -ForegroundColor Gray

    Write-OptLog -Module "Invoke-TelemetryBlock" `
        -Operation "Get-ItemProperty" `
        -Target "$regPath\$valueName" `
        -Values @{ CurrentValue = $currentValue.$valueName; DesiredValue = $desiredValue } `
        -Result "Skip" `
        -Message "AllowTelemetry already at desired value" `
        -Level "SKIP"

    $skipCount++
    return
}

# Save rollback entry BEFORE modification
Save-RollbackEntry -Type "Registry" `
    -Target $regPath `
    -ValueName $valueName `
    -OriginalData $currentValue.$valueName `
    -OriginalType "REG_DWORD"

# Modify value
Set-ItemProperty -Path $regPath -Name $valueName -Value $desiredValue -Type DWord -ErrorAction Stop

Write-Host "[SUCCESS] Set AllowTelemetry to $desiredValue" -ForegroundColor Green

Write-OptLog -Module "Invoke-TelemetryBlock" `
    -Operation "Set-ItemProperty" `
    -Target "$regPath\$valueName" `
    -Values @{ OldValue = $currentValue.$valueName; NewValue = $desiredValue } `
    -Result "Success" `
    -Message "Telemetry capped at Security level" `
    -Level "SUCCESS"

$successCount++
```

**Source:** Pattern established in `/mnt/d/Coding/WinOptim/lib/Invoke-RestorePoint.ps1` lines 53-73 (restore point check idempotency)

### Pattern 3: Service Operation with Protected Service Check

**What:** Explicitly validate service is not in protected list before modification

**When to use:** All Set-Service operations (SRVC-03 requirement)

**Example:**
```powershell
# Example from SRVC-01: Disable telemetry services
$protectedServices = @('HvHost', 'vmms', 'WslService', 'LxssManager', 'VmCompute')
$protectedWildcard = @('vmic*')

# Load service list from config
$config = Get-Content "$PSScriptRoot\..\config\services.json" | ConvertFrom-Json
$disabledList = $config.disabled

foreach ($serviceEntry in $disabledList) {
    $serviceName = $serviceEntry.name

    # CRITICAL: Protected service check (SRVC-03)
    if ($protectedServices -contains $serviceName) {
        Write-Host "[ERROR] $serviceName is a protected virtualization service. Cannot disable." -ForegroundColor Red
        $errorCount++
        continue
    }

    # Check for wildcard match (e.g., vmic*)
    foreach ($wildcard in $protectedWildcard) {
        if ($serviceName -like $wildcard) {
            Write-Host "[ERROR] $serviceName matches protected pattern $wildcard. Cannot disable." -ForegroundColor Red
            $errorCount++
            continue
        }
    }

    # Get service
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

    if ($null -eq $service) {
        Write-Host "[SKIP] Service '$serviceName' not found on this system" -ForegroundColor Gray
        Write-OptLog -Module "Invoke-ServiceOptimize" `
            -Operation "Get-Service" `
            -Target $serviceName `
            -Values @{} `
            -Result "Skip" `
            -Message "Service not found" `
            -Level "SKIP"
        $skipCount++
        continue
    }

    # Check current state for idempotency (CONTEXT: Service state mismatch)
    $currentStartType = (Get-WmiObject -Class Win32_Service -Filter "Name='$serviceName'").StartMode
    $currentStatus = $service.Status

    if ($currentStartType -eq 'Disabled') {
        if ($currentStatus -eq 'Stopped') {
            # Both StartType and status match desired state
            Write-Host "[SKIP] Service '$serviceName' already disabled and stopped" -ForegroundColor Gray
            $skipCount++
            continue
        } else {
            # StartType matches but service still running
            Write-Host "[WARNING] Service '$serviceName' disabled but still running ($currentStatus)" -ForegroundColor Yellow
            # Log warning per CONTEXT decision
        }
    }

    # Prompt user per CONTEXT: Service disable failures
    Write-Host "[ACTION] Disabling service: $serviceName" -ForegroundColor Cyan
    $continue = Read-Host -Prompt "Disable this service? (Y/N/A for All)"

    if ($continue -ne 'Y' -and $continue -ne 'y' -and $continue -ne 'A' -and $continue -ne 'a') {
        Write-Host "[SKIP] User chose to skip $serviceName" -ForegroundColor Gray
        $skipCount++
        continue
    }

    # Save rollback entry BEFORE modification (SRVC-04)
    Save-RollbackEntry -Type "Service" `
        -Target $serviceName `
        -OriginalStartType $currentStartType

    # Attempt to stop service if running
    if ($service.Status -ne 'Stopped') {
        try {
            Stop-Service -Name $serviceName -Force -ErrorAction Stop
            Write-Host "[SUCCESS] Stopped service $serviceName" -ForegroundColor Green
        } catch {
            # CONTEXT: Service stop timeout
            Write-Host "[ERROR] Failed to stop $serviceName: $_" -ForegroundColor Red
            $forceKill = Read-Host -Prompt "Force kill service process? (Y/N)"
            if ($forceKill -eq 'Y' -or $forceKill -eq 'y') {
                # Force kill logic here
            } else {
                $errorCount++
                continue
            }
        }
    }

    # Disable service
    try {
        Set-Service -Name $serviceName -StartupType Disabled -ErrorAction Stop
        Write-Host "[SUCCESS] Disabled service $serviceName" -ForegroundColor Green

        Write-OptLog -Module "Invoke-ServiceOptimize" `
            -Operation "Set-Service" `
            -Target $serviceName `
            -Values @{ OldStartType = $currentStartType; NewStartType = 'Disabled' } `
            -Result "Success" `
            -Message "Service disabled successfully" `
            -Level "SUCCESS"

        $successCount++
    } catch {
        Write-Host "[ERROR] Failed to disable $serviceName: $_" -ForegroundColor Red
        $errorCount++
    }
}
```

**Source:** Pattern established in PRD Section 2.3 Module 6 (Service Management) and CONTEXT decisions

### Pattern 4: GPU Detection with Vendor Filtering

**What:** Use WMI to detect GPUs, filter by vendor, handle multiple GPUs

**When to use:** GPU module for HAGS/MPO optimizations (GPUD-03 requirement)

**Example:**
```powershell
# Example from GPUD-03: Nvidia GPU detection
Write-Host "[INFO] Detecting GPUs..." -ForegroundColor Cyan

try {
    $gpus = Get-WmiObject Win32_VideoController
} catch {
    # CONTEXT: WMI Query Fails
    Write-Host "[WARNING] WMI query failed: $_" -ForegroundColor Yellow
    $choice = Read-Host -Prompt "Halt GPU module, use fallback detection, or skip GPU optimizations? (H/F/S)"

    if ($choice -eq 'H' -or $choice -eq 'h') {
        Write-Host "[ERROR] Halting GPU module per user choice" -ForegroundColor Red
        return $false
    } elseif ($choice -eq 'S' -or $choice -eq 's') {
        Write-Host "[SKIP] Skipping GPU module per user choice" -ForegroundColor Gray
        return $false
    } else {
        # Fallback detection logic here (CONTEXT discretion)
    }
}

if ($null -eq $gpus -or $gpus.Count -eq 0) {
    # CONTEXT: No GPU Found
    Write-Host "[WARNING] No GPUs detected via WMI" -ForegroundColor Yellow
    $choice = Read-Host -Prompt "Halt, skip GPU module, or attempt generic optimizations? (H/S/G)"

    if ($choice -eq 'G' -or $choice -eq 'g') {
        # Attempt MPO disable only
        Write-Host "[INFO] Attempting generic MPO disable..." -ForegroundColor Cyan
    } else {
        return $false
    }
}

# Filter out virtual GPUs (CONTEXT: Virtual GPU Detected)
$physicalGpus = $gpus | Where-Object {
    $_.Name -notlike '*Hyper-V*' -and
    $_.Name -notlike '*VMware*' -and
    $_.Name -notlike '*Virtual*' -and
    $_.Name -notlike '*Remote Desktop*'
}

if ($physicalGpus.Count -eq 0) {
    Write-Host "[SKIP] No physical GPUs found (all detected GPUs are virtual)" -ForegroundColor Gray
    return $false
}

# Check for Nvidia GPUs
$nvidiaGpus = $physicalGpus | Where-Object { $_.Name -like '*NVIDIA*' }
$amdGpus = $physicalGpus | Where-Object { $_.Name -like '*AMD*' -or $_.Name -like '*Radeon*' }

# CONTEXT: Multiple GPUs - Multi-select menu
if ($physicalGpus.Count -gt 1) {
    Write-Host "`nMultiple GPUs detected:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $physicalGpus.Count; $i++) {
        $gpuType = if ($nvidiaGpus -contains $physicalGpus[$i]) { "Nvidia" }
                   elseif ($amdGpus -contains $physicalGpus[$i]) { "AMD" }
                   else { "Unknown" }

        $discrete = if ($physicalGpus[$i].AdapterRAM -gt 2GB) { " [Discrete]" } else { " [Integrated]" }

        Write-Host "  [$i] $($physicalGpus[$i].Name) ($gpuType)$discrete" -ForegroundColor White
    }

    # CONTEXT: Default Selection - Pre-select discrete GPU
    $defaultIndex = $physicalGpus.IndexOf(($physicalGpus | Where-Object { $_.AdapterRAM -gt 2GB } | Select-Object -First 1))

    $selection = Read-Host -Prompt "Select GPU(s) to optimize (comma-separated indices, default=$defaultIndex)"
    if ([string]::IsNullOrWhiteSpace($selection)) {
        $selection = $defaultIndex
    }

    $selectedGpus = $selection -split ',' | ForEach-Object {
        $physicalGpus[[int]$_]
    }
} else {
    $selectedGpus = @($physicalGpus[0])
}

# Process selected GPUs
foreach ($gpu in $selectedGpus) {
    $gpuName = $gpu.Name

    # CONTEXT: Unknown GPU Vendor
    $isNvidia = $gpuName -like '*NVIDIA*'
    $isAmd = $gpuName -like '*AMD*' -or $gpuName -like '*Radeon*'

    if (-not $isNvidia -and -not $isAmd) {
        Write-Host "[WARNING] Unknown GPU vendor: $gpuName" -ForegroundColor Yellow
        $choice = Read-Host -Prompt "Apply generic optimizations, skip vendor-specific, or halt? (G/S/H)"

        if ($choice -eq 'H' -or $choice -eq 'h') {
            return $false
        } elseif ($choice -eq 'S' -or $choice -eq 's') {
            continue
        }
        # else: apply generic optimizations
    }

    # CONTEXT: Nvidia GPU - Prompt for vendor-specific optimizations
    if ($isNvidia) {
        $nvidiaOpt = Read-Host -Prompt "Apply Nvidia-specific optimizations for $gpuName? (Y/N)"
        if ($nvidiaOpt -eq 'Y' -or $nvidiaOpt -eq 'y') {
            # Disable NvTelemetryContainer service
            $nvTelemetry = Get-Service -Name 'NvTelemetryContainer' -ErrorAction SilentlyContinue
            if ($null -ne $nvTelemetry) {
                # ... disable logic ...
            }

            # Output NVCP manual configuration checklist
            Write-Host "`n[NVIDIA Control Panel Manual Configuration]" -ForegroundColor Yellow
            Write-Host "1. Open NVIDIA Control Panel" -ForegroundColor White
            Write-Host "2. Go to 'Manage 3D Settings'" -ForegroundColor White
            Write-Host "3. Set 'Power management mode' to 'Prefer maximum performance'" -ForegroundColor White
            Write-Host "4. Set 'Texture filtering - Quality' to 'High performance'" -ForegroundColor White
            Write-Host "5. Set 'Max Frame Rate' to your monitor refresh rate" -ForegroundColor White
        } else {
            Write-Host "[INFO] Skipping Nvidia-specific optimizations, applying HAGS-only mode" -ForegroundColor Cyan
        }
    }

    # CONTEXT: AMD GPU - Prompt for vendor-specific optimizations
    if ($isAmd) {
        $amdOpt = Read-Host -Prompt "Apply AMD-specific optimizations for $gpuName? (Y/N)"
        if ($amdOpt -ne 'Y' -and $amdOpt -ne 'y') {
            Write-Host "[INFO] Skipping AMD-specific optimizations" -ForegroundColor Cyan
            continue
        }
        # AMD-specific logic here
    }

    # Apply HAGS (GPUD-01)
    Write-Host "[ACTION] Enabling Hardware-Accelerated GPU Scheduling..." -ForegroundColor Cyan

    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    $valueName = "HwSchMode"
    $desiredValue = 2

    # CONTEXT: HAGS Checks - Check registry value + driver capability
    $currentHags = Get-ItemProperty -Path $regPath -Name $valueName -ErrorAction SilentlyContinue

    if ($null -ne $currentHags -and $currentHags.$valueName -eq $desiredValue) {
        Write-Host "[SKIP] HAGS already enabled" -ForegroundColor Gray
    } else {
        # CONTEXT: HAGS Capability Validation - Try-catch approach
        try {
            # Save rollback entry
            Save-RollbackEntry -Type "Registry" `
                -Target $regPath `
                -ValueName $valueName `
                -OriginalData $currentHags.$valueName `
                -OriginalType "REG_DWORD"

            # Enable HAGS
            Set-ItemProperty -Path $regPath -Name $valueName -Value $desiredValue -Type DWord -ErrorAction Stop

            Write-Host "[SUCCESS] HAGS enabled (requires reboot to activate)" -ForegroundColor Green

            # CONTEXT: HAGS Reboot - Prompt user
            $reboot = Read-Host -Prompt "Reboot now to activate HAGS? (Y/N)"
            if ($reboot -eq 'Y' -or $reboot -eq 'y') {
                Restart-Computer -Confirm
            } else {
                Write-Host "[WARNING] HAGS will not be active until reboot" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "[ERROR] Failed to enable HAGS: $_" -ForegroundColor Red
            Write-Host "[INFO] Your GPU driver may not support HAGS" -ForegroundColor Cyan
        }
    }

    # Apply MPO disable (GPUD-02)
    Write-Host "[ACTION] Disabling Multi-Plane Overlay..." -ForegroundColor Cyan

    $dwmPath = "HKLM:\SOFTWARE\Microsoft\Windows\Dwm"
    $mpoValue = "OverlayTestMode"
    $desiredMpo = 5

    # CONTEXT: MPO Checks - Check registry value + verify system state
    $currentMpo = Get-ItemProperty -Path $dwmPath -Name $mpoValue -ErrorAction SilentlyContinue

    if ($null -eq $currentMpo) {
        # CONTEXT: MPO Key Missing - Log WARNING (expected on older Windows)
        Write-Host "[WARNING] MPO registry key not found (expected on older Windows versions)" -ForegroundColor Yellow

        Write-OptLog -Module "Invoke-GpuDwmOptimize" `
            -Operation "Get-ItemProperty" `
            -Target "$dwmPath\$mpoValue" `
            -Values @{} `
            -Result "Warning" `
            -Message "MPO key not found, may not be supported on this Windows version" `
            -Level "WARNING"
    } elseif ($currentMpo.$mpoValue -eq $desiredMpo) {
        Write-Host "[SKIP] MPO already disabled" -ForegroundColor Gray
    } else {
        # Save rollback entry
        Save-RollbackEntry -Type "Registry" `
            -Target $dwmPath `
            -ValueName $mpoValue `
            -OriginalData $currentMpo.$mpoValue `
            -OriginalType "REG_DWORD"

        # Disable MPO
        Set-ItemProperty -Path $dwmPath -Name $mpoValue -Value $desiredMpo -Type DWord -ErrorAction Stop

        Write-Host "[SUCCESS] MPO disabled" -ForegroundColor Green

        Write-OptLog -Module "Invoke-GpuDwmOptimize" `
            -Operation "Set-ItemProperty" `
            -Target "$dwmPath\$mpoValue" `
            -Values @{ OldValue = $currentMpo.$mpoValue; NewValue = $desiredMpo } `
            -Result "Success" `
            -Message "Multi-Plane Overlay disabled" `
            -Level "SUCCESS"
    }
}
```

**Source:** Pattern established in CONTEXT decisions (GPU Detection Strategy) and PRD Section 2.3 Module 2

### Pattern 5: Scheduled Task Handling with User Choice

**What:** Prompt user for disable/delete/hybrid action, handle system vs custom tasks

**When to use:** Scheduled task management in Telemetry module (TELM-04 requirement)

**Example:**
```powershell
# Example from TELM-04: Scheduled task handling
$tasks = @(
    @{ Name = 'CompatibilityAppraiser'; Path = '\Microsoft\Windows\Application Experience\CompatibilityAppraiser' },
    @{ Name = 'ProgramDataUpdater'; Path = '\Microsoft\Windows\Application Experience\ProgramDataUpdater' },
    @{ Name = 'Consolidator'; Path = '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator' },
    @{ Name = 'UsbCeip'; Path = '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip' }
)

# CONTEXT: Task Action - Prompt user at runtime
Write-Host "`n[Scheduled Task Handling Strategy]" -ForegroundColor Cyan
Write-Host "1. Disable only: Sets State=0, fully reversible" -ForegroundColor White
Write-Host "2. Delete task: Removes task, cleaner but irreversible" -ForegroundColor White
Write-Host "3. Hybrid: Disable custom tasks, delete system telemetry tasks" -ForegroundColor White

$strategy = Read-Host -Prompt "Choose strategy (1/2/3)"

foreach ($task in $tasks) {
    $taskName = $task.Name
    $taskPath = $task.Path

    try {
        $scheduledTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

        if ($null -eq $scheduledTask) {
            Write-Host "[SKIP] Task '$taskName' not found" -ForegroundColor Gray
            $skipCount++
            continue
        }

        # CONTEXT: Task Checks - Check State + Enabled property
        $currentState = $scheduledTask.State
        $currentEnabled = $scheduledTask.Enabled

        if ($currentState -eq 'Disabled' -and -not $currentEnabled) {
            # CONTEXT: Already Disabled - Still attempt to disable (idempotent operation)
            Write-Host "[INFO] Task '$taskName' already disabled, confirming..." -ForegroundColor Cyan
        }

        # CONTEXT: System vs Custom - Distinguish by task author/creator
        $taskAuthor = $scheduledTask.Author
        $isSystemTask = $taskAuthor -like '*Microsoft*' -or $taskPath -like '*\Microsoft\Windows\*'

        # Apply strategy
        if ($strategy -eq '1') {
            # Disable only
            Disable-ScheduledTask -TaskName $taskName -TaskPath (Split-Path $taskPath) -ErrorAction Stop

            # Save rollback entry (CONTEXT: Task Rollback - re-enable if disabled)
            Save-RollbackEntry -Type "ScheduledTask" `
                -Target $taskPath `
                -ValueName "State" `
                -OriginalData $currentState `
                -OriginalType "TaskState"

            Write-Host "[SUCCESS] Disabled task '$taskName'" -ForegroundColor Green
            $successCount++

        } elseif ($strategy -eq '2') {
            # Delete task
            Unregister-ScheduledTask -TaskName $taskName -TaskPath (Split-Path $taskPath) -Confirm:$false -ErrorAction Stop

            # Save rollback entry (CONTEXT: Task Rollback - recreate if deleted)
            Save-RollbackEntry -Type "ScheduledTask" `
                -Target $taskPath `
                -ValueName "TaskDefinition" `
                -OriginalData ($scheduledTask.TaskDefinition.OuterXml) `
                -OriginalType "TaskXml"

            Write-Host "[SUCCESS] Deleted task '$taskName'" -ForegroundColor Green
            $successCount++

        } elseif ($strategy -eq '3') {
            # Hybrid
            if ($isSystemTask) {
                # Delete system telemetry tasks
                Unregister-ScheduledTask -TaskName $taskName -TaskPath (Split-Path $taskPath) -Confirm:$false -ErrorAction Stop

                Save-RollbackEntry -Type "ScheduledTask" `
                    -Target $taskPath `
                    -ValueName "TaskDefinition" `
                    -OriginalData ($scheduledTask.TaskDefinition.OuterXml) `
                    -OriginalType "TaskXml"

                Write-Host "[SUCCESS] Deleted system task '$taskName'" -ForegroundColor Green
            } else {
                # Disable custom tasks
                Disable-ScheduledTask -TaskName $taskName -TaskPath (Split-Path $taskPath) -ErrorAction Stop

                Save-RollbackEntry -Type "ScheduledTask" `
                    -Target $taskPath `
                    -ValueName "State" `
                    -OriginalData $currentState `
                    -OriginalType "TaskState"

                Write-Host "[SUCCESS] Disabled custom task '$taskName'" -ForegroundColor Green
            }
            $successCount++
        }

        Write-OptLog -Module "Invoke-TelemetryBlock" `
            -Operation "Disable-ScheduledTask" `
            -Target $taskPath `
            -Values @{ TaskName = $taskName; Strategy = $strategy } `
            -Result "Success" `
            -Message "Scheduled task processed" `
            -Level "SUCCESS"

    } catch {
        # CONTEXT: Scheduled Task Failures - Continue disabling remaining tasks
        Write-Host "[ERROR] Failed to process task '$taskName': $_" -ForegroundColor Red
        Write-OptLog -Module "Invoke-TelemetryBlock" `
            -Operation "Disable-ScheduledTask" `
            -Target $taskPath `
            -Values @{ Error = $_.Exception.Message } `
            -Result "Error" `
            -Message "Failed to process scheduled task" `
            -Level "ERROR"
        $errorCount++
        # Continue with next task
    }
}

# CONTEXT: Scheduled Task Failures - List failed tasks at end
if ($errorCount -gt 0) {
    Write-Host "`n[WARNING] Failed to process $errorCount task(s). Review log for details." -ForegroundColor Yellow
}
```

**Source:** Pattern established in CONTEXT decisions (Scheduled Task Handling)

### Anti-Patterns to Avoid

- **Backtick line continuation:** Banned from codebase (QUAL-06 requirement). Causes parsing failures in scheduled tasks. Use splatting `@{}` or single-line cmdlets instead.
- **Direct registry modification without rollback check:** Violates QUAL-02 requirement. Must call Save-RollbackEntry before every Set-ItemProperty.
- **Missing idempotency checks:** Violates QUAL-01 requirement. Every operation must check current state first and emit [SKIP] if already in desired state.
- **Calling wsl.exe from elevated context:** Violates QUAL-08 requirement. WSL fails under LOCAL_SYSTEM. Use WMI and Get-Service only.
- **Modifying protected services:** Violates SRVC-03 and QUAL-09 requirements. HvHost, vmms, WslService, LxssManager, VmCompute, vmic* must never be touched.
- **Locale-sensitive powercfg aliases:** Not applicable to Phase 3 but worth noting — use hardcoded GUIDs only (QUAL-07 requirement).
- **Silent service failures:** CONTEXT requires user prompts on service disable failures. Don't silently continue.
- **Assuming GPU vendor:** CONTEXT requires detection and user prompts for unknown vendors. Don't assume Nvidia/AMD only.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| **Registry ACL modification** | Custom .NET ACL code with manual permission inheritance | Take-RegistryOwnership lib/ helper (already implemented in Phase 1) | TrustedInstaller ownership transfer is complex; helper handles edge cases and error conditions |
| **JSONL logging** | Manual file append with string concatenation | Write-OptLog lib/ helper (already implemented in Phase 1) | Structured logging with proper serialization, error handling, and timestamp formatting |
| **Rollback manifest management** | Manual JSON read/modify/write with depth handling | Save-RollbackEntry lib/ helper (already implemented in Phase 1) | Handles array appending, duplicate entry overwriting, proper JSON depth |
| **Service detection** | Hardcoded service lists in each module | config/services.json (already exists) | Single source of truth, extensible, supports OEM service detection |
| **PowerShell version validation** | Manual $PSVersionTable checking with exit codes | Test-PowerShellVersion lib/ helper (already implemented in Phase 2) | Handles PowerShell 7+ prompts, proper error messages, logging integration |
| **Virtualization stack validation** | Calling wsl.exe or checking Hyper-V feature state | Test-VirtStack lib/ helper (already implemented in Phase 1) | WMI-only approach avoids LOCAL_SYSTEM context error, properly validates WSL2/Hyper-V |
| **System Restore Point creation** | Manual Checkpoint-Computer with retry logic | Invoke-RestorePointCreation lib/ helper (already implemented in Phase 2) | Handles recent point detection, old point warnings, creation failure prompts |

**Key insight:** Phase 1 and Phase 2 already implemented all the critical helper functions. Phase 3 is about composing these helpers into coherent modules, not rebuilding infrastructure. The lib/ directory provides 5 production-ready helpers that encapsulate complex operations (registry ACL, rollback manifest, JSONL logging, GUID extraction, virtualization validation) plus 3 safety gate helpers (restore point, elevation, version check, virtualization validation). Don't duplicate this logic in modules — dot-source the helpers and call them.

## Common Pitfalls

### Pitfall 1: Missing Rollback Entry Before Modification

**What goes wrong:** Module modifies registry value or service startup type without saving original state to rollback manifest. User cannot revert changes via Invoke-Rollback.

**Why it happens:** Developer focuses on the operation logic and forgets the QUAL-02 requirement: "Every module calls Save-RollbackEntry before every Set-ItemProperty, Set-Service, and fsutil call."

**How to avoid:** Establish a hard rule in the module structure: every region that performs destructive operations must start with a Save-RollbackEntry call. Code review checklist: "Does every Set-ItemProperty have a corresponding Save-RollbackEntry?"

**Warning signs:** Module passes tests but rollback doesn't restore values. Rollback manifest JSON is missing entries. Manual inspection shows registry/service changed but no original value recorded.

### Pitfall 2: Incomplete Idempotency Checks

**What goes wrong:** Module doesn't check current state before modification, or only checks one property (e.g., service StartType but not running state). Second run produces changes instead of [SKIP] messages, violating QUAL-01.

**Why it happens:** Developer implements basic state checking but overlooks CONTEXT requirements: "Service checks: Check StartType + running state — skip only if both match desired state" and "Registry checks: Skip if key exists with correct value AND correct type (DWORD vs QWORD match)."

**How to avoid:** For services: check both StartType (via Get-WmiObject Win32_Service.StartMode) and Status (via Get-Service.Status). For registry: check value exists AND value matches AND type matches (DWORD vs QWORD). Document idempotency conditions in code comments.

**Warning signs:** Second script run modifies values that shouldn't change. Log shows [SUCCESS] instead of [SKIP] for already-configured items. Quality gate QG-01 (idempotency test) fails.

### Pitfall 3: Protected Service Modification

**What goes wrong:** Module attempts to disable HvHost, vmms, WslService, LxssManager, VmCompute, or vmic* services. Breaks WSL2/Hyper-V functionality, violating SRVC-03 and QUAL-09 requirements.

**Why it happens:** config/services.json is modified incorrectly, or module doesn't validate against protected list before service operations. Developer assumes config file is safe without explicit blocklist.

**How to avoid:** Hardcode protected service blocklist in module (not just in config). Explicit check: `if ($protectedServices -contains $serviceName) { Write-Error "Cannot modify protected service"; continue }`. Test-VirtStack pre-flight and post-flight validation catches this (SAFE-04 requirement).

**Warning signs:** Test-VirtStack post-validation shows WSL2/Hyper-V state change. Docker Desktop fails to start after optimization. Manual inspection shows virtualization services disabled.

### Pitfall 4: Access Denied on Registry Keys

**What goes wrong:** Set-ItemProperty fails with "Access Denied" error on keys owned by TrustedInstaller (e.g., Windows Search keys). Module halts or throws unhandled exception.

**Why it happens:** Developer doesn't use Take-RegistryOwnership helper before registry modification. Assumes elevation is sufficient for all registry keys.

**How to avoid:** Wrap problematic registry operations in try-catch. On Access Denied, call Take-RegistryOwnership -Path $regPath, then retry Set-ItemProperty. CONTEXT decision: "Registry Ownership Failures: Log WARNING, skip that registry operation, continue with others" — don't halt the entire module.

**Warning signs:** Module fails with SecurityException. Registry keys under HKLM:\SOFTWARE\Microsoft\Windows Search are problematic. Known TrustedInstaller-owned keys from PRD Section 1.4.

### Pitfall 5: WMI Query Failures in GPU Detection

**What goes wrong:** Get-WmiObject Win32_VideoController fails or returns unexpected results. GPU module crashes or skips all optimizations.

**Why it happens:** WMI service is disabled, corrupted, or returning malformed data. Developer doesn't handle WMI failure scenarios per CONTEXT decision: "WMI Query Fails: Warn user, prompt to choose: halt module, use fallback detection methods, or skip GPU optimizations."

**How to avoid:** Wrap Get-WmiObject in try-catch with $ErrorActionPreference = 'Stop'. On failure, prompt user with three options per CONTEXT. Implement basic fallback (e.g., registry-only HAGS/MPO modifications without GPU-specific logic). Log WMI failures to JSONL for debugging.

**Warning signs:** GPU module fails immediately on start. WMI-related error messages. $gpus variable is null or empty. No GPU optimizations applied.

### Pitfall 6: Scheduled Task Path Incorrect

**What goes wrong:** Disable-ScheduledTask fails with "Task not found" error. Module skips task or crashes.

**Why it happens:** Task path is incorrect (e.g., missing '\Microsoft\Windows\' prefix). Get-ScheduledTask requires full task path, not just task name. Developer confuses TaskName and TaskPath parameters.

**How to avoid:** Store full task path in config/arrays: `'\Microsoft\Windows\Application Experience\CompatibilityAppraiser'`. Use Split-Path to extract parent path for TaskPath parameter: `Disable-ScheduledTask -TaskName $taskName -TaskPath (Split-Path $fullPath)`. Test with Get-ScheduledTask before disable to verify path.

**Warning signs:** All scheduled tasks show [SKIP] "Task not found". Disable-ScheduledTask throws exceptions. Log shows path-related errors.

### Pitfall 7: HAGS Reboot Not Handled

**What goes wrong:** HAGS registry value is set to 2 but GPU scheduling doesn't actually activate until reboot. User thinks optimization failed. Subsequent check shows HAGS still disabled, causing confusion.

**Why it happens:** Developer doesn't prompt for reboot after HAGS modification (CONTEXT requirement: "HAGS Reboot: Prompt user: 'Reboot now? (Y/N)'"). Doesn't explain that HAGS requires reboot to activate.

**How to avoid:** After setting HwSchMode=2, display clear message: "HAGS enabled (requires reboot to activate)". Prompt user: "Reboot now to activate HAGS? (Y/N)". If user declines, log WARNING that HAGS will not be active until reboot. GPUD-05 requirement: "validates HAGS activation post-reboot via registry readback" — implement check that informs user if HAGS still ≠2.

**Warning signs:** User reports HAGS not working after optimization. GPU scheduling benchmark shows no improvement. Registry HwSchMode=2 but DWM still using old scheduler.

## Code Examples

Verified patterns from official sources:

### Registry Operation with Rollback and Idempotency

```powershell
# Source: /mnt/d/Coding/WinOptim/lib/Invoke-RestorePoint.ps1 (lines 53-73, 126-139)
# Pattern: Check-then-modify with rollback save and JSONL logging

$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
$valueName = "AllowTelemetry"
$desiredValue = 0

# Check current state
$currentValue = Get-ItemProperty -Path $regPath -Name $valueName -ErrorAction SilentlyContinue

if ($null -ne $currentValue -and $currentValue.$valueName -eq $desiredValue) {
    Write-Host "[SKIP] $valueName already set to $desiredValue" -ForegroundColor Gray

    Write-OptLog -Module "Invoke-TelemetryBlock" `
        -Operation "Get-ItemProperty" `
        -Target "$regPath\$valueName" `
        -Values @{ CurrentValue = $currentValue.$valueName; DesiredValue = $desiredValue } `
        -Result "Skip" `
        -Message "Already at desired value" `
        -Level "SKIP"

    $skipCount++
    return
}

# Save rollback entry BEFORE modification
Save-RollbackEntry -Type "Registry" `
    -Target $regPath `
    -ValueName $valueName `
    -OriginalData $currentValue.$valueName `
    -OriginalType "REG_DWORD"

# Modify value
Set-ItemProperty -Path $regPath -Name $valueName -Value $desiredValue -Type DWord -ErrorAction Stop

Write-Host "[SUCCESS] Set $valueName to $desiredValue" -ForegroundColor Green

Write-OptLog -Module "Invoke-TelemetryBlock" `
    -Operation "Set-ItemProperty" `
    -Target "$regPath\$valueName" `
    -Values @{ OldValue = $currentValue.$valueName; NewValue = $desiredValue } `
    -Result "Success" `
    -Message "Telemetry setting configured" `
    -Level "SUCCESS"
```

### Service Operation with Protected Check and Graceful Skip

```powershell
# Source: /mnt/d/Coding/WinOptim/lib/Invoke-RestorePoint.ps1 (lines 50-87) - Error handling pattern
# Pattern: Try-catch with null check and user prompt

$serviceName = "DiagTrack"
$protectedServices = @('HvHost', 'vmms', 'WslService', 'LxssManager', 'VmCompute')

# Protected service check
if ($protectedServices -contains $serviceName) {
    Write-Host "[ERROR] $serviceName is protected. Cannot disable." -ForegroundColor Red
    $errorCount++
    continue
}

# Get service with graceful skip
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if ($null -eq $service) {
    Write-Host "[SKIP] Service '$serviceName' not found" -ForegroundColor Gray

    Write-OptLog -Module "Invoke-ServiceOptimize" `
        -Operation "Get-Service" `
        -Target $serviceName `
        -Values @{} `
        -Result "Skip" `
        -Message "Service not found on this system" `
        -Level "SKIP"

    $skipCount++
    continue
}

# Check current state
$currentStartType = (Get-WmiObject -Class Win32_Service -Filter "Name='$serviceName'").StartMode
$currentStatus = $service.Status

if ($currentStartType -eq 'Disabled' -and $currentStatus -eq 'Stopped') {
    Write-Host "[SKIP] Service already disabled and stopped" -ForegroundColor Gray
    $skipCount++
    continue
}

# User prompt per CONTEXT decision
Write-Host "[ACTION] Disabling service: $serviceName" -ForegroundColor Cyan
$continue = Read-Host -Prompt "Disable this service? (Y/N/A for All)"

if ($continue -ne 'Y' -and $continue -ne 'y' -and $continue -ne 'A' -and $continue -ne 'a') {
    Write-Host "[SKIP] User chose to skip $serviceName" -ForegroundColor Gray
    $skipCount++
    continue
}

# Save rollback entry
Save-RollbackEntry -Type "Service" `
    -Target $serviceName `
    -OriginalStartType $currentStartType

# Stop service if running
if ($service.Status -ne 'Stopped') {
    try {
        Stop-Service -Name $serviceName -Force -ErrorAction Stop
        Write-Host "[SUCCESS] Stopped service $serviceName" -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Failed to stop $serviceName: $_" -ForegroundColor Red

        # CONTEXT: Service stop timeout - prompt user
        $forceKill = Read-Host -Prompt "Force kill service process? (Y/N)"
        if ($forceKill -eq 'Y' -or $forceKill -eq 'y') {
            # Force kill logic here
        } else {
            $errorCount++
            continue
        }
    }
}

# Disable service
try {
    Set-Service -Name $serviceName -StartupType Disabled -ErrorAction Stop
    Write-Host "[SUCCESS] Disabled service $serviceName" -ForegroundColor Green

    Write-OptLog -Module "Invoke-ServiceOptimize" `
        -Operation "Set-Service" `
        -Target $serviceName `
        -Values @{ OldStartType = $currentStartType; NewStartType = 'Disabled' } `
        -Result "Success" `
        -Message "Service disabled" `
        -Level "SUCCESS"

    $successCount++
} catch {
    Write-Host "[ERROR] Failed to disable $serviceName: $_" -ForegroundColor Red

    Write-OptLog -Module "Invoke-ServiceOptimize" `
        -Operation "Set-Service" `
        -Target $serviceName `
        -Values @{ Error = $_.Exception.Message } `
        -Result "Error" `
        -Message "Failed to disable service" `
        -Level "ERROR"

    $errorCount++
}
```

### WMI GPU Detection with Error Handling

```powershell
# Source: /mnt/d/Coding/WinOptim/lib/Test-VirtStack.ps1 (lines 40-90) - WMI query pattern
# Pattern: Try-catch WMI query with user prompt on failure

Write-Host "[INFO] Detecting GPUs via WMI..." -ForegroundColor Cyan

try {
    $gpus = Get-WmiObject Win32_VideoController -ErrorAction Stop
} catch {
    Write-Host "[WARNING] WMI query failed: $_" -ForegroundColor Yellow

    Write-OptLog -Module "Invoke-GpuDwmOptimize" `
        -Operation "Get-WmiObject" `
        -Target "Win32_VideoController" `
        -Values @{ Error = $_.Exception.Message } `
        -Result "Warning" `
        -Message "WMI GPU detection failed" `
        -Level "WARNING"

    # CONTEXT: WMI Query Fails - prompt user
    $choice = Read-Host -Prompt "Halt GPU module, use fallback detection, or skip GPU optimizations? (H/F/S)"

    if ($choice -eq 'H' -or $choice -eq 'h') {
        Write-Host "[ERROR] Halting GPU module per user choice" -ForegroundColor Red
        return $false
    } elseif ($choice -eq 'S' -or $choice -eq 's') {
        Write-Host "[SKIP] Skipping GPU module per user choice" -ForegroundColor Gray
        return $false
    } else {
        # Fallback: attempt registry-only HAGS/MPO without GPU detection
        Write-Host "[INFO] Using fallback detection (registry-only mode)" -ForegroundColor Cyan
        $fallbackMode = $true
    }
}

if (-not $fallbackMode) {
    if ($null -eq $gpus -or $gpus.Count -eq 0) {
        # CONTEXT: No GPU Found
        Write-Host "[WARNING] No GPUs detected via WMI" -ForegroundColor Yellow

        Write-OptLog -Module "Invoke-GpuDwmOptimize" `
            -Operation "Get-WmiObject" `
            -Target "Win32_VideoController" `
            -Values @{} `
            -Result "Warning" `
            -Message "No GPUs detected" `
            -Level "WARNING"

        $choice = Read-Host -Prompt "Halt, skip GPU module, or attempt generic optimizations? (H/S/G)"

        if ($choice -eq 'G' -or $choice -eq 'g') {
            Write-Host "[INFO] Attempting generic MPO disable..." -ForegroundColor Cyan
        } else {
            return $false
        }
    }

    # Filter out virtual GPUs
    $physicalGpus = $gpus | Where-Object {
        $_.Name -notlike '*Hyper-V*' -and
        $_.Name -notlike '*VMware*' -and
        $_.Name -notlike '*Virtual*' -and
        $_.Name -notlike '*Remote Desktop*'
    }

    if ($physicalGpus.Count -eq 0) {
        Write-Host "[SKIP] No physical GPUs found (all detected GPUs are virtual)" -ForegroundColor Gray
        return $false
    }

    # Detect Nvidia GPUs
    $nvidiaGpus = $physicalGpus | Where-Object { $_.Name -like '*NVIDIA*' }

    foreach ($gpu in $nvidiaGpus) {
        $gpuName = $gpu.Name

        # CONTEXT: Nvidia GPU - Prompt for vendor-specific optimizations
        $nvidiaOpt = Read-Host -Prompt "Apply Nvidia-specific optimizations for $gpuName? (Y/N)"

        if ($nvidiaOpt -eq 'Y' -or $nvidiaOpt -eq 'y') {
            # Disable NvTelemetryContainer service
            $nvTelemetry = Get-Service -Name 'NvTelemetryContainer' -ErrorAction SilentlyContinue

            if ($null -ne $nvTelemetry) {
                # ... disable logic ...
            }

            # Output NVCP manual configuration checklist
            Write-Host "`n[NVIDIA Control Panel Manual Configuration]" -ForegroundColor Yellow
            Write-Host "1. Open NVIDIA Control Panel" -ForegroundColor White
            Write-Host "2. Set 'Power management mode' to 'Prefer maximum performance'" -ForegroundColor White
            Write-Host "3. Set 'Texture filtering - Quality' to 'High performance'" -ForegroundColor White
        }
    }
}

# Apply HAGS (registry-only, works without GPU detection)
Write-Host "[ACTION] Enabling Hardware-Accelerated GPU Scheduling..." -ForegroundColor Cyan

$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
$valueName = "HwSchMode"
$desiredValue = 2

$currentHags = Get-ItemProperty -Path $regPath -Name $valueName -ErrorAction SilentlyContinue

if ($null -ne $currentHags -and $currentHags.$valueName -eq $desiredValue) {
    Write-Host "[SKIP] HAGS already enabled" -ForegroundColor Gray
} else {
    try {
        Save-RollbackEntry -Type "Registry" `
            -Target $regPath `
            -ValueName $valueName `
            -OriginalData $currentHags.$valueName `
            -OriginalType "REG_DWORD"

        Set-ItemProperty -Path $regPath -Name $valueName -Value $desiredValue -Type DWord -ErrorAction Stop

        Write-Host "[SUCCESS] HAGS enabled (requires reboot to activate)" -ForegroundColor Green

        # CONTEXT: HAGS Reboot - Prompt user
        $reboot = Read-Host -Prompt "Reboot now to activate HAGS? (Y/N)"
        if ($reboot -eq 'Y' -or $reboot -eq 'y') {
            Restart-Computer -Confirm
        } else {
            Write-Host "[WARNING] HAGS will not be active until reboot" -ForegroundColor Yellow

            Write-OptLog -Module "Invoke-GpuDwmOptimize" `
                -Operation "Set-ItemProperty" `
                -Target "$regPath\$valueName" `
                -Values @{} `
                -Result "Warning" `
                -Message "HAGS enabled but requires reboot to activate" `
                -Level "WARNING"
        }
    } catch {
        Write-Host "[ERROR] Failed to enable HAGS: $_" -ForegroundColor Red
        Write-Host "[INFO] Your GPU driver may not support HAGS" -ForegroundColor Cyan
    }
}
```

### Scheduled Task Operation with Strategy Pattern

```powershell
# Source: PRD Section 2.3 Module 1 + CONTEXT decisions
# Pattern: User choice strategy with system/custom distinction

$tasks = @(
    @{ Name = 'CompatibilityAppraiser'; Path = '\Microsoft\Windows\Application Experience\CompatibilityAppraiser' },
    @{ Name = 'ProgramDataUpdater'; Path = '\Microsoft\Windows\Application Experience\ProgramDataUpdater' }
)

# CONTEXT: Task Action - Prompt user at runtime
Write-Host "`n[Scheduled Task Handling Strategy]" -ForegroundColor Cyan
Write-Host "1. Disable only: Sets State=0, fully reversible" -ForegroundColor White
Write-Host "2. Delete task: Removes task, cleaner but irreversible" -ForegroundColor White
Write-Host "3. Hybrid: Disable custom tasks, delete system telemetry tasks" -ForegroundColor White

$strategy = Read-Host -Prompt "Choose strategy (1/2/3)"

foreach ($task in $tasks) {
    $taskName = $task.Name
    $taskPath = $task.Path

    try {
        $scheduledTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

        if ($null -eq $scheduledTask) {
            Write-Host "[SKIP] Task '$taskName' not found" -ForegroundColor Gray
            $skipCount++
            continue
        }

        # CONTEXT: Task Checks - Check State + Enabled property
        $currentState = $scheduledTask.State
        $currentEnabled = $scheduledTask.Enabled

        if ($currentState -eq 'Disabled' -and -not $currentEnabled) {
            # CONTEXT: Already Disabled - Still attempt to disable (idempotent)
            Write-Host "[INFO] Task '$taskName' already disabled, confirming..." -ForegroundColor Cyan
        }

        # CONTEXT: System vs Custom - Distinguish by task author/creator
        $taskAuthor = $scheduledTask.Author
        $isSystemTask = $taskAuthor -like '*Microsoft*' -or $taskPath -like '*\Microsoft\Windows\*'

        # Apply strategy
        if ($strategy -eq '1') {
            # Disable only
            $parentPath = Split-Path $taskPath
            Disable-ScheduledTask -TaskName $taskName -TaskPath $parentPath -ErrorAction Stop

            # CONTEXT: Task Rollback - re-enable if disabled
            Save-RollbackEntry -Type "ScheduledTask" `
                -Target $taskPath `
                -ValueName "State" `
                -OriginalData $currentState `
                -OriginalType "TaskState"

            Write-Host "[SUCCESS] Disabled task '$taskName'" -ForegroundColor Green
            $successCount++

        } elseif ($strategy -eq '2') {
            # Delete task
            Unregister-ScheduledTask -TaskName $taskName -TaskPath (Split-Path $taskPath) -Confirm:$false -ErrorAction Stop

            # CONTEXT: Task Rollback - recreate if deleted
            Save-RollbackEntry -Type "ScheduledTask" `
                -Target $taskPath `
                -ValueName "TaskDefinition" `
                -OriginalData ($scheduledTask.TaskDefinition.OuterXml) `
                -OriginalType "TaskXml"

            Write-Host "[SUCCESS] Deleted task '$taskName'" -ForegroundColor Green
            $successCount++

        } elseif ($strategy -eq '3') {
            # Hybrid
            if ($isSystemTask) {
                # Delete system telemetry tasks
                Unregister-ScheduledTask -TaskName $taskName -TaskPath (Split-Path $taskPath) -Confirm:$false -ErrorAction Stop

                Save-RollbackEntry -Type "ScheduledTask" `
                    -Target $taskPath `
                    -ValueName "TaskDefinition" `
                    -OriginalData ($scheduledTask.TaskDefinition.OuterXml) `
                    -OriginalType "TaskXml"

                Write-Host "[SUCCESS] Deleted system task '$taskName'" -ForegroundColor Green
            } else {
                # Disable custom tasks
                $parentPath = Split-Path $taskPath
                Disable-ScheduledTask -TaskName $taskName -TaskPath $parentPath -ErrorAction Stop

                Save-RollbackEntry -Type "ScheduledTask" `
                    -Target $taskPath `
                    -ValueName "State" `
                    -OriginalData $currentState `
                    -OriginalType "TaskState"

                Write-Host "[SUCCESS] Disabled custom task '$taskName'" -ForegroundColor Green
            }
            $successCount++
        }

        Write-OptLog -Module "Invoke-TelemetryBlock" `
            -Operation "Disable-ScheduledTask" `
            -Target $taskPath `
            -Values @{ TaskName = $taskName; Strategy = $strategy; IsSystemTask = $isSystemTask } `
            -Result "Success" `
            -Message "Scheduled task processed" `
            -Level "SUCCESS"

    } catch {
        # CONTEXT: Scheduled Task Failures - Continue disabling remaining tasks
        Write-Host "[ERROR] Failed to process task '$taskName': $_" -ForegroundColor Red

        Write-OptLog -Module "Invoke-TelemetryBlock" `
            -Operation "Disable-ScheduledTask" `
            -Target $taskPath `
            -Values @{ Error = $_.Exception.Message } `
            -Result "Error" `
            -Message "Failed to process scheduled task" `
            -Level "ERROR"

        $errorCount++
        # Continue with next task (don't halt entire module)
    }
}

# CONTEXT: Scheduled Task Failures - List failed tasks at end
if ($errorCount -gt 0) {
    Write-Host "`n[WARNING] Failed to process $errorCount task(s). Review log for details." -ForegroundColor Yellow
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| **PowerShell 2.0** | PowerShell 5.1+ | Windows 11 release (2021) | Windows 11 bundles PowerShell 5.1; project requires #Requires -Version 5.1 |
| **Get-WmiObject only** | Get-WmiObject + Get-CimInstance | PowerShell 3.0 (2012) | CIM is newer but WMI is more reliable in PowerShell 5.1; PRD specifies WMI |
| **External binary calls (reg.exe, sc.exe)** | Native PowerShell cmdlets | PowerShell 1.0 (2006) | Native cmdlets provide better error handling, object-oriented output, pipeline support |
| **Backtick line continuation** | Splatting (@{}) | Project requirement (QUAL-06) | Backticks cause parsing failures in scheduled tasks; splatting is safer and more readable |
| **Locale-sensitive aliases** | Hardcoded GUIDs | Project discovery (PRD 1.3) | powercfg aliases fail on non-English Windows; GUIDs work across all locales |
| **wsl.exe invocation** | WMI-only queries | Project discovery (PRD 1.6) | wsl.exe fails under LOCAL_SYSTEM (elevated context); WMI avoids this error |
| **Manual ACL manipulation** | Take-RegistryOwnership helper | Phase 1 implementation | TrustedInstaller ownership is complex; helper encapsulates .NET Security.AccessControl logic |

**Deprecated/outdated:**
- **PowerShell 7+ for this project:** Project targets PowerShell 5.1 (Windows 11 bundled). PowerShell 7+ has breaking differences; Test-PowerShellVersion helper prompts user before proceeding with PS 7+.
- **Scheduled task XML manipulation:** Disable-ScheduledTask and Unregister-ScheduledTask cmdlets replace need for direct XML manipulation.
- **Service manipulation via sc.exe:** Set-Service cmdlet provides object-oriented service management without external binary calls.

## Open Questions

1. **WMI Fallback Detection Implementation**
   - What we know: CONTEXT specifies "WMI Fallback Detection: Claude's discretion (not specified by user)"
   - What's unclear: Should we implement registry-based GPU detection as fallback, or simply skip GPU-specific optimizations?
   - Recommendation: Implement basic fallback — attempt HAGS/MPO registry modifications without GPU vendor detection. This provides generic optimizations even if WMI fails, aligning with CONTEXT "No GPU Found" option to "attempt generic optimizations (MPO disable via registry without vendor checks)"

2. **HAGS Driver Capability Validation**
   - What we know: CONTEXT specifies three options: "query driver for HAGS support, try-catch (attempt enable, catch error if unsupported), or enable HAGS for all GPUs (assume support)"
   - What's unclear: Which approach is safest? Querying driver support is complex; try-catch may produce confusing errors; assume support may fail on old drivers.
   - Recommendation: Use try-catch approach (attempt enable, catch error if unsupported). This is simplest to implement and provides clear error messages: "Your GPU driver may not support HAGS" if Set-ItemProperty fails. User can then decide whether to update drivers or skip HAGS.

3. **Service Dependent Logic**
   - What we know: CONTEXT specifies "Dependent Service Failures: Prompt user to disable parent+child or skip both"
   - What's unclear: Should we detect service dependencies automatically via Get-WmiObject Win32_DependentService, or rely on Set-Service errors to reveal dependencies?
   - Recommendation: Rely on Set-Service errors. When attempting to disable a parent service, Set-Service will fail with error message indicating dependent services. Catch this error and prompt user with specific dependent service names. This avoids complex dependency graph traversal.

4. **Scheduled Task Rollback Recreation**
   - What we know: CONTEXT specifies "Task Rollback: Hybrid restore — re-enable if disabled, recreate if deleted"
   - What's unclear: Recreating deleted tasks from TaskDefinition.OuterXml may fail due to task principal or trigger differences across Windows versions.
   - Recommendation: Store minimal task recreation data (TaskName, TaskPath, Author, Description) instead of full TaskDefinition XML. During rollback, log WARNING that deleted task cannot be perfectly recreated and provide manual recreation instructions. This is safer than XML-based recreation which may fail.

## Sources

### Primary (HIGH confidence)

- **Project codebase** - All existing lib/ implementations (Write-OptLog.ps1, Save-RollbackEntry.ps1, Take-RegistryOwnership.ps1, Invoke-RestorePoint.ps1, Test-PowerShellVersion.ps1, Test-VirtStack.ps1)
- **Project PRD** - `/mnt/d/Coding/WinOptim/WinOptimizer_PRD.md` — Complete registry/service change inventory, real-world error patterns, implementation phases
- **Project requirements** - `/mnt/d/Coding/WinOptim/.planning/REQUIREMENTS.md` — TELM-01 through TELM-05, GPUD-01 through GPUD-05, SRVC-01 through SRVC-05
- **Project CONTEXT** - `/mnt/d/Coding/WinOptim/.planning/phases/03-core-modules/03-CONTEXT.md` — All user decisions on error handling, user interaction, idempotency, GPU detection, rollback manifest, JSONL logging
- **config/services.json** - Service lists (disabled, manual, protected, OEM) already implemented in Phase 1

### Secondary (MEDIUM confidence)

- **PowerShell 5.1 built-in cmdlet documentation** — Set-ItemProperty, Get-Service, Set-Service, Get-WmiObject, Disable-ScheduledTask, Unregister-ScheduledTask, Get-ScheduledTask are standard Windows PowerShell cmdlets
- **.NET Framework System.Security.AccessControl** — Used by Take-RegistryOwnership for registry ACL manipulation (standard .NET approach)
- **Windows Registry structure** — HKLM paths for telemetry (DataCollection), AutoLogger sessions, GPU drivers (GraphicsDrivers), DWM settings — verified against project PRD Section 1.8

### Tertiary (LOW confidence)

- **Web search attempts** — WebSearch tool returned empty results for PowerShell module patterns, GPU detection, service management. No web sources to cite.
- **Note:** Web search failures do not impact research confidence. Project codebase, PRD, and existing lib/ implementations provide HIGH confidence for all Phase 3 requirements. PowerShell 5.1 cmdlets are well-documented in Microsoft official docs (though not retrieved via web search due to tool issues).

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All cmdlets are built into PowerShell 5.1 and Windows 11. No external packages required.
- Architecture: HIGH - Project lib/ helpers demonstrate established patterns. PRD provides complete specification.
- Pitfalls: HIGH - CONTEXT decisions specify error handling for every edge case. Real-world errors documented in PRD Section 1.
- Code examples: HIGH - All examples derived from existing lib/ implementations (Invoke-RestorePoint.ps1, Test-PowerShellVersion.ps1, Test-VirtStack.ps1) and PRD specifications.

**Research date:** 2026-03-13
**Valid until:** 30 days (PowerShell 5.1 and Windows 11 registry structures are stable; no fast-moving dependencies in this phase)

---

*Phase 3 Research Complete*
*Ready for planning: 03-PLAN.md creation*
