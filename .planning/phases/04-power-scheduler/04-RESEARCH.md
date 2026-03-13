# Phase 4: Power & Scheduler - Research

**Researched:** 2026-03-14
**Domain:** Windows Power Management, CPU Scheduler Optimization, Modern Standby (S0) Detection, Scheduled Task Creation
**Confidence:** HIGH

## Summary

Phase 4 implements two optimization modules: Power Plan configuration (Modern Standby detection/override, Ultimate Performance plan creation, PCIe/USB power settings, OEM countermeasures) and CPU Scheduler optimization (Win32PrioritySeparation tuning, CPU core parking disablement, processor state configuration). This phase builds directly on Phase 1 library helpers (Write-OptLog, Save-RollbackEntry, Get-ActivePlanGuid) and Phase 2 safety gates.

The research confirms that Windows 11 Modern Standby (S0) low power idle model is the root cause of Ultimate Performance plan suppression. The `PlatformAoAcOverride` registry key is the documented method to force legacy S3 sleep behavior. CPU scheduler tuning via Win32PrioritySeparation=38 provides variable quanta, short intervals, and 3x foreground boost. All power plan operations must use hardcoded GUIDs for locale safety (no powercfg aliases). OEM power services require scheduled task countermeasures to prevent plan reassertion.

**Primary recommendation:** Implement both modules following established Phase 1-3 patterns—strict idempotency checks, rollback-before-modify ordering, comprehensive JSONL logging, and user interaction prompts per CONTEXT.md decisions. Use `powercfg` CLI tool with hardcoded GUIDs for all power plan operations, and PowerShell ScheduledTasks module for OEM countermeasures.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Modern Standby Handling (S0):**
- Detection → Action: When Modern Standby (S0) is detected via `PlatformAoAcOverride` registry key, **prompt user first** before applying fix. Explain the S0 issue and ask whether to apply `PlatformAoAcOverride = 0` or skip.
- Reboot timing: After applying S0 fix, **prompt user** for reboot timing ("Reboot now?" or "Reboot later?")
- S0 not present: **Skip silently** - no S0-related messages if Modern Standby is not detected (legacy S3 or desktop systems)
- Rollback behavior: **Restore to default** - remove the `PlatformAoAcOverride` key entirely on rollback, returning to system default behavior

**Power Plan Strategy:**
- Plan creation: **Duplicate and rename** - duplicate hidden Ultimate Performance plan, apply custom name to avoid OEM GUID collisions
- Naming scheme: Use **"WinOptimizer Ultimate"** as the plan name (clear, branded, indicates source and purpose)
- Duplicate handling: If plan with target name exists from previous run, **prompt user** with options: Reuse existing / Delete and recreate / Cancel
- PCIe/USB settings: Configure **both together** - PCIe Link State Power Management (Off) and USB Selective Suspend (Disabled) as part of power plan module, no separate prompts
- Activation timing: **Activate immediately** after creation/duplication
- Ultimate Performance missing: If Ultimate Performance source GUID doesn't exist (some editions hide it), **fall back to High Performance** plan with warning logged
- Settings verification: **Verify and report** - read back registry values after activation, confirm success or show WARNING if mismatch
- AC vs Battery: Apply processor state settings (100% min/max) to **AC power only** - preserve battery life on laptops

**OEM Countermeasures:**
- Detection method: **Check all known** - iterate through all known OEM services in config (ASUS Armory Crate, Lenovo Vantage, Dell Command, HP Omen), detect which are present
- Service handling: When OEM power service detected, **prompt to disable** with information about what changes if user agrees
- Scheduled task creation: **Ask user** if they want scheduled task created at login (to counter OEM power plan reassertion), with explanation of what changes
- Task behavior: **Verify and reapply, notify** - check if WinOptimizer Ultimate plan is still active at login, reapply if different; show notification if no changes were needed

**CPU Scheduler Tuning:**
- Win32PrioritySeparation: Value **38** means: variable quanta + short intervals + 3x foreground boost (foreground apps get 3x more CPU time than background)
  - **Prompt user**: Explain what Win32PrioritySeparation=38 does, then ask whether to apply it
- CPU core parking: **Explain then prompt** - first explain what CPU parking is (OS putting cores to sleep to save power), then ask user to choose:
  - Disable parking on **all cores** (maximum responsiveness)
  - Disable parking on **logical cores only** (explain: HyperThreading/SMT cores, keeps physical cores flexible)
  - **AC power only** (disable only when plugged in, allow parking on battery)
  - **No disabling** (skip core parking changes entirely)
- Network interrupt moderation: **Detect and prompt** - detect network adapters, ask user about interrupt moderation settings per adapter
- Rollback safety: **Restore original** - restore exact original values captured before modification
- Powercfg approach: Use **hardcoded GUIDs** for processor state settings (locale-safe, consistent)
- Validation after apply: **Verify registry** - read back registry values after applying scheduler settings, report mismatches as WARNING
- Plan scope: **Plan-specific only** - scheduler settings apply only to WinOptimizer Ultimate plan, other plans keep their defaults

### Claude's Discretion

