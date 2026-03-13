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

        #region Stage 2: Disable Telemetry Services
        # Implemented in Task 2
        #endregion

        #region Stage 3: Set Background Services to Manual
        # Implemented in Task 2
        #endregion

        #region Stage 4: Service Rollback Data
        # SRVC-04: Prior service StartType values are saved to rollback manifest
        # Rollback entries are created in Stages 2 and 3 before each Set-Service call
        # The rollback manifest will be used by Invoke-Rollback to restore original StartType values
        #endregion

        #region Summary Display
        # Implemented in Task 2
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
