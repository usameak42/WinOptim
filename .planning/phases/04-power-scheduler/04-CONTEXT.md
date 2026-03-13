# Phase 4: Power & Scheduler - Context

**Gathered:** 2026-03-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Implement two optimization modules:
1. **Invoke-PowerPlanConfig** - Modern Standby (S0) detection/override, Ultimate Performance plan creation/duplication, PCIe/USB power settings, OEM power service detection and countermeasures
2. **Invoke-SchedulerOptimize** - Win32PrioritySeparation tuning (38 = variable quanta, short intervals, 3x foreground boost), CPU core parking disablement, processor state configuration (100% min/max), network adapter interrupt moderation

Both modules include complete rollback integration, JSONL logging, and idempotency checks.

</domain>

<decisions>
## Implementation Decisions

### Modern Standby Handling (S0)

- **Detection → Action**: When Modern Standby (S0) is detected via `PlatformAoAcOverride` registry key, **prompt user first** before applying fix. Explain the S0 issue and ask whether to apply `PlatformAoAcOverride = 0` or skip.
- **Reboot timing**: After applying S0 fix, **prompt user** for reboot timing ("Reboot now?" or "Reboot later?")
- **S0 not present**: **Skip silently** - no S0-related messages if Modern Standby is not detected (legacy S3 or desktop systems)
- **Rollback behavior**: **Restore to default** - remove the `PlatformAoAcOverride` key entirely on rollback, returning to system default behavior

### Power Plan Strategy

- **Plan creation**: **Duplicate and rename** - duplicate hidden Ultimate Performance plan, apply custom name to avoid OEM GUID collisions
- **Naming scheme**: Use **"WinOptimizer Ultimate"** as the plan name (clear, branded, indicates source and purpose)
- **Duplicate handling**: If plan with target name exists from previous run, **prompt user** with options: Reuse existing / Delete and recreate / Cancel
- **PCIe/USB settings**: Configure **both together** - PCIe Link State Power Management (Off) and USB Selective Suspend (Disabled) as part of power plan module, no separate prompts
- **Activation timing**: **Activate immediately** after creation/duplication
- **Ultimate Performance missing**: If Ultimate Performance source GUID doesn't exist (some editions hide it), **fall back to High Performance** plan with warning logged
- **Settings verification**: **Verify and report** - read back registry values after activation, confirm success or show WARNING if mismatch
- **AC vs Battery**: Apply processor state settings (100% min/max) to **AC power only** - preserve battery life on laptops

### OEM Countermeasures

- **Detection method**: **Check all known** - iterate through all known OEM services in config (ASUS Armory Crate, Lenovo Vantage, Dell Command, HP Omen), detect which are present
- **Service handling**: When OEM power service detected, **prompt to disable** with information about what changes if user agrees
- **Scheduled task creation**: **Ask user** if they want scheduled task created at login (to counter OEM power plan reassertion), with explanation of what changes
- **Task behavior**: **Verify and reapply, notify** - check if WinOptimizer Ultimate plan is still active at login, reapply if different; show notification if no changes were needed

### CPU Scheduler Tuning

- **Win32PrioritySeparation**: Value **38** means: variable quanta + short intervals + 3x foreground boost (foreground apps get 3x more CPU time than background)
  - **Prompt user**: Explain what Win32PrioritySeparation=38 does, then ask whether to apply it
- **CPU core parking**: **Explain then prompt** - first explain what CPU parking is (OS putting cores to sleep to save power), then ask user to choose:
  - Disable parking on **all cores** (maximum responsiveness)
  - Disable parking on **logical cores only** (explain: HyperThreading/SMT cores, keeps physical cores flexible)
  - **AC power only** (disable only when plugged in, allow parking on battery)
  - **No disabling** (skip core parking changes entirely)
- **Network interrupt moderation**: **Detect and prompt** - detect network adapters, ask user about interrupt moderation settings per adapter
- **Rollback safety**: **Restore original** - restore exact original values captured before modification
- **Powercfg approach**: Use **hardcoded GUIDs** for processor state settings (locale-safe, consistent)
- **Validation after apply**: **Verify registry** - read back registry values after applying scheduler settings, report mismatches as WARNING
- **Plan scope**: **Plan-specific only** - scheduler settings apply only to WinOptimizer Ultimate plan, other plans keep their defaults

### Claude's Discretion

- **Missing GUID keys**: If a processor power setting GUID key doesn't exist in registry (some systems omit certain settings), choose appropriate handling:
  - **Recommended**: Skip with WARNING (log that key was missing, continue with other settings)
  - **Alternative**: Create the missing registry key with desired value (more aggressive)
  - Choose based on how critical the setting is for overall optimization goals

</decisions>

<specifics>
## Specific Ideas

- **S0 explanation context**: Modern Standby (S0) is like smartphone sleep — system stays partially active for background tasks. This suppresses Ultimate Performance plan. The `PlatformAoAcOverride = 0` fix forces legacy S3 sleep behavior, allowing high-performance plans to activate.
- **CPU parking explanation**: "CPU parking" is Windows putting CPU cores to sleep to save power. Disabling parking keeps all cores awake and ready to respond immediately, improving responsiveness at cost of power efficiency.
- **Logical cores explanation**: "Logical cores" are HyperThreading/SMT sibling cores — the extra execution threads Intel/AMD add to physical CPU cores. Disabling parking on logical cores only keeps physical cores flexible for power management while ensuring HT threads are always available.
- **OEM service behavior**: OEM power services (ASUS Armory Crate, Lenovo Vantage, etc.) frequently reassert OEM power plans at boot/login. The scheduled task countermeasure reactivates WinOptimizer Ultimate plan after OEM interference.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope (Power & Scheduler optimization modules only).

</deferred>

---

*Phase: 04-power-scheduler*
*Context gathered: 2026-03-14*