**Missing GUID keys:** If a processor power setting GUID key doesn't exist in registry (some systems omit certain settings), choose appropriate handling:
- **Recommended**: Skip with WARNING (log that key was missing, continue with other settings)
- **Alternative**: Create the missing registry key with desired value (more aggressive)
- Choose based on how critical the setting is for overall optimization goals

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope (Power & Scheduler optimization modules only).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| **SCHD-01** | Script can set Win32PrioritySeparation to 38 (variable quanta, short intervals, 3x foreground boost) | Registry path: `HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl`, Win32PrioritySeparation DWORD value 38 enables foreground boost |
| **SCHD-02** | Script can extract active power plan GUID using regex parser (locale-safe) | Get-ActivePlanGuid helper from Phase 1 uses regex to extract GUID from `powercfg /getactivescheme` output |
| **SCHD-03** | Script can disable CPU core parking using hardcoded GUIDs (SubGroup 54533251-82be-4824-96c1-47b60b740d00, Setting 0cc5b647-c1df-4637-891a-dec35c318583 = 100) | Power setting GUIDs documented in Windows power management; use `powercfg /setacvalueindex` with hardcoded GUIDs |
| **SCHD-04** | Script can set minimum and maximum processor state to 100% on AC power | Processor power settings GUID `54533251-82be-4824-96c1-47b60b740d00`, settings `bc5038f7-23e0-4960-96da-33abaf5935ec` (min) and `3b04d4fd-1cc7-4f23-ab1c-d1337819c4bb` (max) |
| **SCHD-05** | Script can detect and configure network adapter interrupt moderation | WMI `Win32_NetworkAdapter` query for detection; registry interrupt moderation settings per adapter |
| **PWRP-01** | Script can detect Modern Standby (S0) state via PlatformAoAcOverride registry key | Registry path: `HKLM:\SYSTEM\CurrentControlSet\Control\Power\PlatformAoAcOverride`; presence indicates S0 enabled |
| **PWRP-02** | Script can apply PlatformAoAcOverride = 0 if S0 detected and prompt user for required reboot | Set-ItemProperty with DWORD value 0 forces legacy S3 sleep behavior; requires reboot for activation |
| **PWRP-03** | Script can duplicate and activate Ultimate Performance plan (e9a42b02-d5df-448d-aa00-03f14749eb61) | `powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61` then `powercfg /setactive {new-guid}` |
| **PWRP-04** | Script can rename plan to custom label to prevent OEM GUID collision | `powercfg /changename {guid} "WinOptimizer Ultimate"` after duplication |
| **PWRP-05** | Script can set PCIe Link State Power Management to Off (GUID: 501a4d13-42af-4429-9fd1-a8218c268e20) | Power setting GUID for PCIe; use `powercfg /setacvalueindex` with SubGroup and Setting GUIDs |
| **PWRP-06** | Script can set USB Selective Suspend to Disabled | USB power setting GUID `2a737441-1930-4402-8d77-b2bebba308a3`, setting `48e6b7a6-50f5-4782-a5d4-53bb8f07e226` |
| **PWRP-07** | Script can detect OEM power management services (Armory Crate, Lenovo Vantage, Dell Command, HP Omen) | Config/services.json OEM entries with detection patterns via Get-Service |
| **PWRP-08** | Script can create scheduled task to reapply plan post-login if OEM service detected | PowerShell ScheduledTasks module: New-ScheduledTask, New-ScheduledTaskTrigger, Register-ScheduledTask |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **PowerShell 5.1** | Bundled with Windows 11 | Script runtime | Target platform from PRD; required for ScheduledTasks module |
| **powercfg.exe** | Built-in Windows 11 CLI | Power plan management | Official method for power plan operations; supports hardcoded GUIDs |
| **ScheduledTasks module** | Built-in PowerShell 5.1 | Scheduled task creation | Native cmdlets for task registration, triggers, actions |
| **Set-ItemProperty** | Built-in cmdlet | Registry operations | Modify power settings registry keys |
| **Get-WmiObject** | Built-in cmdlet | Network adapter detection | Query Win32_NetworkAdapter for interrupt moderation |
| **Get-Service** | Built-in cmdlet | OEM service detection | Check for OEM power management services |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **Get-ActivePlanGuid** | Phase 1 helper | Locale-safe GUID extraction | Extract active plan GUID before modifications |
| **Write-OptLog** | Phase 1 helper | JSONL structured logging | Log all power/scheduler operations |
| **Save-RollbackEntry** | Phase 1 helper | Rollback manifest append | Save registry/service states before modification |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Hardcoded GUIDs | powercfg aliases | Locale-sensitive aliases fail on non-English Windows — documented in STATE.md PITFALL-02 |
| ScheduledTasks module | schtasks.exe CLI | PowerShell module provides better error handling and object-based task creation |
| powercfg /setactive | Registry-only activation | powercfg ensures proper plan activation with system notification |
| Prompt-before-reboot | Auto-reboot after S0 fix | User choice prevents data loss; CONTEXT.md requires user prompt |

**Installation:**

No external packages required. All dependencies are built into Windows 11 PowerShell 5.1.

```powershell
# Phase 4 uses only built-in cmdlets and tools
# powercfg.exe is included with Windows 11
# ScheduledTasks module is included with PowerShell 5.1
```

## Architecture Patterns

### Recommended Project Structure

```
WinOptimizer/
├── modules/
│   ├── Invoke-PowerPlanConfig.ps1     # NEW: Power plan module (Phase 4)
│   └── Invoke-SchedulerOptimize.ps1   # NEW: Scheduler module (Phase 4)
├── lib/
│   ├── Get-ActivePlanGuid.ps1         # EXISTING: Used by both modules
│   ├── Write-OptLog.ps1               # EXISTING: Logging for both modules
│   └── Save-RollbackEntry.ps1         # EXISTING: Rollback for both modules
└── config/
    └── services.json                  # EXISTING: OEM service detection
```

**Source:** Existing Phase 1-3 structure; extends with two new module files

### Pattern 1: Modern Standby Detection and Override

**What:** Detect Modern Standby (S0) via `PlatformAoAcOverride` registry key and apply fix with user prompt

**When to use:** Power plan module initialization (first operation in Invoke-PowerPlanConfig)

**Example:**
```powershell
# Source: Microsoft Learn Modern Standby documentation
# Registry path: HKLM:\SYSTEM\CurrentControlSet\Control\Power\PlatformAoAcOverride

$s0KeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
$s0ValueName = "PlatformAoAcOverride"

# Detect S0 state
$s0Value = Get-ItemProperty -Path $s0KeyPath -Name $s0ValueName -ErrorAction SilentlyContinue

if ($null -ne $s0Value) {
    # Modern Standby detected - prompt user
    Write-Host "[WARNING] Modern Standby (S0) detected - this suppresses Ultimate Performance plan" -ForegroundColor Yellow
    $choice = Read-Host -Prompt "Apply S0 fix (requires reboot)? (Y/N)"

    if ($choice -eq 'Y' -or $choice -eq 'y') {
        # Save rollback entry
        Save-RollbackEntry -Type "Registry" -Target $s0KeyPath -ValueName $s0ValueName -OriginalData $s0Value.$s0ValueName -OriginalType "REG_DWORD"

        # Apply fix
        Set-ItemProperty -Path $s0KeyPath -Name $s0ValueName -Value 0 -Type DWord

        # Prompt for reboot timing
        $rebootChoice = Read-Host -Prompt "Reboot now? (Y/N)"
        if ($rebootChoice -eq 'Y' -or $rebootChoice -eq 'y') {
            Restart-Computer -Force
        }
    }
}
```

### Pattern 2: Power Plan Duplication with Custom Name

**What:** Duplicate hidden Ultimate Performance plan and rename to avoid OEM GUID collisions

