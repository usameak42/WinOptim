# Pitfalls Research: Windows Optimization Gotchas

**Confidence:** Critical — PRD Section 1 documents real-world errors encountered

Each pitfall below was discovered during actual Windows 11 optimization sessions. The script MUST defensively handle these scenarios.

## PITFALL-01: Execution Policy Override Failure

**What went wrong:**
```
Set-ExecutionPolicy Unrestricted -Scope CurrentUser
# ERROR: ExecutionPolicyOverride scope conflict
```

**Root cause:** Machine-level or GPO-enforced policy in `HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell` blocks global scope changes. Machine-scope policy takes precedence over all user-scope attempts.

**Detection:** Check if `Set-ExecutionPolicy` fails with `ExecutionPolicyOverride` error.

**Prevention:**
- Use Process-scope bypass only: `Set-ExecutionPolicy Bypass -Scope Process -Force`
- NEVER attempt to modify Machine-scope or User-scope policy
- Inject bypass flag into current runspace without writing to registry

**Which phase:** Entry Point (first operation)

---

## PITFALL-02: Ultimate Performance Plan Hidden by Modern Standby

**What went wrong:**
```
powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
# ERROR: Plan does not appear in powercfg /list
```

**Root cause:** Laptop firmware advertises Modern Standby (S0 Low Power Idle) to the OS. When S0 is active, Windows Power Manager kernel module (`po.sys`) explicitly suppresses high-performance plans as they are architecturally incompatible with S0's always-on network stack.

**Detection:**
```powershell
$s0Key = Get-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Power' -Name 'PlatformAoAcOverride' -ErrorAction SilentlyContinue
if ($s0Key.PlatformAoAcOverride -eq 1) { # Modern Standby active }
```

**Prevention:**
1. Detect S0 state via `PlatformAoAcOverride` registry key
2. Apply fix: `reg add HKLM\System\CurrentControlSet\Control\Power /v PlatformAoAcOverride /t REG_DWORD /d 0 /f`
3. Prompt user for **required reboot** before continuing
4. Do NOT assume Ultimate Performance plan exists without S0 check

**Which phase:** Module 4 (Power Plan Config)

**Warning signs:**
- `powercfg /list` does not show Ultimate Performance plan
- Laptop has "Always On" connected standby
- `powercfg /availablesleepstates` shows "Modern Standby (S0)"

---

## PITFALL-03: CPU Core Parking — Locale Parameter Parsing Failure

**What went wrong:**
```
$activePlan = powercfg /getactivescheme
# Returns: "Power Scheme GUID: e9a42b02-d5df-448d-aa00-03f14749eb61  (Ultimate Performance)"
# Naive string assignment captures label text, not GUID

powercfg -setacvalueindex $activePlan SUB_PROCESSOR CPONCORES 100
# ERROR: Invalid Parameters
```

**Root cause:** Two compounding issues:
1. `powercfg /getactivescheme` returns formatted string with label; naive string assignment captures text
2. `SUB_PROCESSOR` alias fails to resolve in non-English Windows locales (Turkish, German, etc.)

**Detection:** Power plan assignment results in "Invalid Parameters" or alias not found errors.

**Prevention:**
1. Use regex GUID extraction for active plan:
   ```powershell
   $activePlan = (powercfg /getactivescheme | Select-String -Pattern '([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})').Matches.Value
   ```
2. Replace ALL powercfg aliases with hardcoded GUIDs:
   - Processor SubGroup: `54533251-82be-4824-96c1-47b60b740d00`
   - Core Parking Setting: `0cc5b647-c1df-4637-891a-dec35c318583`

**Which phase:** All phases using powercfg (Modules 3, 4)

**Warning signs:**
- Non-English Windows locale
- "Invalid Parameters" from powercfg
- Alias resolution failures

---

## PITFALL-04: Windows Search — TrustedInstaller Registry Ownership

**What went wrong:**
```
Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows Search\Gather\Windows\SystemIndex' -Name 'WindowsOnly' -Value 1
# ERROR: SecurityException: Requested registry access is not allowed
```

**Root cause:** The key is owned by `NT SERVICE\TrustedInstaller`. Standard elevation to Administrators group does not inherit TrustedInstaller permissions. The ACL explicitly denies write access to Administrators.

**Detection:** `SecurityException` when attempting to modify Windows Search keys.

**Prevention:**
1. Implement `Take-RegistryOwnership` helper using `System.Security.AccessControl` classes
2. Programmatically transfer ownership to Administrators group
3. Grant `FullControl` to Administrators
4. Apply target property change
5. Alternative: Route through ExecTI to execute as TrustedInstaller (more complex)

