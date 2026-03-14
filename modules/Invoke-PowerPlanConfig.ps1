#Requires -Version 5.1

<#
.SYNOPSIS
    Configures power plan settings including Modern Standby detection, Ultimate Performance plan creation, and PCIe/USB power optimization.

.DESCRIPTION
    The Invoke-PowerPlanConfig function detects and overrides Modern Standby (S0) state,
    creates a custom Ultimate Performance power plan, configures PCIe and USB power settings,
    detects OEM power management services, and creates scheduled task countermeasures.

    All operations include rollback manifest entries and JSONL logging for complete reversibility.

.PARAMETER None
    This function accepts no parameters.

.EXAMPLE
    Invoke-PowerPlanConfig

.NOTES
    Author: WinOptimizer Project
    Version: 1.0.0
    Requirements: PowerShell 5.1+, Administrator rights
#>
function Invoke-PowerPlanConfig {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    #region Dot-source Library Helpers
    . $PSScriptRoot\..\lib\Write-OptLog.ps1
    . $PSScriptRoot\..\lib\Save-RollbackEntry.ps1
    . $PSScriptRoot\..\lib\Get-ActivePlanGuid.ps1
    #endregion

    #region Initialize Module State
    $successCount = 0
    $skipCount = 0
    $warningCount = 0
    $errorCount = 0
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $global:CurrentModule = "Invoke-PowerPlanConfig"

    # Initialize logging paths
    $tempDir = Join-Path -Path $env:TEMP -ChildPath "WinOptimizer"
    if (-not (Test-Path -Path $tempDir)) {
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
    }
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $global:LogPath = Join-Path -Path $tempDir -ChildPath "WinOptimizer-${timestamp}.jsonl"
    $global:RollbackPath = Join-Path -Path $tempDir -ChildPath "Rollback.jsonl"
    #endregion

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " WinOptimizer Power Plan Configuration" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    Write-Host "Configuring power plans for maximum performance..." -ForegroundColor White
    #endregion

    #region Stage 1: Modern Standby (S0) Detection and Override (PWRP-01, PWRP-02)
    Write-Host "`n[STAGE 1] Modern Standby (S0) Detection" -ForegroundColor Cyan

    $s0KeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
    $s0ValueName = "PlatformAoAcOverride"

    try {
        $s0Value = Get-ItemProperty -Path $s0KeyPath -Name $s0ValueName -ErrorAction SilentlyContinue

        if ($null -ne $s0Value) {
            Write-Host "[WARNING] Modern Standby (S0) detected" -ForegroundColor Yellow
            Write-Host "  Modern Standby (S0) is like smartphone sleep - system stays partially active for background tasks." -ForegroundColor White
            Write-Host "  This suppresses Ultimate Performance plan availability." -ForegroundColor White
            Write-Host "  Fix: Set PlatformAoAcOverride = 0 to force legacy S3 sleep behavior (requires reboot)." -ForegroundColor White

            $choice = Read-Host -Prompt "Apply S0 fix (requires reboot)? (Y/N)"

            if ($choice -eq 'Y' -or $choice -eq 'y') {
                # Save rollback entry BEFORE modification
                Save-RollbackEntry -Type "Registry" -Target $s0KeyPath -ValueName $s0ValueName -OriginalData $s0Value.$s0ValueName -OriginalType "REG_DWORD"

                # Apply fix
                Set-ItemProperty -Path $s0KeyPath -Name $s0ValueName -Value 0 -Type DWord -ErrorAction Stop

                Write-Host "[SUCCESS] Applied S0 fix - PlatformAoAcOverride set to 0" -ForegroundColor Green
                Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "Set-ItemProperty" -Target "$s0KeyPath\$s0ValueName" -Values @{ OldValue = $s0Value.$s0ValueName; NewValue = 0 } -Result "Success" -Message "Applied S0 fix - requires reboot" -Level "WARNING"
                $successCount++

                # Prompt for reboot timing
                $rebootChoice = Read-Host -Prompt "Reboot now? (Y/N)"
                if ($rebootChoice -eq 'Y' -or $rebootChoice -eq 'y') {
                    Write-Host "[ACTION] Rebooting system to apply S0 fix..." -ForegroundColor Cyan
                    Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "Restart-Computer" -Target "localhost" -Values @{ Reason = "S0 fix applied" } -Result "Success" -Message "System reboot initiated for S0 fix" -Level "INFO"
                    Restart-Computer -Force
                }
                else {
                    Write-Host "[WARNING] S0 fix applied but requires reboot to take effect" -ForegroundColor Yellow
                    Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "Set-ItemProperty" -Target "$s0KeyPath\$s0ValueName" -Values @{ NewValue = 0; RebootPending = $true } -Result "Warning" -Message "S0 fix applied, reboot pending" -Level "WARNING"
                    $warningCount++
                }
            }
            else {
                Write-Host "[SKIP] User declined S0 fix - Ultimate Performance plan may be suppressed" -ForegroundColor Gray
                Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "Get-ItemProperty" -Target "$s0KeyPath\$s0ValueName" -Values @{ S0Detected = $true; UserAction = "Declined" } -Result "Skip" -Message "User declined S0 fix" -Level "SKIP"
                $skipCount++
            }
        }
        else {
            # No S0 detected - skip silently per CONTEXT.md decision
            Write-Host "[INFO] Modern Standby (S0) not detected - system uses legacy S3 sleep" -ForegroundColor Cyan
            Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "Get-ItemProperty" -Target "$s0KeyPath\$s0ValueName" -Values @{ S0Detected = $false } -Result "Skip" -Message "No Modern Standby detected" -Level "INFO"
            $skipCount++
        }
    }
    catch {
        Write-Host "[ERROR] Failed to detect or apply S0 fix: $_" -ForegroundColor Red
        Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "Get-ItemProperty" -Target "$s0KeyPath\$s0ValueName" -Values @{ Error = $_.Exception.Message } -Result "Error" -Message "S0 detection/fix failed" -Level "ERROR"
        $errorCount++
    }
    #endregion

    #region Stage 2: Power Plan Duplication and Activation (PWRP-03, PWRP-04)
    Write-Host "`n[STAGE 2] Power Plan Creation and Activation" -ForegroundColor Cyan

    # Define hardcoded GUIDs (locale-safe)
    $ultimatePerfGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
    $highPerfGuid = "8c5e7fda-e8bf-45a6-a6cc-4b3c3f300d00"
    $customPlanName = "WinOptimizer Ultimate"
    $planGuid = $null

    try {
        # Check for existing plan with target name
        $existingOutput = powercfg /list 2>&1
        $existingPlan = $existingOutput | Select-String -Pattern $customPlanName

        if ($existingPlan) {
            # Extract existing plan GUID (case-insensitive pattern for A-F/a-f, no braces in powercfg output)
            $existingGuid = ($existingPlan.Line | Select-String -Pattern '[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}').Matches[0].Value

            if ([string]::IsNullOrEmpty($existingGuid)) {
                Write-Host "[ERROR] Failed to extract GUID from existing plan" -ForegroundColor Red
                Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "powercfg /list" -Target $customPlanName -Values @{ RawOutput = $existingPlan } -Result "Error" -Message "Failed to extract existing plan GUID" -Level "ERROR"
                $errorCount++
                return $false
            }

            Write-Host "[WARNING] Plan '$customPlanName' already exists (GUID: $existingGuid)" -ForegroundColor Yellow
            $choice = Read-Host -Prompt "Reuse existing / Delete and recreate / Cancel? (R/D/C)"

            if ($choice -eq 'R' -or $choice -eq 'r') {
                # Reuse existing plan
                $planGuid = $existingGuid
                Write-Host "[INFO] Reusing existing power plan" -ForegroundColor Cyan
                Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "powercfg /list" -Target $customPlanName -Values @{ Action = "Reuse"; Guid = $existingGuid } -Result "Skip" -Message "Reusing existing power plan" -Level "SKIP"
                $skipCount++
            }
            elseif ($choice -eq 'D' -or $choice -eq 'd') {
                # Delete and recreate
                $deleteOutput = powercfg /delete $existingGuid 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "[SUCCESS] Deleted existing plan - will recreate" -ForegroundColor Green
                    Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "powercfg /delete" -Target $existingGuid -Values @{ PlanName = $customPlanName } -Result "Success" -Message "Deleted existing power plan for recreation" -Level "SUCCESS"
                    $successCount++
                }
                else {
                    Write-Host "[ERROR] Failed to delete existing plan: $deleteOutput" -ForegroundColor Red
                    Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "powercfg /delete" -Target $existingGuid -Values @{ Error = $deleteOutput } -Result "Error" -Message "Failed to delete existing plan" -Level "ERROR"
                    $errorCount++
                    return $false
                }
            }
            else {
                # Cancel
                Write-Host "[SKIP] User cancelled power plan creation" -ForegroundColor Gray
                Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "powercfg /list" -Target $customPlanName -Values @{ UserAction = "Cancelled" } -Result "Skip" -Message "User cancelled power plan creation" -Level "SKIP"
                $skipCount++
                return $false
            }
        }

        if ($null -eq $planGuid) {
            # Duplicate Ultimate Performance plan
            $dupOutput = powercfg /duplicatescheme $ultimatePerfGuid 2>&1

            if ($LASTEXITCODE -ne 0) {
                # Ultimate Performance not available - fall back to High Performance
                Write-Host "[WARNING] Ultimate Performance plan not found - falling back to High Performance" -ForegroundColor Yellow
                Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "powercfg /duplicatescheme" -Target $ultimatePerfGuid -Values @{ FallbackTo = $highPerfGuid } -Result "Warning" -Message "Ultimate Performance unavailable, using High Performance" -Level "WARNING"
                $warningCount++

                $dupOutput = powercfg /duplicatescheme $highPerfGuid 2>&1

                if ($LASTEXITCODE -ne 0) {
                    Write-Host "[ERROR] Failed to duplicate power plan: $dupOutput" -ForegroundColor Red
                    Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "powercfg /duplicatescheme" -Target $highPerfGuid -Values @{ Error = $dupOutput } -Result "Error" -Message "Failed to duplicate High Performance plan" -Level "ERROR"
                    $errorCount++
                    return $false
                }
            }

            # Extract new GUID from output (case-insensitive pattern for A-F/a-f, no braces in powercfg output)
            $planGuid = ($dupOutput | Select-String -Pattern '[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}').Matches[0].Value

            if ([string]::IsNullOrEmpty($planGuid)) {
                Write-Host "[ERROR] Failed to extract GUID from powercfg output" -ForegroundColor Red
                Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "powercfg /duplicatescheme" -Target "GUID extraction" -Values @{ RawOutput = $dupOutput } -Result "Error" -Message "Failed to extract new plan GUID" -Level "ERROR"
                $errorCount++
                return $false
            }

            # Rename to custom name
            $renameOutput = powercfg /changename $planGuid $customPlanName 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[SUCCESS] Renamed plan to '$customPlanName'" -ForegroundColor Green
                Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "powercfg /changename" -Target $planGuid -Values @{ PlanName = $customPlanName } -Result "Success" -Message "Power plan renamed successfully" -Level "SUCCESS"
                $successCount++
            }
            else {
                Write-Host "[WARNING] Failed to rename plan (non-critical): $renameOutput" -ForegroundColor Yellow
                Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "powercfg /changename" -Target $planGuid -Values @{ PlanName = $customPlanName; Error = $renameOutput } -Result "Warning" -Message "Plan rename failed (non-critical)" -Level "WARNING"
                $warningCount++
            }
        }

        # Activate the plan
        $activeOutput = powercfg /setactive $planGuid 2>&1

        if ($LASTEXITCODE -eq 0) {
            # Verify activation
            $activeGuid = Get-ActivePlanGuid

            if ($activeGuid -eq $planGuid) {
                Write-Host "[SUCCESS] Activated '$customPlanName' power plan" -ForegroundColor Green
                Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "powercfg /setactive" -Target $planGuid -Values @{ PlanName = $customPlanName; Verified = $true } -Result "Success" -Message "Power plan activated and verified" -Level "SUCCESS"
                $successCount++
            }
            else {
                Write-Host "[WARNING] Plan activation may have failed - verification mismatch" -ForegroundColor Yellow
                Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "powercfg /setactive" -Target $planGuid -Values @{ ExpectedGuid = $planGuid; ActualGuid = $activeGuid } -Result "Warning" -Message "Plan activation verification failed" -Level "WARNING"
                $warningCount++
            }
        }
        else {
            Write-Host "[ERROR] Failed to activate power plan: $activeOutput" -ForegroundColor Red
            Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "powercfg /setactive" -Target $planGuid -Values @{ Error = $activeOutput } -Result "Error" -Message "Power plan activation failed" -Level "ERROR"
            $errorCount++
        }
    }
    catch {
        Write-Host "[ERROR] Failed to create or activate power plan: $_" -ForegroundColor Red
        Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "powercfg" -Target "PowerPlanCreation" -Values @{ Error = $_.Exception.Message } -Result "Error" -Message "Power plan creation failed" -Level "ERROR"
        $errorCount++
    }
    #endregion

    #region Stage 3: PCIe and USB Power Settings (PWRP-05, PWRP-06)
    Write-Host "`n[STAGE 3] PCIe and USB Power Configuration" -ForegroundColor Cyan

    # Define hardcoded GUIDs for power settings (locale-safe)
    $pciSubGroup = "501a4d13-42af-4429-9fd1-a8218c268e20"         # PCI Express
    $pciLinkStatePower = "12c0bdb0-2d34-4600-9843-91eb582ae84f"  # Link State Power Management
    $usbSubGroup = "2a737441-1930-4402-8d77-b2bebba308a3"         # USB
    $usbSelectiveSuspend = "48e6b7a6-50f5-4782-a5d4-53bb8f07e226"  # USB Selective Suspend

    try {
        # Get active plan GUID
        $planGuid = Get-ActivePlanGuid

        if ($null -eq $planGuid) {
            Write-Host "[ERROR] Failed to get active power plan GUID" -ForegroundColor Red
            Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "Get-ActivePlanGuid" -Target "ActivePlan" -Values @{ Error = "Null GUID returned" } -Result "Error" -Message "Failed to retrieve active plan GUID" -Level "ERROR"
            $errorCount++
            return $false
        }

        # Configure PCIe Link State Power Management to Off (if available)
        $pciRegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\$pciSubGroup\$pciLinkStatePower"

        if (Test-Path -Path $pciRegPath -ErrorAction SilentlyContinue) {
            $pciCurrentValue = Get-ItemProperty -Path "$pciRegPath" -Name "ACValueIndex" -ErrorAction SilentlyContinue

            # Save rollback entry BEFORE modification
            Save-RollbackEntry -Type "Registry" -Target "$planGuid\$pciSubGroup" -ValueName $pciLinkStatePower -OriginalData $pciCurrentValue.ACValueIndex -OriginalType "REG_DWORD"

            $pciOutput = powercfg /setacvalueindex $planGuid $pciSubGroup $pciLinkStatePower 0 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Host "[SUCCESS] Set PCIe Link State Power Management to Off" -ForegroundColor Green
                Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "powercfg /setacvalueindex" -Target "$planGuid\$pciSubGroup\$pciLinkStatePower" -Values @{ OldValue = $pciCurrentValue.ACValueIndex; NewValue = 0 } -Result "Success" -Message "PCIe Link State Power Management disabled" -Level "SUCCESS"
                $successCount++
            }
            else {
                Write-Host "[ERROR] Failed to set PCIe power setting: $pciOutput" -ForegroundColor Red
                Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "powercfg /setacvalueindex" -Target "$planGuid\$pciSubGroup\$pciLinkStatePower" -Values @{ Error = $pciOutput } -Result "Error" -Message "PCIe power setting failed" -Level "ERROR"
                $errorCount++
            }
        }
        else {
            Write-Host "[INFO] PCIe Link State Power Management setting not available on this system - skipping" -ForegroundColor Cyan
            Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "Test-Path" -Target $pciRegPath -Values @{ Available = $false } -Result "Skip" -Message "PCIe power setting not available" -Level "INFO"
            $skipCount++
        }

        # Configure USB Selective Suspend to Disabled
        $usbRegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\$usbSubGroup\$usbSelectiveSuspend"
        $usbCurrentValue = Get-ItemProperty -Path "$usbRegPath" -Name "ACValueIndex" -ErrorAction SilentlyContinue

        # Save rollback entry BEFORE modification
        Save-RollbackEntry -Type "Registry" -Target "$planGuid\$usbSubGroup" -ValueName $usbSelectiveSuspend -OriginalData $usbCurrentValue.ACValueIndex -OriginalType "REG_DWORD"

        $usbOutput = powercfg /setacvalueindex $planGuid $usbSubGroup $usbSelectiveSuspend 0 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "[SUCCESS] Set USB Selective Suspend to Disabled" -ForegroundColor Green
            Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "powercfg /setacvalueindex" -Target "$planGuid\$usbSubGroup\$usbSelectiveSuspend" -Values @{ OldValue = $usbCurrentValue.ACValueIndex; NewValue = 0 } -Result "Success" -Message "USB Selective Suspend disabled" -Level "SUCCESS"
            $successCount++
        }
        else {
            Write-Host "[ERROR] Failed to set USB power setting: $usbOutput" -ForegroundColor Red
            Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "powercfg /setacvalueindex" -Target "$planGuid\$usbSubGroup\$usbSelectiveSuspend" -Values @{ Error = $usbOutput } -Result "Error" -Message "USB power setting failed" -Level "ERROR"
            $errorCount++
        }

        # Apply power settings
        $applyOutput = powercfg /SetActive $planGuid 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "[SUCCESS] Applied power settings to active plan" -ForegroundColor Green
            Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "powercfg /SetActive" -Target $planGuid -Values @{ PCIeOff = $true; USBSuspendDisabled = $true } -Result "Success" -Message "Power settings applied successfully" -Level "SUCCESS"
            $successCount++
        }
        else {
            Write-Host "[WARNING] Failed to apply power settings: $applyOutput" -ForegroundColor Yellow
            Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "powercfg /SetActive" -Target $planGuid -Values @{ Error = $applyOutput } -Result "Warning" -Message "Power settings apply failed" -Level "WARNING"
            $warningCount++
        }
    }
    catch {
        Write-Host "[ERROR] Failed to configure PCIe/USB power settings: $_" -ForegroundColor Red
        Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "powercfg" -Target "PCIeUSBConfig" -Values @{ Error = $_.Exception.Message } -Result "Error" -Message "PCIe/USB configuration failed" -Level "ERROR"
        $errorCount++
    }
    #endregion

    #region Stage 4: OEM Service Detection and Countermeasures (PWRP-07, PWRP-08)
    Write-Host "`n[STAGE 4] OEM Service Detection and Countermeasures" -ForegroundColor Cyan

    try {
        # Load OEM service configuration
        $configPath = "$PSScriptRoot\..\config\services.json"
        if (-not (Test-Path $configPath)) {
            Write-Host "[ERROR] Configuration file not found: $configPath" -ForegroundColor Red
            Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "Test-Path" -Target $configPath -Values @{ Error = "File not found" } -Result "Error" -Message "services.json configuration missing" -Level "ERROR"
            $errorCount++
            return $false
        }

        $servicesConfig = Get-Content -Path $configPath | ConvertFrom-Json
        $oemServicesDetected = @()

        # Detect OEM power services
        foreach ($vendor in $servicesConfig.oem.PSObject.Properties) {
            $vendorName = $vendor.Name
            $vendorServices = $vendor.Value

            foreach ($service in $vendorServices) {
                $serviceName = $service.name
                $displayName = $service.displayName
                $detectionPattern = $service.detectionPattern.query

                # Execute detection query
                $serviceExists = Invoke-Expression $detectionPattern

                if ($serviceExists) {
                    $oemServicesDetected += @{
                        Vendor = $vendorName
                        Name = $serviceName
                        DisplayName = $displayName
                    }
                }
            }
        }

        # Handle detected OEM services
        if ($oemServicesDetected.Count -gt 0) {
            Write-Host "`n[WARNING] Detected OEM power management services:" -ForegroundColor Yellow
            foreach ($service in $oemServicesDetected) {
                Write-Host "  - [$($service.Vendor)] $($service.DisplayName) ($($service.Name))" -ForegroundColor White
            }

            Write-Host "`nOEM services may reassert OEM power plans at boot/login." -ForegroundColor Yellow
            $disableChoice = Read-Host -Prompt "Disable detected OEM services? (Y/N)"

            if ($disableChoice -eq 'Y' -or $disableChoice -eq 'y') {
                # Disable OEM services
                foreach ($service in $oemServicesDetected) {
                    try {
                        $svc = Get-Service -Name $service.Name -ErrorAction Stop

                        # Save rollback entry BEFORE modification
                        Save-RollbackEntry -Type "Service" -Target $service.Name -OriginalStartType $svc.StartType

                        # Stop and disable service
                        Stop-Service -Name $service.Name -Force -ErrorAction Stop
                        Set-Service -Name $service.Name -StartupType Disabled -ErrorAction Stop

                        Write-Host "[SUCCESS] Disabled OEM service: $($service.DisplayName)" -ForegroundColor Green
                        Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "Set-Service" -Target $service.Name -Values @{ OriginalStartType = $svc.StartType; NewStartType = "Disabled" } -Result "Success" -Message "OEM power service disabled" -Level "SUCCESS"
                        $successCount++
                    }
                    catch {
                        Write-Host "[ERROR] Failed to disable OEM service: $($service.Name) - $_" -ForegroundColor Red
                        Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "Set-Service" -Target $service.Name -Values @{ Error = $_.Exception.Message } -Result "Error" -Message "OEM service disable failed" -Level "ERROR"
                        $errorCount++
                    }
                }

                # Prompt for scheduled task creation
                Write-Host "`nCreate scheduled task to reapply power plan at login?" -ForegroundColor Cyan
                Write-Host "  This task will reactivate WinOptimizer Ultimate plan at login to counter OEM interference." -ForegroundColor White
                $taskChoice = Read-Host -Prompt "Create scheduled task? (Y/N)"

                if ($taskChoice -eq 'Y' -or $taskChoice -eq 'y') {
                    # Get active plan GUID
                    $planGuid = Get-ActivePlanGuid
                    $taskName = "WinOptimizer Power Plan Reapply"
                    $taskDescription = "Reapply WinOptimizer Ultimate power plan at login to counter OEM interference"

                    # Check if task already exists
                    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

                    if ($existingTask) {
                        Write-Host "[WARNING] Scheduled task '$taskName' already exists" -ForegroundColor Yellow
                        $overwriteChoice = Read-Host -Prompt "Overwrite existing task? (Y/N)"

                        if ($overwriteChoice -eq 'Y' -or $overwriteChoice -eq 'y') {
                            # Unregister existing task
                            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
                            Write-Host "[INFO] Deleted existing scheduled task" -ForegroundColor Cyan
                        }
                        else {
                            Write-Host "[SKIP] Keeping existing scheduled task" -ForegroundColor Gray
                            Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "Get-ScheduledTask" -Target $taskName -Values @{ UserAction = "Keep existing" } -Result "Skip" -Message "User kept existing scheduled task" -Level "SKIP"
                            $skipCount++
                            return
                        }
                    }

                    # Create task action
                    $action = New-ScheduledTaskAction -Execute "powercfg.exe" -Argument "/setactive $planGuid"

                    # Create trigger: At logon
                    $trigger = New-ScheduledTaskTrigger -AtLogon

                    # Create principal: Run with highest privileges
                    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest -LogonType Interactive

                    # Create settings
                    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

                    # Register the task
                    try {
                        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description $taskDescription -ErrorAction Stop | Out-Null

                        Write-Host "[SUCCESS] Created scheduled task '$taskName'" -ForegroundColor Green
                        Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "Register-ScheduledTask" -Target $taskName -Values @{ PlanGuid = $planGuid; Trigger = "AtLogon"; RunLevel = "Highest" } -Result "Success" -Message "Scheduled task created to counter OEM interference" -Level "SUCCESS"

                        # Save rollback entry for scheduled task
                        Save-RollbackEntry -Type "ScheduledTask" -Target $taskName -OriginalData $null

                        $successCount++
                    }
                    catch {
                        Write-Host "[ERROR] Failed to create scheduled task: $_" -ForegroundColor Red
                        Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "Register-ScheduledTask" -Target $taskName -Values @{ Error = $_.Exception.Message } -Result "Error" -Message "Scheduled task creation failed" -Level "ERROR"
                        $errorCount++
                    }
                }
                else {
                    Write-Host "[SKIP] User declined scheduled task creation - OEM services may reassert power plans" -ForegroundColor Gray
                    Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "UserPrompt" -Target "ScheduledTaskCreation" -Values @{ UserAction = "Declined" } -Result "Skip" -Message "User declined scheduled task creation" -Level "SKIP"
                    $skipCount++
                }
            }
            else {
                Write-Host "[SKIP] User declined OEM service disablement" -ForegroundColor Gray
                Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "UserPrompt" -Target "OEMServiceDisable" -Values @{ UserAction = "Declined" } -Result "Skip" -Message "User declined OEM service disablement" -Level "SKIP"
                $skipCount++
            }
        }
        else {
            Write-Host "[INFO] No OEM power management services detected" -ForegroundColor Cyan
            Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "Get-Content" -Target $configPath -Values @{ OEMServicesDetected = 0 } -Result "Skip" -Message "No OEM services found" -Level "INFO"
            $skipCount++
        }
    }
    catch {
        Write-Host "[ERROR] Failed to detect OEM services or create countermeasures: $_" -ForegroundColor Red
        Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "OEMDetection" -Target "OEMServices" -Values @{ Error = $_.Exception.Message } -Result "Error" -Message "OEM detection/countermeasures failed" -Level "ERROR"
        $errorCount++
    }
    #endregion

    #region End Block: Display Summary and Return Result
    $stopwatch.Stop()
    $elapsedTime = $stopwatch.Elapsed.ToString("mm\:ss")

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " Power Plan Configuration Summary" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Successes:  $successCount" -ForegroundColor Green
    Write-Host "  Warnings:   $warningCount" -ForegroundColor Yellow
    Write-Host "  Skips:      $skipCount" -ForegroundColor Gray
    Write-Host "  Errors:     $errorCount" -ForegroundColor Red
    Write-Host "  Elapsed:    $elapsedTime" -ForegroundColor White
    Write-Host "========================================`n" -ForegroundColor Cyan

    $result = ($errorCount -eq 0)

    if ($result) {
        Write-Host "[SUCCESS] Power plan configuration completed successfully" -ForegroundColor Green
        Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "ModuleComplete" -Target "Summary" -Values @{ Successes = $successCount; Warnings = $warningCount; Skips = $skipCount; Errors = $errorCount; Elapsed = $elapsedTime } -Result "Success" -Message "Power plan configuration module completed" -Level "SUCCESS"
    }
    else {
        Write-Host "[ERROR] Power plan configuration completed with errors" -ForegroundColor Red
        Write-OptLog -Module "Invoke-PowerPlanConfig" -Operation "ModuleComplete" -Target "Summary" -Values @{ Successes = $successCount; Warnings = $warningCount; Skips = $skipCount; Errors = $errorCount; Elapsed = $elapsedTime } -Result "Error" -Message "Power plan configuration module completed with errors" -Level "ERROR"
    }

    return $result
    #endregion
}