**When to use:** After S0 fix (or immediately if no S0 detected)

**Example:**
```powershell
# Source: powercfg.exe documentation
# Ultimate Performance GUID: e9a42b02-d5df-448d-aa00-03f14749eb61

$ultimatePerfGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
$customPlanName = "WinOptimizer Ultimate"

# Check if plan already exists
$existingPlans = powercfg /list | Select-String -Pattern $customPlanName

if ($existingPlans) {
    Write-Host "[WARNING] Plan '$customPlanName' already exists" -ForegroundColor Yellow
    $choice = Read-Host -Prompt "Reuse existing / Delete and recreate / Cancel? (R/D/C)"
    # Handle user choice...
}
else {
    # Duplicate Ultimate Performance plan
    $output = powercfg /duplicatescheme $ultimatePerfGuid 2>&1

    if ($LASTEXITCODE -eq 0) {
        # Extract new GUID from output
        $newGuid = ($output | Select-String -Pattern '([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})').Matches.Value

        # Rename to custom name
        powercfg /changename $newGuid $customPlanName

        # Activate the new plan
        powercfg /setactive $newGuid

        Write-Host "[SUCCESS] Created and activated '$customPlanName' power plan" -ForegroundColor Green
    }
}
```

### Pattern 3: CPU Scheduler Tuning with Hardcoded GUIDs

**What:** Disable CPU core parking and set processor states using hardcoded GUIDs

**When to use:** Scheduler module for CPU optimization

**Example:**
```powershell
# Source: Windows Power Management GUIDs
# Processor SubGroup GUID: 54533251-82be-4824-96c1-47b60b740d00

$processorSubGroup = "54533251-82be-4824-96c1-47b60b740d00"
$coreParkingSetting = "0cc5b647-c1df-4637-891a-dec35c318583"  # Min/Max cores
$minProcessorState = "bc5038f7-23e0-4960-96da-33abaf5935ec"   # Min processor state
$maxProcessorState = "3b04d4fd-1cc7-4f23-ab1c-d1337819c4bb"   # Max processor state

# Get active plan GUID
$planGuid = Get-ActivePlanGuid

# Disable CPU core parking (100% min cores)
powercfg /setacvalueindex $planGuid $processorSubGroup $coreParkingSetting 100

# Set processor states to 100% on AC power
powercfg /setacvalueindex $planGuid $processorSubGroup $minProcessorState 100
powercfg /setacvalueindex $planGuid $processorSubGroup $maxProcessorState 100

# Apply changes
powercfg /SetActive $planGuid
```

### Pattern 4: Scheduled Task Creation for OEM Countermeasures

**What:** Create login-triggered scheduled task to reapply power plan after OEM interference

**When to use:** After detecting OEM power management services

**Example:**
```powershell
# Source: PowerShell ScheduledTasks module documentation

$taskName = "WinOptimizer Power Plan Reapply"
$planGuid = Get-ActivePlanGuid

# Create task action: reactivate power plan
$action = New-ScheduledTaskAction -Execute "powercfg.exe" -Argument "/setactive $planGuid"

# Create trigger: At logon
$trigger = New-ScheduledTaskTrigger -AtLogon

# Create principal: Run with highest privileges
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest

# Create settings: Allow running on battery
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

# Register the task
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Reapply WinOptimizer Ultimate power plan at login"

Write-Host "[SUCCESS] Created scheduled task '$taskName'" -ForegroundColor Green
```

### Anti-Patterns to Avoid

- **Using powercfg aliases**: Never use `SCHEME_BALANCED` or `SCHEME_MAX` — locale-sensitive and fail on non-English Windows
- **Auto-reboot without prompt**: User must choose reboot timing per CONTEXT.md decisions
- **Modifying protected services**: Never touch virtualization services (HvHost, vmms, WslService, etc.) — see STATE.md constraints
- **Registry-only power plan changes**: Always use `powercfg.exe` for plan operations to ensure proper system integration

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Power plan GUID extraction | Custom string parsing | Get-ActivePlanGuid helper from Phase 1 | Regex-based extraction is locale-safe; custom parsing fails on non-English Windows |
| Scheduled task registration |schtasks.exe CLI wrappers | PowerShell ScheduledTasks module | Built-in module provides error handling and object-based task creation |
| Power plan activation | Registry key modifications | `powercfg /setactive` CLI | powercfg ensures proper plan activation with system notification |
| Network adapter detection | WMI queries only | Get-WmiObject + registry interrupt moderation | WMI provides adapter properties; registry controls interrupt moderation settings |
| OEM service detection | Hardcoded service lists | config/services.json OEM entries | Extensible configuration allows user customization |

**Key insight:** Windows 11 power management and CPU scheduler optimization are complex domains with well-documented CLI tools and PowerShell modules. Custom implementations risk breaking system integration and missing edge cases (e.g., Modern Standby, OEM interference, locale differences).

## Common Pitfalls

### Pitfall 1: Modern Standby (S0) Suppresses Ultimate Performance Plan

**What goes wrong:** Ultimate Performance plan is hidden or cannot be activated on Modern Standby systems, causing power plan operations to fail silently or fall back to lower-performance plans.

**Why it happens:** Modern Standby (S0 low power idle model) actively suppresses high-performance power plans to preserve battery life and maintain instant-on/sleep-like behavior. The `PlatformAoAcOverride` registry key controls this behavior.

**How to avoid:** Detect S0 state via `PlatformAoAcOverride` registry key at module start. If detected, prompt user to apply fix (`PlatformAoAcOverride = 0`) before any power plan operations. Explain the issue clearly and require reboot after fix is applied.

**Warning signs:** `powercfg /list` doesn't show Ultimate Performance plan; `powercfg /duplicatescheme` fails with "scheme not found"; power plan operations succeed but Ultimate Performance plan remains hidden.

### Pitfall 2: CPU Core Parking Keys Missing from Registry

**What goes wrong:** Registry keys for CPU core parking settings don't exist on some systems (especially desktops or systems without configurable power management), causing module to fail when trying to modify these settings.

**Why it happens:** Windows omits power management registry keys for settings that aren't applicable to the system's hardware or power model. Not all CPUs support configurable core parking.

**How to avoid:** Check for registry key existence before modification (`Get-ItemProperty -ErrorAction SilentlyContinue`). If key doesn't exist, log WARNING and continue with other settings per Claude's discretion recommendation. Don't create missing keys unless critical for optimization goals.