```powershell
function Take-RegistryOwnership {
    param([string]$Path)
    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($Path, 'ReadWriteSubTree', 'TakeOwnership')
    $acl = $key.GetAccessControl()
    $acl.SetOwner([System.Security.Principal.NTAccount]'Administrators')
    $key.SetAccessControl($acl)
}
```

**Which phase:** Module 5 (File System Optimization — Windows Search exclusions)

**Warning signs:**
- Keys under `HKLM:\SOFTWARE\Microsoft\Windows Search`
- "Requested registry access is not allowed" despite elevation

---

## PITFALL-05: ASUS Armory Crate Power Plan Reassertion

**What went wrong:**
```
powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61
# Success on first run
# REBOOT
# powercfg /getactivescheme
# Returns: ASUS Turbo plan (GUID reverted)
```

**Root cause:** `ArmouryCrate.Service` and `ASUSOptimization` register a boot-time power plan callback via Windows Power Management event infrastructure. They reassert ASUS-specific plan GUIDs at login, overriding any user-set active plan.

**Detection:**
- Ultimate Performance plan reverts to OEM plan after reboot
- Service exists: `Get-Service ArmouryCrate.Service` - not elevated

**Prevention:**
1. Detect OEM power management services:
   - ASUS: `ArmouryCrate.Service`, `ASUSOptimization`
   - Lenovo: `LenovoVantage`
   - Dell: `DellCommandCenter`
   - HP: `HP Omen Gaming Hub`
2. If detected, create Windows Scheduled Task:
   - Trigger: `AtLogOn` + `PT10S` delay (wait for OEM to reassert first)
   - Action: `powercfg /setactive [custom plan GUID]`
   - RunLevel: `Highest`
   - Principal: Current user (NOT LOCAL_SYSTEM)
3. Task runs after login and reasserts the optimization plan

**Which phase:** Module 4 (Power Plan Config — OEM Detection)

**Warning signs:**
- OEM gaming laptop software installed
- Power plan reverts after reboot
- OEM-specific plan names in `powercfg /list`

---

## PITFALL-06: WSL Status — LOCAL_SYSTEM Context Error

**What went wrong:**
```
# Running elevated PowerShell
wsl --status
# ERROR: Wsl/WSL_E_LOCAL_SYSTEM_NOT_SUPPORTED
```

**Root cause:** WSL2 is a per-user feature. `LxssManager` maps WSL instances to user SID tokens. Running `wsl.exe` under `LOCAL_SYSTEM` (which elevated PowerShell inherits) provides no user SID, which WSL explicitly rejects. The error is benign — WSL is intact.

**Detection:** `Wsl/WSL_E_LOCAL_SYSTEM_NOT_SUPPORTED` error when calling `wsl.exe` from elevated script.

**Prevention:**
1. NEVER call `wsl.exe` from elevated script context
2. Use WMI queries for WSL validation:
   ```powershell
   Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
   ```
3. Use `Get-Service` for service state:
   ```powershell
   Get-Service LxssManager -ErrorAction SilentlyContinue
   ```

**Which phase:** Entry Point (Test-VirtStack helper), All phases (validation)

**Warning signs:**
- Elevated PowerShell session
- Need to validate WSL state
- Temptation to call `wsl --status`

---

## PITFALL-07: Scheduled Task — Multiline Parameter Parsing Failure

**What went wrong:**
```powershell
$action = New-ScheduledTaskAction -Execute "powercfg.exe" `
    -Argument "/setactive e9a42b02-d5df-448d-aa00-03f14749eb61" `
    -DontStopIfGoingOnBattery
# ERROR: ParameterNotFound: -DontStopIfGoingOnBattery
```

**Root cause:** PowerShell's line-continuation parser misinterpreted backtick continuation characters, causing cmdlets to be parsed as separate incomplete statements which then failed parameter validation.

**Detection:** Parameters not recognized as valid cmdlet parameters.

**Prevention:**
1. **Ban backtick line continuation** entirely in codebase
2. Use single-line cmdlet calls OR proper splatting:
   ```powershell
   $params = @{
       Execute = "powercfg.exe"
       Argument = "/setactive e9a42b02-d5df-448d-aa00-03f14749eb61"
   }
   $action = New-ScheduledTaskAction @params
   ```

**Which phase:** All phases (code style rule)

