#Requires -Version 5.1

<#
.SYNOPSIS
    Optimizes Windows services for reduced background overhead

.DESCRIPTION
    Disables telemetry services, sets background services to Manual startup, validates
    protected services remain untouched. All changes are recorded to rollback manifest.
#>

function Invoke-ServiceOptimize {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    begin {
        # Dot-source lib helpers
        . $PSScriptRoot\..\lib\Write-OptLog.ps1
        . $PSScriptRoot\..\lib\Save-RollbackEntry.ps1

        # Initialize counters
        $successCount = 0
        $skipCount = 0
        $warningCount = 0
        $errorCount = 0
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        # SRVC-03: Protected services blocklist (must never be touched)
        $protectedServices = @('HvHost', 'vmms', 'WslService', 'LxssManager', 'VmCompute')
        $protectedWildcard = @('vmic*')

        # Validate config file exists
        $configPath = "$PSScriptRoot\..\config\services.json"
        if (-not (Test-Path $configPath)) {
            Write-Host "[ERROR] Config file not found: $configPath" -ForegroundColor Red
            return $false
        }
    }

    process {
        #region Stage 1: Protected Service Validation
        Write-Host "[INFO] Validating service configuration..." -ForegroundColor Cyan

        # Load service lists from config
        try {
            $config = Get-Content $configPath | ConvertFrom-Json
            $disabledList = $config.disabled
            $manualList = $config.manual
        }
        catch {
            Write-Host "[ERROR] Failed to load config/services.json: $_" -ForegroundColor Red
            return $false
        }

        # CRITICAL: Validate no protected services in disabled list
        $configProtectedViolations = @()
        foreach ($serviceEntry in $disabledList) {
            $serviceName = $serviceEntry.name

            # Check exact match
            if ($protectedServices -contains $serviceName) {
                $configProtectedViolations += "Disabled list contains protected service: $serviceName"
            }

            # Check wildcard match
            foreach ($wildcard in $protectedWildcard) {
                if ($serviceName -like $wildcard) {
                    $configProtectedViolations += "Disabled list contains protected service pattern: $serviceName matches $wildcard"
                }
            }
        }

        # CRITICAL: Validate no protected services in manual list
        foreach ($serviceEntry in $manualList) {
            $serviceName = $serviceEntry.name

            # Check exact match
            if ($protectedServices -contains $serviceName) {
                $configProtectedViolations += "Manual list contains protected service: $serviceName"
            }

            # Check wildcard match
            foreach ($wildcard in $protectedWildcard) {
                if ($serviceName -like $wildcard) {
                    $configProtectedViolations += "Manual list contains protected service pattern: $serviceName matches $wildcard"
                }
            }
        }

        # Fail-fast if config contains protected services
        if ($configProtectedViolations.Count -gt 0) {
            Write-Host "[ERROR] Protected service validation failed:" -ForegroundColor Red
            foreach ($violation in $configProtectedViolations) {
                Write-Host "  - $violation" -ForegroundColor Red
            }
            Write-Host "[ERROR] Cannot proceed. Protected services must never be modified." -ForegroundColor Red

            Write-OptLog -Module "Invoke-ServiceOptimize" `
                -Operation "Validate-Config" `
                -Target "config/services.json" `
                -Values @{ Violations = $configProtectedViolations } `
                -Result "Error" `
                -Message "Config validation failed - protected services in service lists" `
                -Level "ERROR"

            return $false
        }

        Write-Host "[SUCCESS] Service configuration validated - no protected services in modification lists" -ForegroundColor Green

        Write-OptLog -Module "Invoke-ServiceOptimize" `
            -Operation "Validate-Config" `
            -Target "config/services.json" `
            -Values @{ DisabledCount = $disabledList.Count; ManualCount = $manualList.Count } `
            -Result "Success" `
            -Message "Config validation passed" `
            -Level "SUCCESS"
        #endregion

        #region Stage 2: Disable Telemetry Services (SRVC-01)
        Write-Host "`n[ACTION] Disabling telemetry and unnecessary services..." -ForegroundColor Cyan

        foreach ($serviceEntry in $disabledList) {
            $serviceName = $serviceEntry.name

            # CRITICAL: Protected service check (already validated in config, but double-check)
            if ($protectedServices -contains $serviceName) {
                Write-Host "[ERROR] $serviceName is a protected virtualization service. Cannot disable." -ForegroundColor Red
                $errorCount++
                continue
            }

            # Check for wildcard match (e.g., vmic*)
            foreach ($wildcard in $protectedWildcard) {
                if ($serviceName -like $wildcard) {
                    Write-Host "[ERROR] $serviceName matches protected pattern $wildcard. Cannot disable." -ForegroundColor Red
                    $errorCount++
                    continue
                }
            }

            # SRVC-05: Gracefully skip services not found
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

            if ($null -eq $service) {
                Write-Host "[SKIP] Service '$serviceName' not found on this system" -ForegroundColor Gray

                Write-OptLog -Module "Invoke-ServiceOptimize" `
                    -Operation "Get-Service" `
                    -Target $serviceName `
                    -Values @{} `
                    -Result "Skip" `
                    -Message "Service not found on this system" `
                    -Level "SKIP"

                $skipCount++
                continue
            }

            # CONTEXT: Service Checks - Check StartType + running state for idempotency
            $currentStartType = (Get-WmiObject -Class Win32_Service -Filter "Name='$serviceName'" -ErrorAction SilentlyContinue).StartMode
            $currentStatus = $service.Status

            if ($currentStartType -eq 'Disabled') {
                if ($currentStatus -eq 'Stopped') {
                    # Both StartType and status match desired state
                    Write-Host "[SKIP] Service '$serviceName' already disabled and stopped" -ForegroundColor Gray

                    Write-OptLog -Module "Invoke-ServiceOptimize" `
                        -Operation "Get-Service" `
                        -Target $serviceName `
                        -Values @{ StartType = $currentStartType; Status = $currentStatus } `
                        -Result "Skip" `
                        -Message "Service already in desired state" `
                        -Level "SKIP"

                    $skipCount++
                    continue
                }
                else {
                    # CONTEXT: Service State Mismatch - StartType matches but service still running
                    Write-Host "[WARNING] Service '$serviceName' disabled but still running ($currentStatus)" -ForegroundColor Yellow

                    Write-OptLog -Module "Invoke-ServiceOptimize" `
                        -Operation "Get-Service" `
                        -Target $serviceName `
                        -Values @{ StartType = $currentStartType; Status = $currentStatus } `
                        -Result "Warning" `
                        -Message "Service disabled but still running" `
                        -Level "WARNING"

                    $warningCount++
                }
            }

            # CONTEXT: Service Disable Failures - Prompt user to continue or halt per service
            Write-Host "[ACTION] Disabling service: $serviceName" -ForegroundColor Cyan
            $continue = Read-Host -Prompt "Disable this service? (Y/N/A for All)"

            if ($continue -ne 'Y' -and $continue -ne 'y' -and $continue -ne 'A' -and $continue -ne 'a') {
                Write-Host "[SKIP] User chose to skip $serviceName" -ForegroundColor Gray
                $skipCount++
                continue
            }

            # SRVC-04: Log prior StartType of each service for rollback
            # Save rollback entry BEFORE modification (QUAL-02 requirement)
            Save-RollbackEntry -Type "Service" `
                -Target $serviceName `
                -OriginalStartType $currentStartType

            # Attempt to stop service if running
            if ($service.Status -ne 'Stopped') {
                try {
                    Stop-Service -Name $serviceName -Force -ErrorAction Stop
                    Write-Host "[SUCCESS] Stopped service $serviceName" -ForegroundColor Green
                }
                catch {
                    # CONTEXT: Service Stop Timeout - Prompt user to force kill or skip
                    Write-Host "[ERROR] Failed to stop ${serviceName}: $_" -ForegroundColor Red
                    $forceKill = Read-Host -Prompt "Force kill service process? (Y/N)"
                    if ($forceKill -eq 'Y' -or $forceKill -eq 'y') {
                        # Force kill logic using Stop-Process
                        try {
                            $process = Get-WmiObject Win32_Service -Filter "Name='$serviceName'" | ForEach-Object { $_.ProcessId }
                            if ($process) {
                                Stop-Process -Id $process -Force -ErrorAction Stop
                                Write-Host "[SUCCESS] Force-killed service process for $serviceName" -ForegroundColor Green
                            }
                        }
                        catch {
                            Write-Host "[ERROR] Failed to force kill ${serviceName}: $_" -ForegroundColor Red
                            $errorCount++
                            continue
                        }
                    }
                    else {
                        $errorCount++
                        continue
                    }
                }
            }

            # Disable service
            try {
                Set-Service -Name $serviceName -StartupType Disabled -ErrorAction Stop
                Write-Host "[SUCCESS] Disabled service $serviceName" -ForegroundColor Green

                Write-OptLog -Module "Invoke-ServiceOptimize" `
                    -Operation "Set-Service" `
                    -Target $serviceName `
                    -Values @{ OldStartType = $currentStartType; NewStartType = 'Disabled' } `
                    -Result "Success" `
                    -Message "Service disabled successfully" `
                    -Level "SUCCESS"

                $successCount++
            }
            catch {
                # CONTEXT: Service Disable Failures - Prompt user to continue or halt
                Write-Host "[ERROR] Failed to disable ${serviceName}: $_" -ForegroundColor Red

                Write-OptLog -Module "Invoke-ServiceOptimize" `
                    -Operation "Set-Service" `
                    -Target $serviceName `
                    -Values @{ Error = $_.Exception.Message } `
                    -Result "Error" `
                    -Message "Failed to disable service" `
                    -Level "ERROR"

                $continue = Read-Host -Prompt "Continue with remaining services? (Y/N)"
                if ($continue -ne 'Y' -and $continue -ne 'y') {
                    Write-Host "[INFO] Halting per user choice" -ForegroundColor Cyan
                    break
                }
                $errorCount++
            }
        }
        #endregion

        #region Stage 3: Set Background Services to Manual (SRVC-02)
        Write-Host "`n[ACTION] Setting background services to Manual startup..." -ForegroundColor Cyan

        foreach ($serviceEntry in $manualList) {
            $serviceName = $serviceEntry.name

            # CRITICAL: Protected service check
            if ($protectedServices -contains $serviceName) {
                Write-Host "[ERROR] $serviceName is a protected virtualization service. Cannot modify." -ForegroundColor Red
                $errorCount++
                continue
            }

            # Check wildcard match
            foreach ($wildcard in $protectedWildcard) {
                if ($serviceName -like $wildcard) {
                    Write-Host "[ERROR] $serviceName matches protected pattern $wildcard. Cannot modify." -ForegroundColor Red
                    $errorCount++
                    continue
                }
            }

            # SRVC-05: Gracefully skip services not found
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

            if ($null -eq $service) {
                Write-Host "[SKIP] Service '$serviceName' not found on this system" -ForegroundColor Gray

                Write-OptLog -Module "Invoke-ServiceOptimize" `
                    -Operation "Get-Service" `
                    -Target $serviceName `
                    -Values @{} `
                    -Result "Skip" `
                    -Message "Service not found on this system" `
                    -Level "SKIP"

                $skipCount++
                continue
            }

            # Check current state for idempotency
            $currentStartType = (Get-WmiObject -Class Win32_Service -Filter "Name='$serviceName'" -ErrorAction SilentlyContinue).StartMode
            $currentStatus = $service.Status

            if ($currentStartType -eq 'Manual') {
                # StartType already matches desired state
                Write-Host "[SKIP] Service '$serviceName' already set to Manual" -ForegroundColor Gray

                Write-OptLog -Module "Invoke-ServiceOptimize" `
                    -Operation "Get-Service" `
                    -Target $serviceName `
                    -Values @{ StartType = $currentStartType; Status = $currentStatus } `
                    -Result "Skip" `
                    -Message "Service already in desired state" `
                    -Level "SKIP"

                $skipCount++
                continue
            }

            # User prompt (optional, less critical for Manual startup)
            Write-Host "[ACTION] Setting service to Manual: $serviceName" -ForegroundColor Cyan

            # SRVC-04: Save rollback entry BEFORE modification
            Save-RollbackEntry -Type "Service" `
                -Target $serviceName `
                -OriginalStartType $currentStartType

            # Set service to Manual
            try {
                Set-Service -Name $serviceName -StartupType Manual -ErrorAction Stop
                Write-Host "[SUCCESS] Set $serviceName to Manual startup" -ForegroundColor Green

                Write-OptLog -Module "Invoke-ServiceOptimize" `
                    -Operation "Set-Service" `
                    -Target $serviceName `
                    -Values @{ OldStartType = $currentStartType; NewStartType = 'Manual' } `
                    -Result "Success" `
                    -Message "Service set to Manual startup" `
                    -Level "SUCCESS"

                $successCount++
            }
            catch {
                Write-Host "[ERROR] Failed to set $serviceName to Manual: $_" -ForegroundColor Red

                Write-OptLog -Module "Invoke-ServiceOptimize" `
                    -Operation "Set-Service" `
                    -Target $serviceName `
                    -Values @{ Error = $_.Exception.Message } `
                    -Result "Error" `
                    -Message "Failed to set service to Manual" `
                    -Level "ERROR"

                $continue = Read-Host -Prompt "Continue with remaining services? (Y/N)"
                if ($continue -ne 'Y' -and $continue -ne 'y') {
                    Write-Host "[INFO] Halting per user choice" -ForegroundColor Cyan
                    break
                }
                $errorCount++
            }
        }
        #endregion

        #region Stage 4: Service Rollback Data (SRVC-04)
        # SRVC-04: Prior service StartType values are saved to rollback manifest
        # Rollback entries are created in Stages 2 and 3 before each Set-Service call
        # The rollback manifest will be used by Invoke-Rollback to restore original StartType values
        #endregion

        #region Summary Display
        # Summary is displayed in end block for timing accuracy
        #endregion
    }

    end {
        $stopwatch.Stop()

        Write-Host "`n=== Service Optimization Summary ===" -ForegroundColor Cyan
        Write-Host "Successful: $successCount | Skipped: $skipCount | Warnings: $warningCount | Errors: $errorCount" -ForegroundColor White
        Write-Host "Elapsed Time: $($stopwatch.Elapsed.ToString('mm\:ss'))" -ForegroundColor White

        if ($errorCount -gt 0) {
            Write-Host "[WARNING] Errors occurred during service optimization. Review log for details." -ForegroundColor Yellow
        }

        if ($warningCount -gt 0) {
            Write-Host "[INFO] Warnings occurred. Some services may require attention." -ForegroundColor Cyan
        }

        return $errorCount -eq 0
    }
}
