#Requires -Version 5.1

<#
.SYNOPSIS
    Optimizes CPU scheduler for foreground responsiveness and disables core parking.

.DESCRIPTION
    The Invoke-SchedulerOptimize function tunes Windows CPU scheduler behavior through
    Win32PrioritySeparation adjustment, CPU core parking disablement, and processor
    state configuration. All changes are logged to JSONL and recorded in the rollback
    manifest for complete reversibility.

.PARAMETER None
    This function accepts no parameters.

.EXAMPLE
    $result = Invoke-SchedulerOptimize

.NOTES
    Uses hardcoded GUIDs for all power settings (locale-safe).
    User prompts for Win32PrioritySeparation and core parking options.
    Author: WinOptimizer Project
    Version: 1.0.0
#>
function Invoke-SchedulerOptimize {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    #region Dot-source Library Helpers
    . $PSScriptRoot\..\lib\Write-OptLog.ps1
    . $PSScriptRoot\..\lib\Save-RollbackEntry.ps1
    . $PSScriptRoot\..\lib\Get-ActivePlanGuid.ps1
    #endregion

    #region Initialize Counters and Stopwatch
    $successCount = 0
    $skipCount = 0
    $warningCount = 0
    $errorCount = 0
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $global:CurrentModule = "Invoke-SchedulerOptimize"
    #endregion

    #region Module Header
    Write-Host "`n" -NoNewline
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "SCHEDULER OPTIMIZATION MODULE" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "Tuning CPU scheduler for maximum foreground responsiveness" -ForegroundColor White
    Write-Host ""
    #endregion

    #region Stage 1: Win32PrioritySeparation Tuning (SCHD-01)
    Write-Host "[Stage 1/4] Win32PrioritySeparation Tuning" -ForegroundColor Cyan
    Write-Host "-------------------------------------------" -ForegroundColor Cyan

    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
    $valueName = "Win32PrioritySeparation"
    $desiredValue = 38

    Write-Host "`n[INFO] Win32PrioritySeparation=38 Configuration:" -ForegroundColor Cyan
    Write-Host "Value 38 enables:" -ForegroundColor White
    Write-Host "  - Variable quanta (dynamic CPU time allocation)" -ForegroundColor White
    Write-Host "  - Short intervals (faster context switching)" -ForegroundColor White
    Write-Host "  - 3x foreground boost (foreground apps get 3x more CPU time)" -ForegroundColor White
    Write-Host "Result: Improved foreground application responsiveness`n" -ForegroundColor Green

    $userChoice = Read-Host "Apply Win32PrioritySeparation=38? (Y/N)"

    if ($userChoice -eq 'Y' -or $userChoice -eq 'y') {
        try {
            #region Check Current Value
            $currentValue = Get-ItemProperty -Path $regPath -Name $valueName -ErrorAction SilentlyContinue

            #region Idempotency Check
            if ($null -ne $currentValue -and $currentValue.$valueName -eq $desiredValue) {
                Write-Host "[SKIP] Win32PrioritySeparation already set to $desiredValue" -ForegroundColor Gray
                Write-OptLog -Module $global:CurrentModule -Operation "Get-ItemProperty" -Target $regPath -Values @{ CurrentValue = $currentValue.$valueName; DesiredValue = $desiredValue } -Result "Skip" -Message "Win32PrioritySeparation already at desired value" -Level "SKIP"
                $skipCount++
            }
            else {
                #region Save Original Value
                $originalValue = if ($null -ne $currentValue) { $currentValue.$valueName } else { $null }
                Save-RollbackEntry -Type "Registry" -Target $regPath -ValueName $valueName -OriginalData $originalValue -OriginalType "REG_DWORD"
                #endregion

                #region Apply New Value
                Set-ItemProperty -Path $regPath -Name $valueName -Value $desiredValue -Type DWord -ErrorAction Stop

                #region Verify Change
                $newValue = Get-ItemProperty -Path $regPath -Name $valueName -ErrorAction Stop

                if ($newValue.$valueName -eq $desiredValue) {
                    Write-Host "[SUCCESS] Set Win32PrioritySeparation to $desiredValue" -ForegroundColor Green
                    Write-OptLog -Module $global:CurrentModule -Operation "Set-ItemProperty" -Target "$regPath\$valueName" -Values @{ OldValue = $originalValue; NewValue = $desiredValue } -Result "Success" -Message "Win32PrioritySeparation set to $desiredValue" -Level "SUCCESS"
                    $successCount++
                }
                else {
                    Write-Host "[WARNING] Win32PrioritySeparation value mismatch after set" -ForegroundColor Yellow
                    Write-OptLog -Module $global:CurrentModule -Operation "Set-ItemProperty" -Target "$regPath\$valueName" -Values @{ ExpectedValue = $desiredValue; ActualValue = $newValue.$valueName } -Result "Warning" -Message "Value verification failed" -Level "WARNING"
                    $warningCount++
                }
                #endregion
            }
            #endregion
        }
        catch {
            Write-Host "[ERROR] Failed to set Win32PrioritySeparation: $_" -ForegroundColor Red
            Write-OptLog -Module $global:CurrentModule -Operation "Set-ItemProperty" -Target "$regPath\$valueName" -Values @{ DesiredValue = $desiredValue } -Result "Error" -Message $_.Exception.Message -Level "ERROR"
            $errorCount++
        }
    }
    else {
        Write-Host "[SKIP] User declined Win32PrioritySeparation tuning" -ForegroundColor Gray
        Write-OptLog -Module $global:CurrentModule -Operation "User Prompt" -Target "$regPath\$valueName" -Values @{ DesiredValue = $desiredValue } -Result "Skip" -Message "User declined Win32PrioritySeparation tuning" -Level "SKIP"
        $skipCount++
    }
    #endregion

    #region Stage 2: CPU Core Parking Disablement (SCHD-03)
    Write-Host "`n[Stage 2/4] CPU Core Parking Disablement" -ForegroundColor Cyan
    Write-Host "-------------------------------------------" -ForegroundColor Cyan

    #region Hardcoded GUIDs for Processor Power Settings
    $processorSubGroup = "54533251-82be-4824-96c1-47b60b740d00"
    $coreParkingSetting = "0cc5b647-c1df-4637-891a-dec35c318583"
    #endregion

    $planGuid = Get-ActivePlanGuid

    if ($null -eq $planGuid) {
        Write-Host "[ERROR] Failed to retrieve active power plan GUID" -ForegroundColor Red
        Write-OptLog -Module $global:CurrentModule -Operation "Get-ActivePlanGuid" -Target "powercfg" -Values @{} -Result "Error" -Message "Failed to get active power plan" -Level "ERROR"
        $errorCount++
    }
    else {
        Write-Host "`n[INFO] CPU Parking Explanation:" -ForegroundColor Cyan
        Write-Host "CPU parking puts CPU cores to sleep to save power." -ForegroundColor White
        Write-Host "Disabling parking keeps all cores awake for maximum responsiveness." -ForegroundColor White
        Write-Host "Trade-off: Improved responsiveness at cost of power efficiency.`n" -ForegroundColor Yellow

        $userChoice = Read-Host "Disable parking on: All cores / Logical cores only / AC power only / Skip? (A/L/O/S)"

        #region Save Rollback Entry Before Applying
        try {
            $currentParkingValue = powercfg /query $planGuid $processorSubGroup $coreParkingSetting 2>&1
            if ($LASTEXITCODE -eq 0) {
                # Extract current value from powercfg output (last non-empty line)
                $currentParkingValue = ($currentParkingValue -split '\r?\n' | Where-Object { $_.Trim() -ne '' } | Select-Object -Last 1).Trim()
                Save-RollbackEntry -Type "Registry" -Target "$planGuid\$processorSubGroup" -ValueName $coreParkingSetting -OriginalData $currentParkingValue -OriginalType "REG_DWORD"
            }
        }
        catch {
            Write-Host "[WARNING] Failed to read current core parking value: $_" -ForegroundColor Yellow
            Write-OptLog -Module $global:CurrentModule -Operation "powercfg /query" -Target "$planGuid\$processorSubGroup\$coreParkingSetting" -Values @{} -Result "Warning" -Message "Failed to read current value" -Level "WARNING"
            $warningCount++
        }
        #endregion

        if ($userChoice -eq 'A' -or $userChoice -eq 'a') {
            #region Set to 100% (All cores)
            powercfg /setacvalueindex $planGuid $processorSubGroup $coreParkingSetting 100 | Out-Null

            if ($LASTEXITCODE -eq 0) {
                Write-Host "[SUCCESS] Disabled CPU core parking on all cores" -ForegroundColor Green
                Write-OptLog -Module $global:CurrentModule -Operation "powercfg /setacvalueindex" -Target "$planGuid\$processorSubGroup\$coreParkingSetting" -Values @{ ACValue = 100 } -Result "Success" -Message "Core parking disabled (all cores)" -Level "SUCCESS"
                $successCount++
            }
            else {
                #region Check if Registry Key Exists
                $registryKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\$processorSubGroup\$coreParkingSetting"
                if (-not (Test-Path $registryKeyPath)) {
                    Write-Host "[WARNING] CPU core parking key not found on this system" -ForegroundColor Yellow
                    Write-OptLog -Module $global:CurrentModule -Operation "Test-Path" -Target $registryKeyPath -Values @{} -Result "Warning" -Message "Registry key not found" -Level "WARNING"
                    $warningCount++
                }
                else {
                    Write-Host "[ERROR] Failed to disable CPU core parking: powercfg exit code $LASTEXITCODE" -ForegroundColor Red
                    Write-OptLog -Module $global:CurrentModule -Operation "powercfg /setacvalueindex" -Target "$planGuid\$processorSubGroup\$coreParkingSetting" -Values @{ DesiredValue = 100 } -Result "Error" -Message "powercfg failed with exit code $LASTEXITCODE" -Level "ERROR"
                    $errorCount++
                }
                #endregion
            }
            #endregion
        }
        elseif ($userChoice -eq 'L' -or $userChoice -eq 'l') {
            #region Set to 50% (Logical cores only)
            powercfg /setacvalueindex $planGuid $processorSubGroup $coreParkingSetting 50 | Out-Null

            if ($LASTEXITCODE -eq 0) {
                Write-Host "[SUCCESS] Disabled CPU core parking on logical cores only (50%)" -ForegroundColor Green
                Write-OptLog -Module $global:CurrentModule -Operation "powercfg /setacvalueindex" -Target "$planGuid\$processorSubGroup\$coreParkingSetting" -Values @{ ACValue = 50 } -Result "Success" -Message "Core parking disabled (logical cores)" -Level "SUCCESS"
                $successCount++
            }
            else {
                Write-Host "[ERROR] Failed to disable CPU core parking: powercfg exit code $LASTEXITCODE" -ForegroundColor Red
                Write-OptLog -Module $global:CurrentModule -Operation "powercfg /setacvalueindex" -Target "$planGuid\$processorSubGroup\$coreParkingSetting" -Values @{ DesiredValue = 50 } -Result "Error" -Message "powercfg failed with exit code $LASTEXITCODE" -Level "ERROR"
                $errorCount++
            }
            #endregion
        }
        elseif ($userChoice -eq 'O' -or $userChoice -eq 'o') {
            #region Set AC to 100%, DC to 0% (AC power only)
            powercfg /setacvalueindex $planGuid $processorSubGroup $coreParkingSetting 100 | Out-Null
            $acResult = $LASTEXITCODE

            powercfg /setdcvalueindex $planGuid $processorSubGroup $coreParkingSetting 0 | Out-Null
            $dcResult = $LASTEXITCODE

            if ($acResult -eq 0 -and $dcResult -eq 0) {
                Write-Host "[SUCCESS] Disabled CPU core parking on AC power only (100% AC, 0% DC)" -ForegroundColor Green
                Write-OptLog -Module $global:CurrentModule -Operation "powercfg /setacvalueindex" -Target "$planGuid\$processorSubGroup\$coreParkingSetting" -Values @{ ACValue = 100; DCValue = 0 } -Result "Success" -Message "Core parking disabled (AC only)" -Level "SUCCESS"
                $successCount++
            }
            else {
                Write-Host "[ERROR] Failed to disable CPU core parking: AC exit code $acResult, DC exit code $dcResult" -ForegroundColor Red
                Write-OptLog -Module $global:CurrentModule -Operation "powercfg /setacvalueindex" -Target "$planGuid\$processorSubGroup\$coreParkingSetting" -Values @{ ACValue = 100; DCValue = 0 } -Result "Error" -Message "powercfg failed with exit codes AC=$acResult, DC=$dcResult" -Level "ERROR"
                $errorCount++
            }
            #endregion
        }
        else {
            Write-Host "[SKIP] User declined CPU core parking changes" -ForegroundColor Gray
            Write-OptLog -Module $global:CurrentModule -Operation "User Prompt" -Target "$planGuid\$processorSubGroup\$coreParkingSetting" -Values @{} -Result "Skip" -Message "User declined core parking changes" -Level "SKIP"
            $skipCount++
        }
    }
    #endregion

    #region Stage 3: Processor State Configuration (SCHD-04)
    Write-Host "`n[Stage 3/4] Processor State Configuration" -ForegroundColor Cyan
    Write-Host "-------------------------------------------" -ForegroundColor Cyan

    #region Only execute if user didn't skip Stage 2
    if ($userChoice -ne 'S' -and $userChoice -ne 's' -and $null -ne $planGuid) {
        #region Hardcoded GUIDs for Processor State Settings
        $minProcessorState = "bc5038f7-23e0-4960-96da-33abaf5935ec"
        $maxProcessorState = "3b04d4fd-1cc7-4f23-ab1c-d1337819c4bb"
        #endregion

        #region Set Minimum Processor State to 100% on AC
        try {
            #region Save Rollback Entry
            $currentMinValue = powercfg /query $planGuid $processorSubGroup $minProcessorState 2>&1
            if ($LASTEXITCODE -eq 0) {
                $currentMinValue = ($currentMinValue -split '\r?\n' | Where-Object { $_.Trim() -ne '' } | Select-Object -Last 1).Trim()
                Save-RollbackEntry -Type "Registry" -Target "$planGuid\$processorSubGroup" -ValueName $minProcessorState -OriginalData $currentMinValue -OriginalType "REG_DWORD"
            }

            #region Apply 100% Minimum
            powercfg /setacvalueindex $planGuid $processorSubGroup $minProcessorState 100 | Out-Null

            if ($LASTEXITCODE -eq 0) {
                Write-Host "[SUCCESS] Set minimum processor state to 100% on AC" -ForegroundColor Green
                Write-OptLog -Module $global:CurrentModule -Operation "powercfg /setacvalueindex" -Target "$planGuid\$processorSubGroup\$minProcessorState" -Values @{ ACValue = 100 } -Result "Success" -Message "Min processor state set to 100% (AC)" -Level "SUCCESS"
                $successCount++
            }
            else {
                Write-Host "[ERROR] Failed to set minimum processor state: powercfg exit code $LASTEXITCODE" -ForegroundColor Red
                Write-OptLog -Module $global:CurrentModule -Operation "powercfg /setacvalueindex" -Target "$planGuid\$processorSubGroup\$minProcessorState" -Values @{ DesiredValue = 100 } -Result "Error" -Message "powercfg failed with exit code $LASTEXITCODE" -Level "ERROR"
                $errorCount++
            }
        }
        catch {
            Write-Host "[ERROR] Failed to set minimum processor state: $_" -ForegroundColor Red
            Write-OptLog -Module $global:CurrentModule -Operation "powercfg /setacvalueindex" -Target "$planGuid\$processorSubGroup\$minProcessorState" -Values @{ DesiredValue = 100 } -Result "Error" -Message $_.Exception.Message -Level "ERROR"
            $errorCount++
        }
        #endregion

        #region Set Maximum Processor State to 100% on AC
        try {
            #region Save Rollback Entry
            $currentMaxValue = powercfg /query $planGuid $processorSubGroup $maxProcessorState 2>&1
            if ($LASTEXITCODE -eq 0) {
                $currentMaxValue = ($currentMaxValue -split '\r?\n' | Where-Object { $_.Trim() -ne '' } | Select-Object -Last 1).Trim()
                Save-RollbackEntry -Type "Registry" -Target "$planGuid\$processorSubGroup" -ValueName $maxProcessorState -OriginalData $currentMaxValue -OriginalType "REG_DWORD"
            }

            #region Apply 100% Maximum
            powercfg /setacvalueindex $planGuid $processorSubGroup $maxProcessorState 100 | Out-Null

            if ($LASTEXITCODE -eq 0) {
                Write-Host "[SUCCESS] Set maximum processor state to 100% on AC" -ForegroundColor Green
                Write-OptLog -Module $global:CurrentModule -Operation "powercfg /setacvalueindex" -Target "$planGuid\$processorSubGroup\$maxProcessorState" -Values @{ ACValue = 100 } -Result "Success" -Message "Max processor state set to 100% (AC)" -Level "SUCCESS"
                $successCount++
            }
            else {
                Write-Host "[ERROR] Failed to set maximum processor state: powercfg exit code $LASTEXITCODE" -ForegroundColor Red
                Write-OptLog -Module $global:CurrentModule -Operation "powercfg /setacvalueindex" -Target "$planGuid\$processorSubGroup\$maxProcessorState" -Values @{ DesiredValue = 100 } -Result "Error" -Message "powercfg failed with exit code $LASTEXITCODE" -Level "ERROR"
                $errorCount++
            }
        }
        catch {
            Write-Host "[ERROR] Failed to set maximum processor state: $_" -ForegroundColor Red
            Write-OptLog -Module $global:CurrentModule -Operation "powercfg /setacvalueindex" -Target "$planGuid\$processorSubGroup\$maxProcessorState" -Values @{ DesiredValue = 100 } -Result "Error" -Message $_.Exception.Message -Level "ERROR"
            $errorCount++
        }
        #endregion

        #region Apply Power Settings
        powercfg /SetActive $planGuid | Out-Null

        if ($LASTEXITCODE -eq 0) {
            Write-Host "[SUCCESS] Applied power plan settings" -ForegroundColor Green
            Write-OptLog -Module $global:CurrentModule -Operation "powercfg /SetActive" -Target $planGuid -Values @{} -Result "Success" -Message "Power plan activated" -Level "SUCCESS"
            $successCount++
        }
        else {
            Write-Host "[WARNING] Failed to apply power plan: powercfg exit code $LASTEXITCODE" -ForegroundColor Yellow
            Write-OptLog -Module $global:CurrentModule -Operation "powercfg /SetActive" -Target $planGuid -Values @{} -Result "Warning" -Message "powercfg failed with exit code $LASTEXITCODE" -Level "WARNING"
            $warningCount++
        }
        #endregion
        #endregion
    }
    #endregion

    #region End Block: Display Summary
    $stopwatch.Stop()

    Write-Host "`n================================" -ForegroundColor Cyan
    Write-Host "SCHEDULER OPTIMIZATION SUMMARY" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "Success: $successCount | Skip: $skipCount | Warning: $warningCount | Error: $errorCount" -ForegroundColor White
    Write-Host "Elapsed Time: $($stopwatch.Elapsed.ToString('mm\:ss\.fff'))" -ForegroundColor White
    Write-Host ""

    if ($errorCount -eq 0) {
        Write-Host "[SUCCESS] Scheduler optimization completed successfully" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "[WARNING] Scheduler optimization completed with $errorCount error(s)" -ForegroundColor Yellow
        return $false
    }
    #endregion
}
