#Requires -Version 5.1

<#
.SYNOPSIS
    Disables Windows telemetry data collection

.DESCRIPTION
    Suppresses telemetry by disabling services, AutoLogger sessions, scheduled tasks, and registry settings.
    All changes are recorded to rollback manifest for complete reversibility.
#>

function Invoke-TelemetryBlock {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Dot-source lib helpers
    . $PSScriptRoot\..\lib\Write-OptLog.ps1
    . $PSScriptRoot\..\lib\Save-RollbackEntry.ps1

    begin {
        # Initialize counters
        $successCount = 0
        $skipCount = 0
        $warningCount = 0
        $errorCount = 0
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        # Set current module for rollback entries
        $global:CurrentModule = "Invoke-TelemetryBlock"

        Write-Host "`n=== Telemetry Suppression Module ===" -ForegroundColor Cyan
        Write-Host "This module disables Windows telemetry data collection." -ForegroundColor White
        Write-Host "All changes will be recorded for rollback." -ForegroundColor White

        $confirmation = Read-Host -Prompt "`nProceed with telemetry suppression? (Y/N)"
        if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
            Write-Host "[SKIP] User cancelled telemetry suppression" -ForegroundColor Gray
            return $false
        }
    }

    process {
        #region Stage 1: Registry Telemetry Settings
        Write-Host "`n[Stage 1] Configuring registry telemetry settings..." -ForegroundColor Cyan

        $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
        $valueName = "AllowTelemetry"
        $desiredValue = 0

        try {
            # Check current state for idempotency
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
            }
            else {
                # Save rollback entry BEFORE modification
                $originalValue = if ($null -ne $currentValue) { $currentValue.$valueName } else { $null }
                Save-RollbackEntry -Type "Registry" `
                    -Target $regPath `
                    -ValueName $valueName `
                    -OriginalData $originalValue `
                    -OriginalType "REG_DWORD"

                # Set registry value
                Set-ItemProperty -Path $regPath -Name $valueName -Value $desiredValue -Type DWord -ErrorAction Stop

                Write-Host "[SUCCESS] Set AllowTelemetry to $desiredValue" -ForegroundColor Green

                Write-OptLog -Module "Invoke-TelemetryBlock" `
                    -Operation "Set-ItemProperty" `
                    -Target "$regPath\$valueName" `
                    -Values @{ OldValue = $originalValue; NewValue = $desiredValue } `
                    -Result "Success" `
                    -Message "Telemetry capped at Security level" `
                    -Level "SUCCESS"

                $successCount++
            }
        }
        catch {
            if ($_.Exception.Message -like "*Access Denied*") {
                Write-Host "[WARNING] Access denied to registry key: $_" -ForegroundColor Yellow

                Write-OptLog -Module "Invoke-TelemetryBlock" `
                    -Operation "Set-ItemProperty" `
                    -Target "$regPath\$valueName" `
                    -Values @{ Error = $_.Exception.Message } `
                    -Result "Warning" `
                    -Message "Access denied to registry key" `
                    -Level "WARNING"

                $warningCount++
            }
            else {
                Write-Host "[ERROR] Failed to set AllowTelemetry: $_" -ForegroundColor Red

                Write-OptLog -Module "Invoke-TelemetryBlock" `
                    -Operation "Set-ItemProperty" `
                    -Target "$regPath\$valueName" `
                    -Values @{ Error = $_.Exception.Message } `
                    -Result "Error" `
                    -Message "Failed to set registry value" `
                    -Level "ERROR"

                $errorCount++
            }
        }
        #endregion

        #region Stage 2: AutoLogger Sessions (Placeholder - Task 2)
        #endregion

        #region Stage 3: Telemetry Services (Placeholder - Task 2)
        #endregion

        #region Stage 4: Scheduled Tasks (Placeholder - Task 2)
        #endregion

        #region Summary Display (Placeholder - Task 2)
        #endregion
    }

    end {
        $stopwatch.Stop()

        Write-Host "`n=== Telemetry Suppression Summary ===" -ForegroundColor Cyan
        Write-Host "Successful: $successCount | Skipped: $skipCount | Warnings: $warningCount | Errors: $errorCount" -ForegroundColor White
        Write-Host "Elapsed Time: $($stopwatch.Elapsed.ToString('mm\:ss'))" -ForegroundColor White

        if ($errorCount -gt 0) {
            Write-Host "[WARNING] Errors occurred during telemetry suppression. Review log for details." -ForegroundColor Yellow
        }

        return $errorCount -eq 0
    }
}
