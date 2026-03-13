#Requires -Version 5.1

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
    Author: WinOptimizer Project
    Version: 1.0.0
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
