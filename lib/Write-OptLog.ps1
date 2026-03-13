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
