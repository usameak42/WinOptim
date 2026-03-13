#Requires -Version 5.1

<#
.SYNOPSIS
    Creates a System Restore Point before optimization modules execute.

.DESCRIPTION
    The Invoke-RestorePointCreation function creates a named System Restore Point
    to provide a safety net before any system modifications. The function checks
    for recent restore points within the last hour to avoid unnecessary duplicates,
    warns if the most recent point is over 24 hours old, and handles creation
    failures gracefully with user prompts. All operations are logged via Write-OptLog
    and restore point metadata is added to the rollback manifest.

.PARAMETER RestorePointName
    The descriptive name for the System Restore Point. Defaults to
    "WinOptimizer-Before-Optimization-YYYYMMDD" format.

.EXAMPLE
    Invoke-RestorePointCreation

.EXAMPLE
    Invoke-RestorePointCreation -RestorePointName "WinOptimizer-Custom-Name"

.NOTES
    Must be called BEFORE any optimization modules execute.
    Even in silent mode, prompts user on restore point creation failure (safety-critical).
    Author: WinOptimizer Project
    Version: 1.0.0
#>
function Invoke-RestorePointCreation {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$RestorePointName = "WinOptimizer-Before-Optimization-$(Get-Date -Format 'yyyyMMdd')"
    )

    begin {
        # Initialize - no setup required
    }

    process {
        try {
            #region Stage 1: Check for Recent Restore Points (Within 1 Hour)
            Write-Verbose "Checking for recent restore points within last hour..."

            try {
                $restorePoints = Get-ComputerRestorePoint |
                    Sort-Object CreationTime -Descending

                if ($null -ne $restorePoints -and $restorePoints.Count -gt 0) {
                    $recentPoint = $restorePoints |
                        Where-Object { $_.CreationTime -gt (Get-Date).AddHours(-1) } |
                        Select-Object -First 1

                    if ($null -ne $recentPoint) {
                        Write-Host "[SKIP] Recent restore point found: $($recentPoint.Description) (created $($recentPoint.CreationTime))" -ForegroundColor Cyan

                        Write-OptLog -Module "SafetyGates" `
                            -Operation "RestorePointCheck" `
                            -Target "SystemRestore" `
                            -Values @{
                                RecentPoint = $recentPoint.Description
                                Created = $recentPoint.CreationTime.ToString("o")
                            } `
                            -Result "Skip" `
                            -Message "Recent restore point exists, skipping creation" `
                            -Level "SKIP"

                        return $true
                    }
                }
            }
            catch {
                Write-Host "[WARNING] Could not query restore point history: $_" -ForegroundColor Yellow
                Write-OptLog -Module "SafetyGates" `
                    -Operation "RestorePointCheck" `
                    -Target "SystemRestore" `
                    -Values @{
                        Error = $_.Exception.Message
                    } `
                    -Result "Warning" `
                    -Message "Failed to query restore point history" `
                    -Level "WARNING"
            }
            #endregion

            #region Stage 2: Check for Old Restore Point (> 24 Hours)
            Write-Verbose "Checking for old restore points (> 24 hours)..."

            try {
                if ($null -ne $restorePoints -and $restorePoints.Count -gt 0) {
                    $oldPoint = $restorePoints |
                        Where-Object { $_.CreationTime -gt (Get-Date).AddHours(-24) } |
                        Select-Object -First 1

                    if ($null -ne $oldPoint) {
                        $ageHours = ((Get-Date) - $oldPoint.CreationTime).TotalHours
                        Write-Host "[WARNING] Most recent restore point is $($ageHours.ToString('F0')) hours old." -ForegroundColor Yellow

                        Write-OptLog -Module "SafetyGates" `
                            -Operation "RestorePointCheck" `
                            -Target "SystemRestore" `
                            -Values @{
                                RecentPoint = $oldPoint.Description
                                AgeHours = $ageHours.ToString('F0')
                            } `
                            -Result "Warning" `
                            -Message "Most recent restore point is old" `
                            -Level "WARNING"
                    }
                }
            }
            catch {
                Write-Verbose "Could not check restore point age: $_"
            }
            #endregion

            #region Stage 3: Create New Restore Point
            Write-Host "[ACTION] Creating System Restore Point: $RestorePointName" -ForegroundColor Cyan
            Write-Host "This may take 10-30 seconds..." -ForegroundColor Gray

            try {
                Checkpoint-Computer -Description $RestorePointName -RestorePointType MODIFY_SETTINGS -ErrorAction Stop

                Write-Host "[SUCCESS] System Restore Point created successfully" -ForegroundColor Green

                Write-OptLog -Module "SafetyGates" `
                    -Operation "RestorePointCreate" `
                    -Target "SystemRestore" `
                    -Values @{
                        RestorePointName = $RestorePointName
                        RestorePointType = "MODIFY_SETTINGS"
                    } `
                    -Result "Success" `
                    -Message "System Restore Point created" `
                    -Level "SUCCESS"

                # Update rollback manifest
                if ($null -eq $global:RollbackData) {
                    $global:RollbackData = @{}
                }

                $global:RollbackData.RestorePoint = @{
                    Name = $RestorePointName
                    Timestamp = Get-Date -Format "o"
                }

                return $true
            }
            catch {
                Write-Host "[ERROR] Failed to create System Restore Point: $_" -ForegroundColor Red

                Write-OptLog -Module "SafetyGates" `
                    -Operation "RestorePointCreate" `
                    -Target "SystemRestore" `
                    -Values @{
                        RestorePointName = $RestorePointName
                        Error = $_.Exception.Message
                    } `
                    -Result "Error" `
                    -Message "System Restore Point creation failed" `
                    -Level "ERROR"

                # CRITICAL: Even in silent mode, prompt user for safety-critical failure
                $continue = Read-Host -Prompt "Restore Point creation failed. Continue anyway? (Y/N)"

                if ($continue -ne 'Y' -and $continue -ne 'y') {
                    Write-OptLog -Module "SafetyGates" `
                        -Operation "RestorePointCreate" `
                        -Target "SystemRestore" `
                        -Values @{
                            Error = $_.Exception.Message
                        } `
                        -Result "Error" `
                        -Message "User chose to exit after restore point failure" `
                        -Level "ERROR"

                    exit 1
                }

                Write-OptLog -Module "SafetyGates" `
                    -Operation "RestorePointCreate" `
                    -Target "SystemRestore" `
                    -Values @{
                        Error = $_.Exception.Message
                    } `
                    -Result "Warning" `
                    -Message "User chose to continue despite restore point failure" `
                    -Level "WARNING"

                return $true
            }
            #endregion
        }
        catch {
            Write-Error "Unexpected error in Invoke-RestorePointCreation: $_"
            return $false
        }
    }

    end {
        # Cleanup - no resources to release
    }
}
