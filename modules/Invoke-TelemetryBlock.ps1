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
        # Initialize logging paths
        $tempDir = Join-Path -Path $env:TEMP -ChildPath "WinOptimizer"
        if (-not (Test-Path -Path $tempDir)) {
            New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        }
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $global:LogPath = Join-Path -Path $tempDir -ChildPath "WinOptimizer-${timestamp}.jsonl"
        $global:RollbackPath = Join-Path -Path $tempDir -ChildPath "Rollback.jsonl"

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

        #region Stage 2: AutoLogger Sessions
        Write-Host "`n[Stage 2] Disabling AutoLogger ETW sessions..." -ForegroundColor Cyan

        $autoLoggerSessions = @(
            'AutoLogger-Diagtrack-Listener',
            'DiagLog',
            'SQMLogger'
        )

        foreach ($sessionName in $autoLoggerSessions) {
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\AutoLogger\$sessionName"
            $valueName = "Start"
            $desiredValue = 0

            try {
                # Check current state for idempotency
                $currentValue = Get-ItemProperty -Path $regPath -Name $valueName -ErrorAction SilentlyContinue

                if ($null -ne $currentValue -and $currentValue.$valueName -eq $desiredValue) {
                    Write-Host "[SKIP] AutoLogger session '$sessionName' already disabled" -ForegroundColor Gray

                    Write-OptLog -Module "Invoke-TelemetryBlock" `
                        -Operation "Get-ItemProperty" `
                        -Target "$regPath\$valueName" `
                        -Values @{ SessionName = $sessionName; CurrentValue = $currentValue.$valueName } `
                        -Result "Skip" `
                        -Message "AutoLogger session already disabled" `
                        -Level "SKIP"

                    $skipCount++
                    continue
                }

                # Save rollback entry BEFORE modification
                $originalValue = if ($null -ne $currentValue) { $currentValue.$valueName } else { $null }
                Save-RollbackEntry -Type "Registry" `
                    -Target $regPath `
                    -ValueName $valueName `
                    -OriginalData $originalValue `
                    -OriginalType "REG_DWORD"

                # Disable AutoLogger session
                Set-ItemProperty -Path $regPath -Name $valueName -Value $desiredValue -Type DWord -ErrorAction Stop

                Write-Host "[SUCCESS] Disabled AutoLogger session '$sessionName'" -ForegroundColor Green

                Write-OptLog -Module "Invoke-TelemetryBlock" `
                    -Operation "Set-ItemProperty" `
                    -Target "$regPath\$valueName" `
                    -Values @{ SessionName = $sessionName; OldValue = $originalValue; NewValue = $desiredValue } `
                    -Result "Success" `
                    -Message "AutoLogger session disabled" `
                    -Level "SUCCESS"

                $successCount++
            }
            catch {
                Write-Host "[WARNING] Failed to disable AutoLogger session '$sessionName': $_" -ForegroundColor Yellow

                Write-OptLog -Module "Invoke-TelemetryBlock" `
                    -Operation "Set-ItemProperty" `
                    -Target "$regPath\$valueName" `
                    -Values @{ SessionName = $sessionName; Error = $_.Exception.Message } `
                    -Result "Warning" `
                    -Message "Failed to disable AutoLogger session" `
                    -Level "WARNING"

                $warningCount++
                continue
            }
        }
        #endregion

        #region Stage 3: Telemetry Services
        Write-Host "`n[Stage 3] Disabling telemetry services..." -ForegroundColor Cyan

        # Load services from config
        $config = Get-Content "$PSScriptRoot\..\config\services.json" | ConvertFrom-Json
        $telemetryServices = $config.disabled | Where-Object { $_.name -like 'DiagTrack' -or $_.name -like 'dmwappushservice' }

        foreach ($serviceEntry in $telemetryServices) {
            $serviceName = $serviceEntry.name

            # Get service
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

            if ($null -eq $service) {
                Write-Host "[SKIP] Service '$serviceName' not found on this system" -ForegroundColor Gray

                Write-OptLog -Module "Invoke-TelemetryBlock" `
                    -Operation "Get-Service" `
                    -Target $serviceName `
                    -Values @{} `
                    -Result "Skip" `
                    -Message "Service not found" `
                    -Level "SKIP"

                $skipCount++
                continue
            }

            # Check current state for idempotency
            $currentStartType = (Get-WmiObject -Class Win32_Service -Filter "Name='$serviceName'").StartMode
            $currentStatus = $service.Status

            if ($currentStartType -eq 'Disabled' -and $currentStatus -eq 'Stopped') {
                Write-Host "[SKIP] Service '$serviceName' already disabled and stopped" -ForegroundColor Gray

                Write-OptLog -Module "Invoke-TelemetryBlock" `
                    -Operation "Get-Service" `
                    -Target $serviceName `
                    -Values @{ StartMode = $currentStartType; Status = $currentStatus } `
                    -Result "Skip" `
                    -Message "Service already disabled and stopped" `
                    -Level "SKIP"

                $skipCount++
                continue
            }

            # Check for state mismatch
            if ($currentStartType -eq 'Disabled' -and $currentStatus -ne 'Stopped') {
                Write-Host "[WARNING] Service '$serviceName' disabled but still running ($currentStatus)" -ForegroundColor Yellow

                Write-OptLog -Module "Invoke-TelemetryBlock" `
                    -Operation "Get-Service" `
                    -Target $serviceName `
                    -Values @{ StartMode = $currentStartType; Status = $currentStatus } `
                    -Result "Warning" `
                    -Message "Service state mismatch: disabled but running" `
                    -Level "WARNING"

                $warningCount++
            }

            # Prompt user per CONTEXT decision
            Write-Host "[ACTION] Disabling service: $serviceName" -ForegroundColor Cyan
            $continue = Read-Host -Prompt "Disable this service? (Y/N/A for All)"

            if ($continue -ne 'Y' -and $continue -ne 'y' -and $continue -ne 'A' -and $continue -ne 'a') {
                Write-Host "[SKIP] User chose to skip $serviceName" -ForegroundColor Gray
                $skipCount++
                continue
            }

            # Save rollback entry BEFORE modification
            Save-RollbackEntry -Type "Service" `
                -Target $serviceName `
                -OriginalStartType $currentStartType

            # Stop service if running
            if ($service.Status -ne 'Stopped') {
                try {
                    Stop-Service -Name $serviceName -Force -ErrorAction Stop
                    Write-Host "[SUCCESS] Stopped service $serviceName" -ForegroundColor Green
                }
                catch {
                    Write-Host "[ERROR] Failed to stop ${serviceName}: $_" -ForegroundColor Red

                    # CONTEXT: Service stop timeout - prompt user
                    $forceKill = Read-Host -Prompt "Force kill service process? (Y/N)"
                    if ($forceKill -eq 'Y' -or $forceKill -eq 'y') {
                        try {
                            $process = Get-WmiObject Win32_Process | Where-Object { $_.CommandLine -like "*$serviceName*" }
                            if ($null -ne $process) {
                                $process.Terminate() | Out-Null
                                Write-Host "[SUCCESS] Force killed service $serviceName" -ForegroundColor Green
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

                Write-OptLog -Module "Invoke-TelemetryBlock" `
                    -Operation "Set-Service" `
                    -Target $serviceName `
                    -Values @{ OldStartType = $currentStartType; NewStartType = 'Disabled' } `
                    -Result "Success" `
                    -Message "Service disabled successfully" `
                    -Level "SUCCESS"

                $successCount++
            }
            catch {
                Write-Host "[ERROR] Failed to disable ${serviceName}: $_" -ForegroundColor Red

                Write-OptLog -Module "Invoke-TelemetryBlock" `
                    -Operation "Set-Service" `
                    -Target $serviceName `
                    -Values @{ Error = $_.Exception.Message } `
                    -Result "Error" `
                    -Message "Failed to disable service" `
                    -Level "ERROR"

                $errorCount++

                # CONTEXT: Service disable failures - prompt user
                $continue = Read-Host -Prompt "Continue with remaining services? (Y/N)"
                if ($continue -ne 'Y' -and $continue -ne 'y') {
                    break
                }
            }
        }
        #endregion

        #region Stage 4: Scheduled Tasks
        Write-Host "`n[Stage 4] Disabling telemetry scheduled tasks..." -ForegroundColor Cyan

        # Prompt user for strategy per CONTEXT decision
        Write-Host "`n[Scheduled Task Handling Strategy]" -ForegroundColor Cyan
        Write-Host "1. Disable only: Sets State=0, fully reversible" -ForegroundColor White
        Write-Host "2. Delete task: Removes task, cleaner but irreversible" -ForegroundColor White
        Write-Host "3. Hybrid: Disable custom tasks, delete system telemetry tasks" -ForegroundColor White

        $strategy = Read-Host -Prompt "Choose strategy (1/2/3)"

        $tasks = @(
            @{ Name = 'CompatibilityAppraiser'; Path = '\Microsoft\Windows\Application Experience\CompatibilityAppraiser' },
            @{ Name = 'ProgramDataUpdater'; Path = '\Microsoft\Windows\Application Experience\ProgramDataUpdater' },
            @{ Name = 'Consolidator'; Path = '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator' },
            @{ Name = 'UsbCeip'; Path = '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip' }
        )

        foreach ($task in $tasks) {
            $taskName = $task.Name
            $taskPath = $task.Path

            try {
                $scheduledTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

                if ($null -eq $scheduledTask) {
                    Write-Host "[SKIP] Task '$taskName' not found" -ForegroundColor Gray
                    $skipCount++
                    continue
                }

                # CONTEXT: Task Checks - Check State + Enabled property
                $currentState = $scheduledTask.State
                $currentEnabled = $scheduledTask.Enabled

                if ($currentState -eq 'Disabled' -and -not $currentEnabled) {
                    Write-Host "[INFO] Task '$taskName' already disabled, confirming..." -ForegroundColor Cyan
                }

                # CONTEXT: System vs Custom - Distinguish by task author/creator
                $taskAuthor = $scheduledTask.Author
                $isSystemTask = $taskAuthor -like '*Microsoft*' -or $taskPath -like '*\Microsoft\Windows\*'

                # Apply strategy
                if ($strategy -eq '1') {
                    # Disable only
                    $parentPath = Split-Path $taskPath
                    Disable-ScheduledTask -TaskName $taskName -TaskPath $parentPath -ErrorAction Stop

                    # Save rollback entry
                    Save-RollbackEntry -Type "ScheduledTask" `
                        -Target $taskPath `
                        -ValueName "State" `
                        -OriginalData $currentState `
                        -OriginalType "TaskState"

                    Write-Host "[SUCCESS] Disabled task '$taskName'" -ForegroundColor Green
                    $successCount++

                }
                elseif ($strategy -eq '2') {
                    # Delete task
                    Unregister-ScheduledTask -TaskName $taskName -TaskPath (Split-Path $taskPath) -Confirm:$false -ErrorAction Stop

                    # Save rollback entry
                    Save-RollbackEntry -Type "ScheduledTask" `
                        -Target $taskPath `
                        -ValueName "TaskDefinition" `
                        -OriginalData ($scheduledTask.TaskDefinition.OuterXml) `
                        -OriginalType "TaskXml"

                    Write-Host "[SUCCESS] Deleted task '$taskName'" -ForegroundColor Green
                    $successCount++

                }
                elseif ($strategy -eq '3') {
                    # Hybrid
                    if ($isSystemTask) {
                        # Delete system telemetry tasks
                        Unregister-ScheduledTask -TaskName $taskName -TaskPath (Split-Path $taskPath) -Confirm:$false -ErrorAction Stop

                        Save-RollbackEntry -Type "ScheduledTask" `
                            -Target $taskPath `
                            -ValueName "TaskDefinition" `
                            -OriginalData ($scheduledTask.TaskDefinition.OuterXml) `
                            -OriginalType "TaskXml"

                        Write-Host "[SUCCESS] Deleted system task '$taskName'" -ForegroundColor Green
                    }
                    else {
                        # Disable custom tasks
                        $parentPath = Split-Path $taskPath
                        Disable-ScheduledTask -TaskName $taskName -TaskPath $parentPath -ErrorAction Stop

                        Save-RollbackEntry -Type "ScheduledTask" `
                            -Target $taskPath `
                            -ValueName "State" `
                            -OriginalData $currentState `
                            -OriginalType "TaskState"

                        Write-Host "[SUCCESS] Disabled custom task '$taskName'" -ForegroundColor Green
                    }
                    $successCount++
                }

                Write-OptLog -Module "Invoke-TelemetryBlock" `
                    -Operation "Disable-ScheduledTask" `
                    -Target $taskPath `
                    -Values @{ TaskName = $taskName; Strategy = $strategy; IsSystemTask = $isSystemTask } `
                    -Result "Success" `
                    -Message "Scheduled task processed" `
                    -Level "SUCCESS"

            }
            catch {
                Write-Host "[ERROR] Failed to process task '$taskName': $_" -ForegroundColor Red

                Write-OptLog -Module "Invoke-TelemetryBlock" `
                    -Operation "Disable-ScheduledTask" `
                    -Target $taskPath `
                    -Values @{ TaskName = $taskName; Error = $_.Exception.Message } `
                    -Result "Error" `
                    -Message "Failed to process scheduled task" `
                    -Level "ERROR"

                $errorCount++
                continue
            }
        }

        # CONTEXT: Scheduled Task Failures - List failed tasks at end
        if ($errorCount -gt 0) {
            Write-Host "`n[WARNING] Failed to process $errorCount task(s). Review log for details." -ForegroundColor Yellow
        }
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