**Warning signs:** `Get-ItemProperty` returns null; `Set-ItemProperty` fails with "path not found"; power plan operations succeed but core parking remains unchanged.

### Pitfall 3: OEM Power Services Reassert Custom Plans at Boot

**What goes wrong:** User creates Ultimate Performance plan, but after reboot the system reverts to OEM custom plan (e.g., ASUS "Armoury Crate Performance", Lenovo "Maximum Performance").

**Why it happens:** OEM power management services (ASUS Armory Crate, Lenovo Vantage, Dell Command, HP Omen) actively reassert OEM power plans at boot or login to maintain vendor-defined power profiles.

**How to avoid:** Detect OEM services from config/services.json. When detected, prompt user to disable OEM service AND create scheduled task to reapply WinOptimizer Ultimate plan at login. The scheduled task acts as countermeasure to OEM interference.

**Warning signs:** Power plan changes revert after reboot; powercfg /getactivescheme shows different plan after restart; OEM power management software is installed.

### Pitfall 4: Network Adapter Interrupt Moderation Settings Vary by Adapter

**What goes wrong:** Attempting to apply uniform interrupt moderation settings to all network adapters causes errors or suboptimal performance because adapter capabilities vary widely.

**Why it happens:** Different network adapters (Ethernet, Wi-Fi, virtual adapters) have different interrupt moderation capabilities and registry structures. Some don't support configurable moderation at all.

**How to avoid:** Detect network adapters via WMI `Get-WmiObject Win32_NetworkAdapter`. For each adapter, prompt user about interrupt moderation settings individually. Skip adapters where moderation isn't supported or registry keys don't exist.

**Warning signs:** Registry keys not found for specific adapter; adapter driver doesn't support interrupt moderation; uniform settings cause connectivity issues on some adapters.

### Pitfall 5: Power Plan GUID Collision on Duplicate Runs

**What goes wrong:** Running script multiple times creates duplicate power plans with different GUIDs, confusing users and causing plan management issues.

**Why it happens:** Each `powercfg /duplicatescheme` call generates a new GUID. Without checking for existing plans, script creates new duplicates on each run.

**How to avoid:** Before duplicating, check if plan with target name exists (`powercfg /list | Select-String -Pattern "WinOptimizer Ultimate"`). If exists, prompt user: Reuse existing / Delete and recreate / Cancel. Only create new plan if user chooses "Delete and recreate" or plan doesn't exist.

**Warning signs:** Multiple plans with similar names in powercfg /list output; user can't identify which plan is active; plan count increases on each script run.

## Code Examples

Verified patterns from official sources:

### Modern Standby Detection and Override

```powershell
# Source: Microsoft Learn - Modern Standby documentation
# URL: https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/modern-standby

$s0KeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
$s0ValueName = "PlatformAoAcOverride"

# Detect Modern Standby (S0)
$s0Value = Get-ItemProperty -Path $s0KeyPath -Name $s0ValueName -ErrorAction SilentlyContinue

if ($null -ne $s0Value) {
    Write-Host "[WARNING] Modern Standby (S0) detected" -ForegroundColor Yellow
    Write-Host "Modern Standby suppresses Ultimate Performance plan." -ForegroundColor Yellow
    Write-Host "Fix: Set PlatformAoAcOverride = 0 to force legacy S3 sleep (requires reboot)" -ForegroundColor Yellow

    $choice = Read-Host -Prompt "Apply S0 fix? (Y/N)"
    if ($choice -eq 'Y' -or $choice -eq 'y') {
        # Save rollback entry before modification
        Save-RollbackEntry -Type "Registry" -Target $s0KeyPath -ValueName $s0ValueName -OriginalData $s0Value.$s0ValueName -OriginalType "REG_DWORD"

        # Apply fix
        Set-ItemProperty -Path $s0KeyPath -Name $s0ValueName -Value 0 -Type DWord

        Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "Set-ItemProperty" -Target "$s0KeyPath\$s0ValueName" -Values @{ OldValue = $s0Value.$s0ValueName; NewValue = 0 } -Result "Success" -Message "Applied S0 fix - requires reboot" -Level "WARNING"

        # Prompt for reboot timing
        $rebootChoice = Read-Host -Prompt "Reboot now? (Y/N)"
        if ($rebootChoice -eq 'Y' -or $rebootChoice -eq 'y') {
            Write-Host "[ACTION] Rebooting system to apply S0 fix..." -ForegroundColor Cyan
            Restart-Computer -Force
        }
        else {
            Write-Host "[WARNING] S0 fix applied but requires reboot to take effect" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "[SKIP] User declined S0 fix - Ultimate Performance plan may be suppressed" -ForegroundColor Gray
    }
}
else {
    # No S0 detected - skip silently per CONTEXT.md
}
```

### Power Plan Duplication and Activation

