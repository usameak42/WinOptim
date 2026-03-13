# Research Summary: WinOptimizer PS1

**Domain:** Windows 11 PowerShell Optimization Toolkit
**Research Date:** 2025-03-13
**Source:** PRD Sections 1-3 (real-world deployment artifacts)

---

## Key Findings

### Stack
- **PowerShell 5.1+** (Windows 11 bundled)
- **No third-party dependencies** — pure Windows scripting
- **Critical constraint:** Locale-safe operations (hardcoded GUIDs, regex extraction)
- **Safety mechanism:** Process-scope execution policy bypass only

### Table Stakes Features
What users expect from any Windows optimization tool:
- Execution policy handling
- Elevation with self-relaunch
- System Restore Point creation (halts on failure)
- Telemetry suppression (DiagTrack, AutoLogger)
- Complete rollback capability
- Structured JSONL logging
- Idempotent operations

### Differentiators
What makes WinOptimizer PS1 unique:
- **Virtualization Safety** — WSL2/Hyper-V validated via WMI (never wsl.exe from elevated context)
- **Locale-Safe Power Plans** — Regex GUID extraction; hardcoded subgroup/setting GUIDs
- **OEM Countermeasures** — Detect Armory Crate, Lenovo Vantage, Dell Command; scheduled task to reassert power plan
- **Modern Standby Detection** — Detect S0 via PlatformAoAcOverride; apply fix before Ultimate Performance plan
- **TrustedInstaller ACL Helper** — Programmatic ownership transfer for Windows Search keys
- **Protected Services Block** — Hardcoded blocklist; HvHost, vmms, WslService never touched
- **Developer-First** — Optimizes low-latency desktop without breaking dev toolchains

### Architecture
```
Entry Point (WinOptimizer.ps1)
    ↓
├── lib/ (5 shared helpers)
├── modules/ (7 independent modules)
├── config/services.json (extensible service lists)
└── %TEMP%\WinOptimizer/ (logs, rollback manifests)
```

**Build order:**
1. Libraries (helpers)
2. Simple modules (Telemetry, Services)
3. Complex modules (Power Plan, Scheduler)
4. I/O optimization (File System)
5. GPU optimization
6. Rollback (last)
7. Entry point (orchestration)

### Watch Out For

**Critical Pitfalls:**
1. **Modern Standby (S0)** — Hides Ultimate Performance plan; must detect and fix before power plan operations
2. **Locale powercfg aliases** — Fail on non-English Windows; use hardcoded GUIDs only
3. **Protected services** — Never touch HvHost, vmms, WslService, LxssManager, VmCompute, vmic*
4. **TrustedInstaller ACL** — Windows Search keys require ownership transfer before modification
5. **OEM power reassertion** — ASUS/Lenovo/Dell/HP services override power plan at boot; create scheduled task countermeasure
6. **WSL LOCAL_SYSTEM error** — Never call wsl.exe from elevated context; use WMI only
7. **Backtick continuation** — Banned from codebase; causes parsing failures

**Detection Strategies:**
- S0: Check `HKLM:\System\CurrentControlSet\Control\Power\PlatformAoAcOverride`
- Locale: Test on Turkish/German Windows builds
- Protected services: Hardcoded blocklist validation
- TrustedInstaller: Catch `SecurityException`
- OEM services: Check for ArmouryCrate.Service, LenovoVantage, DellCommandCenter

**Prevention Strategies:**
- Use regex GUID extraction for all powercfg operations
- Implement `Take-RegistryOwnership` helper for TrustedInstaller keys
- Implement `Test-VirtStack` using WMI only (no wsl.exe)
- Hardcoded protected services blocklist enforced in all modules
- Check current state before modifying (idempotency)
- Ban backtick line continuation; use splatting `@{}`

---

## Implementation Considerations

### Estimated Scope
- **~950 lines** of PowerShell code
- **7 modules** (average ~135 lines each)
- **5 library helpers** (average ~20 lines each)
- **Entry point** (~150 lines)

### Riskiest Modules
1. **Module 4 (Power Plan)** — S0 detection, OEM detection, scheduled task creation, may require reboot
2. **Module 3 (Scheduler)** — Locale-sensitive powercfg operations, hardcoded GUIDs
3. **Module 7 (Rollback)** — Manifest parsing, reverse-order restoration

### Quality Gates
- **QG-01 Idempotency** — Run twice; second run must produce zero changes (all [SKIP])
- **QG-02 Rollback Integrity** — Apply modules, rollback, verify all values restored
- **QG-03 Virtualization Safety** — Confirm Docker, WSL2, Hyper-V work after full execution
- **QG-04 OEM Compatibility** — Test on ASUS, Lenovo, Dell laptops
- **QG-05 Locale Safety** — Test on Turkish, German Windows 11
- **QG-06 Modern Standby** — Confirm S0 detection works on both S0 and S3 firmware
- **QG-07 Silent Mode** — Run `-Silent -RunAll`; confirm all modules execute without prompts

---

## Next Steps

1. **Requirements Definition** — Translate PRD modules into scoped v1 requirements
2. **Roadmap Creation** — Break implementation into phases (per PRD Section 3.4)
3. **Phase 1 Planning** — Detailed plan for core scripting and modularity

---

**Research Files:**
- `STACK.md` — Technology stack, hardcoded GUIDs, constraints
- `FEATURES.md` — Table stakes, differentiators, anti-features, module breakdown
- `ARCHITECTURE.md` — Component boundaries, data flow, build order
- `PITFALLS.md` — 10 critical pitfalls with detection/prevention strategies

**Confidence Level:** High — All research based on real-world Windows 11 optimization deployments documented in PRD Section 1.

---
*Research complete: 2025-03-13*
*Synthesized from WinOptimizer PRD*
