---
created: 2026-03-14T00:59:12.951Z
title: Fix PowerShell variable syntax error across all scripts
area: scripts
files:
  - **/*.ps1
---

## Problem

PowerShell parser errors occur due to incorrect variable reference syntax inside double-quoted strings. The pattern `"[TEXT] $variableName: $_"` causes PowerShell to interpret `$variableName:` as a single variable reference instead of `$variableName` followed by literal `: $_`.

Error message:
```
Variable reference is not valid. ':' was not followed by a valid variable name character.
```

## Solution

Search all `.ps1` files for the pattern `$variableName: $_` inside Write-Host statements and similar strings. Replace with `${variableName}: $_` by wrapping the variable name in curly braces.

Common variables to check: `$serviceName`, `$taskName`, `$regPath`, `$regValue`, etc.

Before:
```powershell
Write-Host "[ERROR] Failed to stop $serviceName: $_" -ForegroundColor Red
```

After:
```powershell
Write-Host "[ERROR] Failed to stop ${serviceName}: $_" -ForegroundColor Red
```

Steps:
1. Grep/search for pattern `: $_"` in all .ps1 files
2. Identify each file and line number
3. Replace `$variableName: $_` with `${variableName}: $_`
4. Verify fixes with PowerShell syntax validation