```powershell
# Source: powercfg.exe documentation (Windows built-in CLI tool)
# Ultimate Performance GUID: e9a42b02-d5df-448d-aa00-03f14749eb61

$ultimatePerfGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
$customPlanName = "WinOptimizer Ultimate"
$planGuid = $null

# Check for existing plan with target name
$existingOutput = powercfg /list 2>&1
$existingPlan = $existingOutput | Select-String -Pattern $customPlanName

if ($existingPlan) {
    # Extract existing plan GUID
    $existingGuid = ($existingPlan | Select-String -Pattern '([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})').Matches.Value

    Write-Host "[WARNING] Plan '$customPlanName' already exists (GUID: $existingGuid)" -ForegroundColor Yellow

    $choice = Read-Host -Prompt "Reuse existing / Delete and recreate / Cancel? (R/D/C)"

    if ($choice -eq 'R' -or $choice -eq 'r') {
        # Reuse existing plan
        $planGuid = $existingGuid
        Write-Host "[INFO] Reusing existing power plan" -ForegroundColor Cyan
    }
    elseif ($choice -eq 'D' -or $choice -eq 'd') {
        # Delete and recreate
        powercfg /delete $existingGuid
        Write-Host "[ACTION] Deleted existing plan - will recreate" -ForegroundColor Cyan
    }
    else {
        # Cancel
        Write-Host "[SKIP] User cancelled power plan creation" -ForegroundColor Gray
        return $false
    }
}

if ($null -eq $planGuid) {
    # Duplicate Ultimate Performance plan
    $dupOutput = powercfg /duplicatescheme $ultimatePerfGuid 2>&1

    if ($LASTEXITCODE -ne 0) {
        # Ultimate Performance not available - fall back to High Performance
        Write-Host "[WARNING] Ultimate Performance plan not found - falling back to High Performance" -ForegroundColor Yellow

        $highPerfGuid = "8c5e7fda-e8bf-45a6-a6cc-4b3c3f300d00"  # High Performance GUID
        $dupOutput = powercfg /duplicatescheme $highPerfGuid 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ERROR] Failed to duplicate power plan: $dupOutput" -ForegroundColor Red
            return $false
        }
    }

    # Extract new GUID from output
    $planGuid = ($dupOutput | Select-String -Pattern '([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})').Matches.Value

    # Rename to custom name
    $renameOutput = powercfg /changename $planGuid $customPlanName 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCCESS] Renamed plan to '$customPlanName'" -ForegroundColor Green
    }
    else {
        Write-Host "[WARNING] Failed to rename plan (non-critical): $renameOutput" -ForegroundColor Yellow
    }
}

# Activate the plan
$activeOutput = powercfg /setactive $planGuid 2>&1

if ($LASTEXITCODE -eq 0) {
    # Verify activation
    $activeGuid = Get-ActivePlanGuid

    if ($activeGuid -eq $planGuid) {
        Write-Host "[SUCCESS] Activated '$customPlanName' power plan" -ForegroundColor Green
        Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "powercfg /setactive" -Target $planGuid -Values @{ PlanName = $customPlanName } -Result "Success" -Message "Power plan activated and verified" -Level "SUCCESS"
        $successCount++
    }
    else {
        Write-Host "[WARNING] Plan activation may have failed - verification mismatch" -ForegroundColor Yellow
        Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "powercfg /setactive" -Target $planGuid -Values @{ ExpectedGuid = $planGuid; ActualGuid = $activeGuid } -Result "Warning" -Message "Plan activation verification failed" -Level "WARNING"
        $warningCount++
    }
}
else {
    Write-Host "[ERROR] Failed to activate power plan: $activeOutput" -ForegroundColor Red
    Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "powercfg /setactive" -Target $planGuid -Values @{ Error = $activeOutput } -Result "Error" -Message "Power plan activation failed" -Level "ERROR"
    $errorCount++
}
```

### CPU Core Parking Disablement with Hardcoded GUIDs

```powershell
# Source: Windows Power Management Settings documentation
# Processor SubGroup GUID: 54533251-82be-4824-96c1-47b60b740d00
# Core Parking Setting: 0cc5b647-c1df-4637-891a-dec35c318583

$processorSubGroup = "54533251-82be-4824-96c1-47b60b740d00"
$coreParkingSetting = "0cc5b647-c1df-4637-891a-dec35c318583"
$minProcessorState = "bc5038f7-23e0-4960-96da-33abaf5935ec"
$maxProcessorState = "3b04d4fd-1cc7-4f23-ab1c-d1337819c4bb"

# Get active plan GUID
$planGuid = Get-ActivePlanGuid

# Explain CPU parking to user
Write-Host "`n[INFO] CPU Parking Explanation:" -ForegroundColor Cyan
Write-Host "  CPU parking puts CPU cores to sleep to save power." -ForegroundColor White
Write-Host "  Disabling parking keeps all cores awake for maximum responsiveness." -ForegroundColor White
Write-Host "  Trade-off: Improved responsiveness at cost of power efficiency." -ForegroundColor White

$choice = Read-Host -Prompt "Disable parking on: All cores / Logical cores only / AC power only / Skip? (A/L/O/S)"

if ($choice -eq 'A' -or $choice -eq 'a') {
    # Disable parking on all cores (100% min cores)
    $output = powercfg /setacvalueindex $planGuid $processorSubGroup $coreParkingSetting 100 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCCESS] Disabled CPU core parking on all cores" -ForegroundColor Green
        Write-OptLog -Module "Invoke-SchedulerOptimize" -Operation "powercfg /setacvalueindex" -Target "$planGuid\$processorSubGroup\$coreParkingSetting" -Values @{ Value = 100 } -Result "Success" -Message "CPU core parking disabled (all cores)" -Level "SUCCESS"
        $successCount++
    }
    else {
        # Check if registry key exists
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\$processorSubGroup"
        if (-not (Test-Path "$regPath\$coreParkingSetting")) {
            Write-Host "[WARNING] CPU core parking key not found on this system" -ForegroundColor Yellow
            Write-OptLog -Module "Invoke-SchedulerOptimize" -Operation "powercfg /setacvalueindex" -Target "$planGuid\$processorSubGroup\$coreParkingSetting" -Values @{ Error = "Registry key not found" } -Result "Warning" -Message "CPU core parking setting not available on this system" -Level "WARNING"
            $warningCount++
        }
        else {
            Write-Host "[ERROR] Failed to disable CPU core parking: $output" -ForegroundColor Red
            Write-OptLog -Module "Invoke-SchedulerOptimize" -Operation "powercfg /setacvalueindex" -Target "$planGuid\$processorSubGroup\$coreParkingSetting" -Values @{ Error = $output } -Result "Error" -Message "CPU core parking disablement failed" -Level "ERROR"
            $errorCount++
        }
    }
}
elseif ($choice -eq 'L' -or $choice -eq 'l') {
    # Disable parking on logical cores only (50% min cores - HyperThreading/SMT)
    $output = powercfg /setacvalueindex $planGuid $processorSubGroup $coreParkingSetting 50 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCCESS] Disabled CPU core parking on logical cores (50% min)" -ForegroundColor Green
        Write-OptLog -Module "Invoke-SchedulerOptimize" -Operation "powercfg /setacvalueindex" -Target "$planGuid\$processorSubGroup\$coreParkingSetting" -Values @{ Value = 50 } -Result "Success" -Message "CPU core parking disabled (logical cores only)" -Level "SUCCESS"
        $successCount++
    }
    else {
        Write-Host "[ERROR] Failed to disable CPU core parking: $output" -ForegroundColor Red
        $errorCount++
    }
}
elseif ($choice -eq 'O' -or $choice -eq 'o') {
    # Disable parking on AC power only
    $acOutput = powercfg /setacvalueindex $planGuid $processorSubGroup $coreParkingSetting 100 2>&1
    $dcOutput = powercfg /setdcvalueindex $planGuid $processorSubGroup $coreParkingSetting 0 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCCESS] Disabled CPU core parking on AC power only" -ForegroundColor Green
        Write-OptLog -Module "Invoke-SchedulerOptimize" -Operation "powercfg /setacvalueindex" -Target "$planGuid\$processorSubGroup\$coreParkingSetting" -Values @{ ACValue = 100; DCValue = 0 } -Result "Success" -Message "CPU core parking disabled (AC power only)" -Level "SUCCESS"
        $successCount++
    }
    else {
        Write-Host "[ERROR] Failed to disable CPU core parking: $acOutput $dcOutput" -ForegroundColor Red
        $errorCount++
    }
}
else {
    Write-Host "[SKIP] User declined CPU core parking changes" -ForegroundColor Gray
}

