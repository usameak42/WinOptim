# Phase 1: Foundation & Libraries - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish repository structure, create reusable library helpers, and prepare configuration infrastructure. This phase builds the foundation that all subsequent phases depend on: the file/directory scaffold, 5 library helper functions (logging, rollback, GUID extraction, permissions, virtualization checks), and the services configuration file.

</domain>

<decisions>
## Implementation Decisions

### Library Function Design
- **Return values:** Boolean `$true`/`$false` for success/failure
- **Complex data parameters:** Use hashtable parameters for structured data (e.g., `Write-OptLog -Properties @{...}`)
- **Comment-based help:** Full help blocks for all library functions (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`)

### Logging Strategy
- **Log fields:** Rich field set — Timestamp, Module, Operation, Target, Values (before/after), Result, Message, Level
- **Format:** JSONL (one JSON object per line) for easy parsing and review

### Service.json Structure
- **Schema:** Rich metadata format with nested categories
  - `disabled: [{name, reason}]`
  - `manual: [{name, reason}]`
  - `oem: {vendor: [{name, displayName, detectionPattern}]}`
- **OEM entries:** Full metadata including vendor name, service display name, and detection pattern (registry key or WMI query)
- **User extensibility:** Include `custom` or `other` section for user-added services; document how to extend

### Repository Organization
- **Module file naming:** Short names (e.g., `TelemetryBlock.ps1`, `GpuDwmOptimize.ps1`)
- **Inline comments:** Minimal — only for complex operations

### Claude's Discretion
- Function signature strictness and parameter validation — follow PowerShell best practices and each function's specific needs
- Error handling approach — balance safety with PowerShell conventions (non-terminating errors where appropriate)
- Log levels — choose appropriate levels for the use case (DEBUG/INFO/SUCCESS/WARNING/ERROR/SKIP)
- Log rotation strategy — based on typical usage patterns
- Log file location — balance security and usability needs
- #region/#endregion block organization — based on code complexity and logical grouping
- JSON schema for services.json — based on tooling and validation needs

</decisions>

<specifics>
## Specific Ideas

No specific requirements or references provided — open to standard PowerShell and repository best practices.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within Phase 1 scope (foundation and library helpers only; individual optimization modules are later phases).

</deferred>

---

*Phase: 01-foundation-libraries*
*Context gathered: 2026-03-13*