**Warning signs:**
- Long command lines with many parameters
- Backtick `` ` `` characters in code
- "Parameter not found" errors

---

## PITFALL-08: Protected Service Modification

**What went wrong:**
```
# Hypothetical: Script disables "unused" services
Set-Service vmms -StartupType Disabled
# BREAKS: Hyper-V VMs no longer start
# BREAKS: Docker Desktop loses WSL2 backend
```

**Root cause:** Virtualization services (Hyper-V, WSL2, Docker) have interdependencies. Disabling protected services breaks developer toolchains.

**Detection:** User reports that WSL2, Hyper-V, or Docker stopped working after optimization.

**Prevention:**
1. Hardcoded protected services blocklist:
   - `HvHost` (Hyper-V Host)
   - `vmms` (Hyper-V Virtual Machine Management)
   - `WslService` (WSL)
   - `LxssManager` (WSL)
   - `VmCompute` (Hyper-V Compute)
   - `vmic*` (All Hyper-V VM Integration Services)
2. NEVER include these in any disabled/manual service list
3. Validate pre/post execution via `Test-VirtStack` helper

**Which phase:** Module 6 (Service Optimization — Protected Block)

**Warning signs:**
- Service name starts with `vmic` or contains `vm`, `ws`, `hv`
- Service relates to virtualization or containers

---

## PITFALL-09: Non-Idempotent Operations

**What went wrong:**
```
# Run script once: AllowTelemetry changes from 1 → 0 (Success)
# Run script twice: AllowTelemetry changes from 0 → 0 (Silent success, but wasteful)
# Better: Second run should emit [SKIP] "Already configured"
```

**Root cause:** Modules don't check current state before modifying.

**Detection:** Second run produces duplicate changes instead of `[SKIP]` messages.

**Prevention:**
1. Every operation must check current state first:
   ```powershell
   $current = Get-ItemProperty 'HKLM:\...' -Name 'AllowTelemetry'
   if ($current.AllowTelemetry -eq 0) {
       Write-Host '[SKIP] AllowTelemetry already set to 0' -ForegroundColor DarkGray
       return
   }
   ```
2. Only modify if state differs from desired state
3. Emit `[SKIP]` message if already in desired state

**Which phase:** All modules (idempotency requirement)

**Warning signs:**
- Duplicate log entries on second run
- No `[SKIP]` messages in output
- Operations always execute regardless of current state

---

## PITFALL-10: Rollback Manifest Race Condition

**What went wrong:**
```
# Module 1 writes rollback entry
# Module 2 writes rollback entry
# Concurrent writes corrupt JSON manifest
```

**Root cause:** Multiple modules writing to same JSON file without synchronization.

**Detection:** Corrupted rollback manifest (invalid JSON).

**Prevention:**
1. Use `Save-RollbackEntry` helper for all writes
2. Helper must: read existing manifest → append entry → write entire manifest
3. PowerShell single-threaded execution prevents race condition in practice
4. For safety, modules run sequentially, not parallel

**Which phase:** All modules (rollback architecture)

**Warning signs:**
- Multiple modules modifying system simultaneously
- JSON parse errors in rollback manifest

---

## Pitfall Summary Table

| Pitfall | Severity | Phase | Detection Method |
|---------|----------|-------|------------------|
| Execution Policy Override | High | Entry Point | Catch `ExecutionPolicyOverride` exception |
| Modern Standby S0 | High | Power Plan | Check `PlatformAoAcOverride` registry key |
| Locale Power Failures | High | Power Plan, Scheduler | Test on Turkish/German Windows |
| TrustedInstaller ACL | Medium | File System | Catch `SecurityException` |
| OEM Reassertion | Medium | Power Plan | Check for OEM services, test after reboot |
| WSL LOCAL_SYSTEM | Low | VirtStack | Avoid `wsl.exe`; use WMI only |
| Backtick Continuation | Medium | All phases | Code review: ban backticks |
| Protected Services | Critical | Services | Hardcoded blocklist validation |
| Non-Idempotent Ops | Low | All modules | Run twice; expect all `[SKIP]` |
| Rollback Race | Low | All modules | Sequential module execution only |

---

## Prevention Strategies by Development Phase

### Phase 1: Core Scripting
- PITFALL-07 (Backtick ban): Code review rule
- PITFALL-08 (Protected services): Hardcoded blocklist in service config
- PITFALL-09 (Idempotency): State check before modification pattern

### Phase 2: Safety Mechanisms
- PITFALL-01 (Execution policy): Process-scope bypass in entry point
- PITFALL-04 (TrustedInstaller): `Take-RegistryOwnership` helper
- PITFALL-06 (WSL LOCAL_SYSTEM): WMI-only in `Test-VirtStack`
- PITFALL-10 (Rollback race): Sequential execution enforced

### Phase 3: CLI Polish
- PITFALL-02 (S0 detection): `PlatformAoAcOverride` check in Power Plan module
- PITFALL-03 (Locale GUIDs): `Get-ActivePlanGuid` regex extractor used everywhere
- PITFALL-05 (OEM reassertion): Service detection + scheduled task countermeasure

### Testing: All Phases
- PITFALL-03 (Locale): Test on Turkish, German Windows builds
- PITFALL-09 (Idempotency): Run full script twice; expect zero changes on second run

---
*Pitfalls synthesized from WinOptimizer PRD Section 1*
*Confidence: Critical — All errors encountered in real-world deployments*