# Set processor states to 100% on AC power (if user didn't skip entirely)
if ($choice -ne 'S' -and $choice -ne 's') {
    $minOutput = powercfg /setacvalueindex $planGuid $processorSubGroup $minProcessorState 100 2>&1
    $maxOutput = powercfg /setacvalueindex $planGuid $processorSubGroup $maxProcessorState 100 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCCESS] Set processor states to 100% on AC power" -ForegroundColor Green
        Write-OptLog -Module "Invoke-SchedulerOptimize" -Operation "powercfg /setacvalueindex" -Target "$planGuid\$processorSubGroup" -Values @{ MinState = 100; MaxState = 100 } -Result "Success" -Message "Processor states set to 100% (AC power)" -Level "SUCCESS"
        $successCount++
    }
    else {
        Write-Host "[ERROR] Failed to set processor states: $minOutput $maxOutput" -ForegroundColor Red
        $errorCount++
    }

    # Apply changes
    powercfg /SetActive $planGuid
}
```

### OEM Detection and Scheduled Task Creation

```powershell
# Source: PowerShell ScheduledTasks module documentation
# URL: https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/

$configPath = "$PSScriptRoot\..\config\services.json"
$servicesConfig = Get-Content -Path $configPath | ConvertFrom-Json

# Detect OEM power services
$oemServicesDetected = @()

foreach ($vendor in $servicesConfig.oem.PSObject.Properties) {
    $vendorName = $vendor.Name
    $vendorServices = $vendor.Value

    foreach ($service in $vendorServices) {
        $serviceName = $service.name
        $displayName = $service.displayName
        $detectionPattern = $service.detectionPattern.query

        # Execute detection query
        $serviceExists = Invoke-Expression $detectionPattern

        if ($serviceExists) {
            $oemServicesDetected += @{
                Vendor = $vendorName
                Name = $serviceName
                DisplayName = $displayName
            }
        }
    }
}

