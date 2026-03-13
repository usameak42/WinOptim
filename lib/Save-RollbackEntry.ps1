#Requires -Version 5.1

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
    Author: WinOptimizer Project
    Version: 1.0.0
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
            Module    = $global:CurrentModule
            Type      = $Type
            Target    = $Target
            Timestamp = Get-Date -Format "o"
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
        $manifest = @($manifest) + @($entry)
        $manifest | ConvertTo-Json -Depth 10 | Set-Content -Path $global:RollbackPath
        #endregion

        return $true
    }
    catch {
        Write-Error "Failed to save rollback entry: $_"
        return $false
    }
}