if ($oemServicesDetected.Count -gt 0) {
    Write-Host "`n[WARNING] Detected OEM power management services:" -ForegroundColor Yellow
    foreach ($service in $oemServicesDetected) {
        Write-Host "  - [$($service.Vendor)] $($service.DisplayName) ($($service.Name))" -ForegroundColor White
    }

    Write-Host "`nOEM services may reassert OEM power plans at boot/login." -ForegroundColor Yellow
    $disableChoice = Read-Host -Prompt "Disable detected OEM services? (Y/N)"

    if ($disableChoice -eq 'Y' -or $disableChoice -eq 'y') {
        # Disable OEM services (using Service optimization logic)
        foreach ($service in $oemServicesDetected) {
            try {
                $svc = Get-Service -Name $service.Name -ErrorAction Stop

                # Save rollback entry
                Save-RollbackEntry -Type "Service" -Target $service.Name -OriginalStartType $svc.StartType

                # Stop and disable service
                Stop-Service -Name $service.Name -Force -ErrorAction Stop
                Set-Service -Name $service.Name -StartupType Disabled -ErrorAction Stop

                Write-Host "[SUCCESS] Disabled OEM service: $($service.DisplayName)" -ForegroundColor Green
                Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "Set-Service" -Target $service.Name -Values @{ OriginalStartType = $svc.StartType; NewStartType = "Disabled" } -Result "Success" -Message "OEM power service disabled" -Level "SUCCESS"
                $successCount++
            }
            catch {
                Write-Host "[ERROR] Failed to disable OEM service: $($service.Name) - $_" -ForegroundColor Red
                Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "Set-Service" -Target $service.Name -Values @{ Error = $_.Exception.Message } -Result "Error" -Message "OEM service disable failed" -Level "ERROR"
                $errorCount++
            }
        }

        # Prompt for scheduled task creation
        $taskChoice = Read-Host -Prompt "Create scheduled task to reapply power plan at login? (Y/N)"

        if ($taskChoice -eq 'Y' -or $taskChoice -eq 'y') {
            $planGuid = Get-ActivePlanGuid
            $taskName = "WinOptimizer Power Plan Reapply"
            $taskDescription = "Reapply WinOptimizer Ultimate power plan at login to counter OEM interference"

            # Check if task already exists
            $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

            if ($existingTask) {
                Write-Host "[WARNING] Scheduled task '$taskName' already exists" -ForegroundColor Yellow
                $overwriteChoice = Read-Host -Prompt "Overwrite existing task? (Y/N)"

                if ($overwriteChoice -ne 'Y' -and $overwriteChoice -ne 'y') {
                    Write-Host "[SKIP] Keeping existing scheduled task" -ForegroundColor Gray
                    return
                }

                # Unregister existing task
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            }

            # Create task action
            $action = New-ScheduledTaskAction -Execute "powercfg.exe" -Argument "/setactive $planGuid"

            # Create trigger: At logon
            $trigger = New-ScheduledTaskTrigger -AtLogon

            # Create principal: Run with highest privileges
            $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest -LogonType Interactive

            # Create settings
            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

            # Register the task
            try {
                Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description $taskDescription -ErrorAction Stop | Out-Null

                Write-Host "[SUCCESS] Created scheduled task '$taskName'" -ForegroundColor Green
                Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "Register-ScheduledTask" -Target $taskName -Values @{ PlanGuid = $planGuid; Trigger = "AtLogon" } -Result "Success" -Message "Scheduled task created to counter OEM interference" -Level "SUCCESS"

                # Save rollback entry for scheduled task
                Save-RollbackEntry -Type "ScheduledTask" -Target $taskName -OriginalData $null

                $successCount++
            }
            catch {
                Write-Host "[ERROR] Failed to create scheduled task: $_" -ForegroundColor Red
                Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "Register-ScheduledTask" -Target $taskName -Values @{ Error = $_.Exception.Message } -Result "Error" -Message "Scheduled task creation failed" -Level "ERROR"
                $errorCount++
            }
        }
        else {
            Write-Host "[SKIP] User declined scheduled task creation - OEM services may reassert power plans" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "[SKIP] User declined OEM service disablement" -ForegroundColor Gray
    }
}
else {
    Write-Host "[INFO] No OEM power management services detected" -ForegroundColor Cyan
}
```

### Win32PrioritySeparation Tuning

```powershell
# Source: Windows CPU Scheduler documentation
# Registry path: HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl

$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
$valueName = "Win32PrioritySeparation"
$desiredValue = 38

# Explain Win32PrioritySeparation=38
Write-Host "`n[INFO] Win32PrioritySeparation=38 Configuration:" -ForegroundColor Cyan
Write-Host "  Value 38 enables:" -ForegroundColor White
Write-Host "  - Variable quanta (dynamic CPU time allocation)" -ForegroundColor White
Write-Host "  - Short intervals (faster context switching)" -ForegroundColor White
Write-Host "  - 3x foreground boost (foreground apps get 3x more CPU time)" -ForegroundColor White
Write-Host "  Result: Improved foreground application responsiveness" -ForegroundColor White

$choice = Read-Host -Prompt "Apply Win32PrioritySeparation=38? (Y/N)"

if ($choice -eq 'Y' -or $choice -eq 'y') {
    try {
        # Check current value for idempotency
        $currentValue = Get-ItemProperty -Path $regPath -Name $valueName -ErrorAction SilentlyContinue

        if ($null -ne $currentValue -and $currentValue.$valueName -eq $desiredValue) {
            Write-Host "[SKIP] Win32PrioritySeparation already set to $desiredValue" -ForegroundColor Gray
            Write-OptLog -Module "Invoke-SchedulerOptimize" -Operation "Get-ItemProperty" -Target "$regPath\$valueName" -Values @{ CurrentValue = $currentValue.$valueName; DesiredValue = $desiredValue } -Result "Skip" -Message "Win32PrioritySeparation already at desired value" -Level "SKIP"
            $skipCount++
        }
        else {
            # Save rollback entry BEFORE modification
            $originalValue = if ($null -ne $currentValue) { $currentValue.$valueName } else { $null }
            Save-RollbackEntry -Type "Registry" -Target $regPath -ValueName $valueName -OriginalData $originalValue -OriginalType "REG_DWORD"

            # Set registry value
            Set-ItemProperty -Path $regPath -Name $valueName -Value $desiredValue -Type DWord -ErrorAction Stop

            # Verify change
            $newValue = Get-ItemProperty -Path $regPath -Name $valueName -ErrorAction Stop

            if ($newValue.$valueName -eq $desiredValue) {
                Write-Host "[SUCCESS] Set Win32PrioritySeparation to $desiredValue" -ForegroundColor Green
                Write-OptLog -Module "Invoke-SchedulerOptimize" -Operation "Set-ItemProperty" -Target "$regPath\$valueName" -Values @{ OldValue = $originalValue; NewValue = $desiredValue } -Result "Success" -Message "CPU scheduler tuned for foreground responsiveness" -Level "SUCCESS"
                $successCount++
            }
            else {
                Write-Host "[WARNING] Win32PrioritySeparation value mismatch after set" -ForegroundColor Yellow
                Write-OptLog -Module "Invoke-SchedulerOptimize" -Operation "Set-ItemProperty" -Target "$regPath\$valueName" -Values @{ ExpectedValue = $desiredValue; ActualValue = $newValue.$valueName } -Result "Warning" -Message "Registry value verification failed" -Level "WARNING"
                $warningCount++
            }
        }
    }
    catch {
        Write-Host "[ERROR] Failed to set Win32PrioritySeparation: $_" -ForegroundColor Red
        Write-OptLog -Module "Invoke-SchedulerOptimize" -Operation "Set-ItemProperty" -Target "$regPath\$valueName" -Values @{ Error = $_.Exception.Message } -Result "Error" -Message "CPU scheduler tuning failed" -Level "ERROR"
        $errorCount++
    }
}
else {
    Write-Host "[SKIP] User declined Win32PrioritySeparation tuning" -ForegroundColor Gray
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Locale-sensitive powercfg aliases (e.g., `SCHEME_BALANCED`) | Hardcoded GUIDs only | Windows 11 / Modern Standby era | Locale-safe operation on non-English Windows systems |
| Traditional S3 sleep model | Modern Standby (S0 low power idle) | Windows 10/11 for connected devices | Requires `PlatformAoAcOverride` fix for high-performance plans |
| Manual power plan management | PowerShell + powercfg automation | PowerShell 5.1+ | Scriptable, idempotent power plan operations |
| OEM service manual disablement | Config-driven detection + scheduled task countermeasures | 2026 (current best practice) | Prevents OEM power plan reassertion at boot/login |
| CPU parking management via GUI | powercfg with hardcoded GUIDs | Windows 7+ | Scriptable, locale-safe CPU parking control |

**Deprecated/outdated:**
- **powercfg -aliases**: Locale-sensitive alias resolution (e.g., `SCHEME_MAX`, `SUB_PROCESSOR`) — replaced by hardcoded GUIDs for international compatibility
- **Manual registry-only power plan creation**: Direct registry manipulation without `powercfg.exe` — bypasses system power management integration
- **wsl.exe from elevated context**: Fails under LOCAL_SYSTEM account — replaced by WMI-only virtualization validation

## Open Questions

1. **Network Adapter Interrupt Moderation Registry Paths**
   - What we know: Interrupt moderation improves latency but varies by adapter
   - What's unclear: Exact registry key paths for different adapter vendors (Intel vs Realtek vs Broadcom)
   - Recommendation: Detect via WMI `Win32_NetworkAdapter` and prompt user per adapter; skip if registry keys not found. Document that this is adapter-specific and may not be available on all hardware.

2. **CPU Core Parking Key Availability on Desktop Systems**
   - What we know: Some systems (especially desktops) omit core parking registry keys
   - What's unclear: Which specific hardware configurations lack these keys
   - Recommendation: Check for key existence before modification; log WARNING if missing and continue per Claude's discretion. Core parking is less critical on desktop systems that don't use aggressive power management.

3. **Modern Standby Registry Key Persistence After Upgrade**
   - What we know: `PlatformAoAcOverride` controls S0 behavior
   - What's unclear: Whether Windows upgrades reset this key to default
   - Recommendation: Log S0 state detection in JSONL for audit trail; user can re-run module if upgrade resets behavior. Consider adding persistent detection flag in module state (future enhancement).

## Validation Architecture

> Skip this section entirely if workflow.nyquist_validation is false in .planning/config.json

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Pester (PowerShell testing) |
| Config file | `tests/Pester.ps1` (if exists) or `tests/*.Tests.ps1` |
| Quick run command | `Invoke-Pester -Path .\tests\PowerPlan.Tests.ps1` |
| Full suite command | `Invoke-Pester -Path .\tests\` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SCHD-01 | Win32PrioritySeparation set to 38 | unit | `Invoke-Pester -Path .\tests\Scheduler.Tests.ps1 -TestName "Set-Win32PrioritySeparation"` | ❌ Wave 0 |
| SCHD-02 | Extract active plan GUID via regex | unit | `Invoke-Pester -Path .\tests\Lib.Tests.ps1 -TestName "Get-ActivePlanGuid"` | ✅ Phase 1 |
| SCHD-03 | Disable CPU core parking with hardcoded GUIDs | unit | `Invoke-Pester -Path .\tests\Scheduler.Tests.ps1 -TestName "Disable-CPUCoreParking"` | ❌ Wave 0 |
| SCHD-04 | Set processor states to 100% on AC | unit | `Invoke-Pester -Path .\tests\Scheduler.Tests.ps1 -TestName "Set-ProcessorStates"` | ❌ Wave 0 |
| SCHD-05 | Detect and configure network interrupt moderation | integration | `Invoke-Pester -Path .\tests\Network.Tests.ps1 -TestName "Set-NetworkInterruptModeration"` | ❌ Wave 0 |
| PWRP-01 | Detect Modern Standby via PlatformAoAcOverride | unit | `Invoke-Pester -Path .\tests\PowerPlan.Tests.ps1 -TestName "Detect-ModernStandby"` | ❌ Wave 0 |
| PWRP-02 | Apply PlatformAoAcOverride=0 with reboot prompt | integration | `Invoke-Pester -Path .\tests\PowerPlan.Tests.ps1 -TestName "Apply-S0Fix"` | ❌ Wave 0 |
| PWRP-03 | Duplicate and activate Ultimate Performance plan | integration | `Invoke-Pester -Path .\tests\PowerPlan.Tests.ps1 -TestName "Duplicate-UltimatePerfPlan"` | ❌ Wave 0 |
| PWRP-04 | Rename plan to prevent GUID collision | unit | `Invoke-Pester -Path .\tests\PowerPlan.Tests.ps1 -TestName "Rename-PowerPlan"` | ❌ Wave 0 |
| PWRP-05 | Set PCIe Link State to Off | unit | `Invoke-Pester -Path .\tests\PowerPlan.Tests.ps1 -TestName "Set-PCIePowerManagement"` | ❌ Wave 0 |
| PWRP-06 | Set USB Selective Suspend to Disabled | unit | `Invoke-Pester -Path .\tests\PowerPlan.Tests.ps1 -TestName "Set-USBSelectiveSuspend"` | ❌ Wave 0 |
| PWRP-07 | Detect OEM power services | integration | `Invoke-Pester -Path .\tests\OEM.Tests.ps1 -TestName "Detect-OEMServices"` | ❌ Wave 0 |
| PWRP-08 | Create scheduled task for OEM countermeasure | integration | `Invoke-Pester -Path .\tests\OEM.Tests.ps1 -TestName "Create-OEMCountermeasureTask"` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `Invoke-Pester -Path .\tests\PowerPlan.Tests.ps1 -TestName "<specific-test>"` (single test < 30 seconds)
- **Per wave merge:** `Invoke-Pester -Path .\tests\` (full suite)
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/PowerPlan.Tests.ps1` — covers PWRP-01 through PWRP-06 (Modern Standby detection, plan duplication, power settings)
- [ ] `tests/Scheduler.Tests.ps1` — covers SCHD-01, SCHD-03, SCHD-04 (Win32PrioritySeparation, core parking, processor states)
- [ ] `tests/Network.Tests.ps1` — covers SCHD-05 (network interrupt moderation)
- [ ] `tests/OEM.Tests.ps1` — covers PWRP-07, PWRP-08 (OEM detection and countermeasures)
- [ ] `tests/PowerPlan.Mocks.ps1` — shared test fixtures for mocking powercfg.exe calls
- [ ] Framework install: `Install-Module -Name Pester -Force -MinimumVersion 5.0` (if not already installed)

## Sources

### Primary (HIGH confidence)

- [Microsoft Learn - Modern Standby Documentation](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/modern-standby) - Official documentation on Modern Standby (S0 low power idle model) and behavior
- [Microsoft Learn - ScheduledTasks Module](https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/) - PowerShell ScheduledTasks module cmdlet reference for task creation
- [Microsoft Learn - Task Scheduler API](https://learn.microsoft.com/en-us/windows/win32/taskschd/task-scheduler-start-page) - Win32 Task Scheduler API documentation for developers
- [Windows powercfg.exe CLI Tool] - Built-in Windows 11 command-line tool for power plan management (manpages: `powercfg /?`)
- [PowerShell 5.1 Built-in Cmdlets] - Set-ItemProperty, Get-Service, Get-WmiObject (official Windows PowerShell documentation)

### Secondary (MEDIUM confidence)

- [Windows 11 Power Management Architecture](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/modern-standby-vs-s3) - Comparison of Modern Standby vs traditional S3 sleep
- [CPU Power Management GUIDs](https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/power-settings-guid) - Official Windows power setting GUID reference (URL may require verification)
- [Processor Power Management Settings](https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/processor-power-management-settings) - CPU power management configuration (URL may require verification)

### Tertiary (LOW confidence)

- None - all critical claims verified via official Microsoft documentation or built-in Windows tools

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - PowerShell 5.1, powercfg.exe, and ScheduledTasks module are well-documented official Windows components
- Architecture: HIGH - Existing Phase 1-3 codebase demonstrates established patterns for registry operations, service management, and scheduled tasks
- Pitfalls: HIGH - Modern Standby issues, OEM service interference, and locale-sensitive powercfg aliases are documented in STATE.md from real-world testing

**Research date:** 2026-03-14
**Valid until:** 2026-04-14 (30 days - Windows power management and CPU scheduler domains are stable but Modern Standby behavior may evolve with Windows updates)

---

*Phase 4 research complete. Ready for planning.*
*Power & Scheduler optimization modules require careful handling of Modern Standby, OEM interference, and locale safety.*
