#Requires -Version 5.1

<#
.SYNOPSIS
    Optimizes GPU and Desktop Window Manager settings for reduced latency

.DESCRIPTION
    Enables Hardware-Accelerated GPU Scheduling, disables Multi-Plane Overlay, detects GPUs,
    and applies vendor-specific optimizations. All changes are recorded to rollback manifest.
#>

function Invoke-GpuDwmOptimize {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    begin {
        #region Initialize counters and arrays
        $successCount = 0
        $skipCount = 0
        $warningCount = 0
        $errorCount = 0
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        # Protected GPU vendors for validation (skip virtual GPUs)
        $protectedVendors = @('Hyper-V', 'VMware', 'Virtual', 'Remote Desktop')
        $selectedGpus = @()
        #endregion

        #region Dot-source lib helpers
        . $PSScriptRoot\..\lib\Write-OptLog.ps1
        . $PSScriptRoot\..\lib\Save-RollbackEntry.ps1
        #endregion
    }

    process {
        #region Stage 1: GPU Detection
        Write-Host "[INFO] Detecting GPUs via WMI..." -ForegroundColor Cyan

        try {
            $gpus = Get-WmiObject Win32_VideoController -ErrorAction Stop
        } catch {
            # CONTEXT: WMI Query Fails
            Write-Host "[WARNING] WMI query failed: $_" -ForegroundColor Yellow

            Write-OptLog -Module "Invoke-GpuDwmOptimize" `
                -Operation "Get-WmiObject" `
                -Target "Win32_VideoController" `
                -Values @{ Error = $_.Exception.Message } `
                -Result "Warning" `
                -Message "WMI GPU detection failed" `
                -Level "WARNING"

            $choice = Read-Host -Prompt "Halt GPU module, use fallback detection, or skip GPU optimizations? (H/F/S)"

            if ($choice -eq 'H' -or $choice -eq 'h') {
                Write-Host "[ERROR] Halting GPU module per user choice" -ForegroundColor Red
                return $false
            } elseif ($choice -eq 'S' -or $choice -eq 's') {
                Write-Host "[SKIP] Skipping GPU module per user choice" -ForegroundColor Gray
                return $false
            } else {
                # Fallback: Attempt registry-only HAGS/MPO without GPU detection
                Write-Host "[INFO] Using fallback detection (registry-only mode)" -ForegroundColor Cyan
                $fallbackMode = $true
                $gpus = @()  # Empty array, skip GPU-specific logic
            }
        }

        # CONTEXT: No GPU Found
        if (-not $fallbackMode -and ($null -eq $gpus -or $gpus.Count -eq 0)) {
            Write-Host "[WARNING] No GPUs detected via WMI" -ForegroundColor Yellow

            Write-OptLog -Module "Invoke-GpuDwmOptimize" `
                -Operation "Get-WmiObject" `
                -Target "Win32_VideoController" `
                -Values @{} `
                -Result "Warning" `
                -Message "No GPUs detected" `
                -Level "WARNING"

            $choice = Read-Host -Prompt "Halt, skip GPU module, or attempt generic optimizations? (H/S/G)"

            if ($choice -eq 'G' -or $choice -eq 'g') {
                Write-Host "[INFO] Attempting generic optimizations (MPO disable via registry)" -ForegroundColor Cyan
                $fallbackMode = $true
            } else {
                return $false
            }
        }

        # CONTEXT: Virtual GPU Detected - Skip virtual GPU
        if (-not $fallbackMode) {
            $physicalGpus = $gpus | Where-Object {
                $gpuName = $_.Name
                $isVirtual = $false
                foreach ($protected in $protectedVendors) {
                    if ($gpuName -like "*$protected*") {
                        $isVirtual = $true
                        break
                    }
                }
                -not $isVirtual
            }

            if ($physicalGpus.Count -eq 0) {
                Write-Host "[SKIP] No physical GPUs found (all detected GPUs are virtual)" -ForegroundColor Gray
                return $false
            }
        } else {
            $physicalGpus = @()
        }

        # CONTEXT: GPU Detection - Detect GPU Vendors
        if ($physicalGpus.Count -gt 0) {
            $nvidiaGpus = $physicalGpus | Where-Object { $_.Name -like '*NVIDIA*' }
            $amdGpus = $physicalGpus | Where-Object { $_.Name -like '*AMD*' -or $_.Name -like '*Radeon*' }
            $intelGpus = $physicalGpus | Where-Object { $_.Name -like '*Intel*' }

            Write-Host "[INFO] Detected $($physicalGpus.Count) physical GPU(s):" -ForegroundColor Cyan
            Write-Host "  - Nvidia: $($nvidiaGpus.Count)" -ForegroundColor White
            Write-Host "  - AMD: $($amdGpus.Count)" -ForegroundColor White
            Write-Host "  - Intel: $($intelGpus.Count)" -ForegroundColor White
        }

        # CONTEXT: Multiple GPUs - Multi-select menu with indices
        if ($physicalGpus.Count -gt 1) {
            Write-Host "`nMultiple GPUs detected:" -ForegroundColor Cyan
            for ($i = 0; $i -lt $physicalGpus.Count; $i++) {
                $gpu = $physicalGpus[$i]
                $gpuType = if ($nvidiaGpus -contains $gpu) { "Nvidia" }
                           elseif ($amdGpus -contains $gpu) { "AMD" }
                           elseif ($intelGpus -contains $gpu) { "Intel" }
                           else { "Unknown" }

                $ramGB = [math]::Round($gpu.AdapterRAM / 1GB, 2)
                $discrete = if ($gpu.AdapterRAM -gt 2GB) { " [Discrete]" } else { " [Integrated]" }

                Write-Host "  [$i] $($gpu.Name) ($gpuType, ${ramGB}GB)$discrete" -ForegroundColor White
            }

            # CONTEXT: Default Selection - Pre-select discrete GPU
            $defaultIndex = $physicalGpus.IndexOf(($physicalGpus | Where-Object { $_.AdapterRAM -gt 2GB } | Select-Object -First 1))

            $selection = Read-Host -Prompt "Select GPU(s) to optimize (comma-separated indices, default=$defaultIndex)"
            if ([string]::IsNullOrWhiteSpace($selection)) {
                $selection = "$defaultIndex"
            }

            $selectedIndices = $selection -split ',' | ForEach-Object { [int]$_.Trim() }
            $selectedGpus = $selectedIndices | ForEach-Object { $physicalGpus[$_] }
        } elseif ($physicalGpus.Count -eq 1) {
            $selectedGpus = @($physicalGpus[0])
        }

        if ($selectedGpus.Count -gt 0) {
            Write-Host "[INFO] Selected $($selectedGpus.Count) GPU(s) for optimization" -ForegroundColor Cyan
        }
        #endregion

        #region Stage 2: HAGS Configuration
        Write-Host "[ACTION] Enabling Hardware-Accelerated GPU Scheduling..." -ForegroundColor Cyan

        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
        $valueName = "HwSchMode"
        $desiredValue = 2

        # Check current state
        $currentHags = Get-ItemProperty -Path $regPath -Name $valueName -ErrorAction SilentlyContinue

        # CONTEXT: HAGS Checks - Check registry value + driver capability validation
        if ($null -ne $currentHags -and $currentHags.$valueName -eq $desiredValue) {
            Write-Host "[SKIP] HAGS already enabled" -ForegroundColor Gray

            Write-OptLog -Module "Invoke-GpuDwmOptimize" `
                -Operation "Get-ItemProperty" `
                -Target "$regPath\$valueName" `
                -Values @{ CurrentValue = $currentHags.$valueName; DesiredValue = $desiredValue } `
                -Result "Skip" `
                -Message "HAGS already enabled" `
                -Level "SKIP"

            $skipCount++
        } else {
            try {
                # Save rollback entry BEFORE modification
                Save-RollbackEntry -Type "Registry" `
                    -Target $regPath `
                    -ValueName $valueName `
                    -OriginalData $currentHags.$valueName `
                    -OriginalType "REG_DWORD"

                # Enable HAGS
                Set-ItemProperty -Path $regPath -Name $valueName -Value $desiredValue -Type DWord -ErrorAction Stop

                Write-Host "[SUCCESS] HAGS enabled (requires reboot to activate)" -ForegroundColor Green

                Write-OptLog -Module "Invoke-GpuDwmOptimize" `
                    -Operation "Set-ItemProperty" `
                    -Target "$regPath\$valueName" `
                    -Values @{ OldValue = $currentHags.$valueName; NewValue = $desiredValue } `
                    -Result "Success" `
                    -Message "Hardware-Accelerated GPU Scheduling enabled" `
                    -Level "SUCCESS"

                $successCount++

                # CONTEXT: HAGS Reboot - Prompt user
                $reboot = Read-Host -Prompt "Reboot now to activate HAGS? (Y/N)"
                if ($reboot -eq 'Y' -or $reboot -eq 'y') {
                    Write-Host "[INFO] Restart-Computer would be called here (deferred to entry point)" -ForegroundColor Cyan
                    # Don't actually reboot - let entry point handle it
                    Write-Host "[WARNING] HAGS will not be active until reboot" -ForegroundColor Yellow
                } else {
                    Write-Host "[WARNING] HAGS will not be active until reboot" -ForegroundColor Yellow

                    Write-OptLog -Module "Invoke-GpuDwmOptimize" `
                        -Operation "Set-ItemProperty" `
                        -Target "$regPath\$valueName" `
                        -Values @{} `
                        -Result "Warning" `
                        -Message "HAGS enabled but requires reboot to activate" `
                        -Level "WARNING"
                }
            } catch {
                Write-Host "[ERROR] Failed to enable HAGS: $_" -ForegroundColor Red
                Write-Host "[INFO] Your GPU driver may not support HAGS" -ForegroundColor Cyan

                Write-OptLog -Module "Invoke-GpuDwmOptimize" `
                    -Operation "Set-ItemProperty" `
                    -Target "$regPath\$valueName" `
                    -Values @{ Error = $_.Exception.Message } `
                    -Result "Error" `
                    -Message "Failed to enable HAGS (driver may not support it)" `
                    -Level "ERROR"

                # CONTEXT: GPU Optimization Step Failure - Prompt user to skip or halt
                $continue = Read-Host -Prompt "Skip HAGS and continue with MPO? (Y/N)"
                if ($continue -ne 'Y' -and $continue -ne 'y') {
                    Write-Host "[ERROR] Halting GPU module per user choice" -ForegroundColor Red
                    return $false
                }
                $errorCount++
            }
        }
        #endregion

        #region Stage 3: MPO Configuration
        Write-Host "[ACTION] Disabling Multi-Plane Overlay..." -ForegroundColor Cyan

        $dwmPath = "HKLM:\SOFTWARE\Microsoft\Windows\Dwm"
        $mpoValue = "OverlayTestMode"
        $desiredMpo = 5

        # CONTEXT: MPO Checks - Check registry value + verify system state
        $currentMpo = Get-ItemProperty -Path $dwmPath -Name $mpoValue -ErrorAction SilentlyContinue

        if ($null -eq $currentMpo) {
            # CONTEXT: MPO Key Missing - Log WARNING (expected on older Windows)
            Write-Host "[WARNING] MPO registry key not found (expected on older Windows versions)" -ForegroundColor Yellow

            Write-OptLog -Module "Invoke-GpuDwmOptimize" `
                -Operation "Get-ItemProperty" `
                -Target "$dwmPath\$mpoValue" `
                -Values @{} `
                -Result "Warning" `
                -Message "MPO key not found, may not be supported on this Windows version" `
                -Level "WARNING"

            $warningCount++
        } elseif ($currentMpo.$mpoValue -eq $desiredMpo) {
            Write-Host "[SKIP] MPO already disabled" -ForegroundColor Gray

            Write-OptLog -Module "Invoke-GpuDwmOptimize" `
                -Operation "Get-ItemProperty" `
                -Target "$dwmPath\$mpoValue" `
                -Values @{ CurrentValue = $currentMpo.$mpoValue; DesiredValue = $desiredMpo } `
                -Result "Skip" `
                -Message "MPO already disabled" `
                -Level "SKIP"

            $skipCount++
        } else {
            try {
                # Save rollback entry
                Save-RollbackEntry -Type "Registry" `
                    -Target $dwmPath `
                    -ValueName $mpoValue `
                    -OriginalData $currentMpo.$mpoValue `
                    -OriginalType "REG_DWORD"

                # Disable MPO
                Set-ItemProperty -Path $dwmPath -Name $mpoValue -Value $desiredMpo -Type DWord -ErrorAction Stop

                Write-Host "[SUCCESS] MPO disabled" -ForegroundColor Green

                Write-OptLog -Module "Invoke-GpuDwmOptimize" `
                    -Operation "Set-ItemProperty" `
                    -Target "$dwmPath\$mpoValue" `
                    -Values @{ OldValue = $currentMpo.$mpoValue; NewValue = $desiredMpo } `
                    -Result "Success" `
                    -Message "Multi-Plane Overlay disabled" `
                    -Level "SUCCESS"

                $successCount++
            } catch {
                Write-Host "[ERROR] Failed to disable MPO: $_" -ForegroundColor Red

                Write-OptLog -Module "Invoke-GpuDwmOptimize" `
                    -Operation "Set-ItemProperty" `
                    -Target "$dwmPath\$mpoValue" `
                    -Values @{ Error = $_.Exception.Message } `
                    -Result "Error" `
                    -Message "Failed to disable MPO" `
                    -Level "ERROR"

                $errorCount++
            }
        }
        #endregion

        #region Stage 4: Vendor Optimizations
        if ($selectedGpus.Count -gt 0 -and -not $fallbackMode) {
            foreach ($gpu in $selectedGpus) {
                $gpuName = $gpu.Name

                # CONTEXT: Unknown GPU Vendor
                $isNvidia = $gpuName -like '*NVIDIA*'
                $isAmd = $gpuName -like '*AMD*' -or $gpuName -like '*Radeon*'
                $isIntel = $gpuName -like '*Intel*'

                if (-not $isNvidia -and -not $isAmd -and -not $isIntel) {
                    Write-Host "[WARNING] Unknown GPU vendor: $gpuName" -ForegroundColor Yellow
                    $choice = Read-Host -Prompt "Apply generic optimizations, skip vendor-specific, or halt? (G/S/H)"

                    if ($choice -eq 'H' -or $choice -eq 'h') {
                        Write-Host "[ERROR] Halting GPU module per user choice" -ForegroundColor Red
                        return $false
                    } elseif ($choice -eq 'S' -or $choice -eq 's') {
                        Write-Host "[SKIP] Skipping vendor-specific optimizations for $gpuName" -ForegroundColor Gray
                        continue
                    }
                    # else: apply generic optimizations (HAGS/MPO already applied)
                }

                # CONTEXT: Nvidia GPU - Prompt for vendor-specific optimizations
                if ($isNvidia) {
                    Write-Host "[INFO] Nvidia GPU detected: $gpuName" -ForegroundColor Cyan
                    $nvidiaOpt = Read-Host -Prompt "Apply Nvidia-specific optimizations? (Y/N)"

                    if ($nvidiaOpt -eq 'Y' -or $nvidiaOpt -eq 'y') {
                        # GPUD-04: Disable NvTelemetryContainer service
                        $nvTelemetry = Get-Service -Name 'NvTelemetryContainer' -ErrorAction SilentlyContinue

                        if ($null -ne $nvTelemetry) {
                            # Get current state
                            $currentStartType = (Get-WmiObject -Class Win32_Service -Filter "Name='NvTelemetryContainer'").StartMode
                            $currentStatus = $nvTelemetry.Status

                            # Idempotency check
                            if ($currentStartType -ne 'Disabled' -or $currentStatus -ne 'Stopped') {
                                Write-Host "[ACTION] Disabling NvTelemetryContainer service..." -ForegroundColor Cyan

                                # Save rollback entry
                                Save-RollbackEntry -Type "Service" `
                                    -Target 'NvTelemetryContainer' `
                                    -OriginalStartType $currentStartType

                                # Stop service
                                if ($nvTelemetry.Status -ne 'Stopped') {
                                    try {
                                        Stop-Service -Name 'NvTelemetryContainer' -Force -ErrorAction Stop
                                        Write-Host "[SUCCESS] Stopped NvTelemetryContainer" -ForegroundColor Green
                                    } catch {
                                        Write-Host "[WARNING] Failed to stop NvTelemetryContainer: $_" -ForegroundColor Yellow
                                    }
                                }

                                # Disable service
                                try {
                                    Set-Service -Name 'NvTelemetryContainer' -StartupType Disabled -ErrorAction Stop
                                    Write-Host "[SUCCESS] Disabled NvTelemetryContainer" -ForegroundColor Green

                                    Write-OptLog -Module "Invoke-GpuDwmOptimize" `
                                        -Operation "Set-Service" `
                                        -Target 'NvTelemetryContainer' `
                                        -Values @{ OldStartType = $currentStartType; NewStartType = 'Disabled' } `
                                        -Result "Success" `
                                        -Message "Nvidia telemetry service disabled" `
                                        -Level "SUCCESS"

                                    $successCount++
                                } catch {
                                    Write-Host "[ERROR] Failed to disable NvTelemetryContainer: $_" -ForegroundColor Red
                                    $errorCount++
                                }
                            } else {
                                Write-Host "[SKIP] NvTelemetryContainer already disabled and stopped" -ForegroundColor Gray
                                $skipCount++
                            }
                        } else {
                            Write-Host "[SKIP] NvTelemetryContainer service not found" -ForegroundColor Gray
                            $skipCount++
                        }

                        # GPUD-03: Output NVCP manual configuration checklist
                        Write-Host "`n[NVIDIA Control Panel Manual Configuration]" -ForegroundColor Yellow
                        Write-Host "1. Open NVIDIA Control Panel" -ForegroundColor White
                        Write-Host "2. Go to 'Manage 3D Settings'" -ForegroundColor White
                        Write-Host "3. Set 'Power management mode' to 'Prefer maximum performance'" -ForegroundColor White
                        Write-Host "4. Set 'Texture filtering - Quality' to 'High performance'" -ForegroundColor White
                        Write-Host "5. Set 'Max Frame Rate' to your monitor refresh rate" -ForegroundColor White
                        Write-Host "6. Set 'Low Latency Mode' to 'Ultra'" -ForegroundColor White
                        Write-Host "`nThese settings must be configured manually in NVIDIA Control Panel." -ForegroundColor Cyan
                    } else {
                        Write-Host "[INFO] Skipping Nvidia-specific optimizations, HAGS-only mode" -ForegroundColor Cyan
                    }
                }

                # CONTEXT: AMD GPU - Prompt for vendor-specific optimizations
                if ($isAmd) {
                    Write-Host "[INFO] AMD GPU detected: $gpuName" -ForegroundColor Cyan
                    $amdOpt = Read-Host -Prompt "Apply AMD-specific optimizations? (Y/N)"

                    if ($amdOpt -eq 'Y' -or $amdOpt -eq 'y') {
                        # AMD-specific optimizations (e.g., Radeon Software settings)
                        Write-Host "[INFO] AMD GPU optimization checklist:" -ForegroundColor Cyan
                        Write-Host "1. Open AMD Radeon Software" -ForegroundColor White
                        Write-Host "2. Go to 'Graphics' -> 'Advanced'" -ForegroundColor White
                        Write-Host "3. Set 'Tessellation Mode' to 'AMD optimized'" -ForegroundColor White
                        Write-Host "4. Set 'Radeon Enhanced Sync' to 'On'" -ForegroundColor White
                        Write-Host "5. Disable 'Radeon Anti-Lag' (adds latency)" -ForegroundColor White
                        Write-Host "`nThese settings must be configured manually in AMD Radeon Software." -ForegroundColor Cyan
                    } else {
                        Write-Host "[INFO] Skipping AMD-specific optimizations" -ForegroundColor Cyan
                    }
                }

                # CONTEXT: Intel Integrated GPU - Prompt for optimization
                if ($isIntel) {
                    Write-Host "[INFO] Intel integrated GPU detected: $gpuName" -ForegroundColor Cyan
                    $intelOpt = Read-Host -Prompt "Optimize integrated GPU? (usually skipped alongside discrete) (Y/N)"

                    if ($intelOpt -ne 'Y' -and $intelOpt -ne 'y') {
                        Write-Host "[INFO] Skipping Intel integrated GPU optimization" -ForegroundColor Cyan
                        continue
                    }
                    # Intel-specific optimizations would go here
                }
            }
        }
        #endregion

        #region Stage 5: HAGS Validation
        # Check if HAGS is actually active (registry readback)
        $actualHags = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -ErrorAction SilentlyContinue

        if ($null -ne $actualHags -and $actualHags.HwSchMode -eq 2) {
            Write-Host "[INFO] HAGS registry value = 2 (enabled)" -ForegroundColor Cyan
            Write-Host "[WARNING] HAGS requires reboot to activate. If system has not rebooted, HAGS is not yet active." -ForegroundColor Yellow

            Write-OptLog -Module "Invoke-GpuDwmOptimize" `
                -Operation "Get-ItemProperty" `
                -Target "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\HwSchMode" `
                -Values @{ RegistryValue = $actualHags.HwSchMode; Active = $false } `
                -Result "Warning" `
                -Message "HAGS registry set but not yet active (requires reboot)" `
                -Level "WARNING"

            $warningCount++
        } else {
            Write-Host "[ERROR] HAGS validation failed - registry value is not 2" -ForegroundColor Red

            Write-OptLog -Module "Invoke-GpuDwmOptimize" `
                -Operation "Get-ItemProperty" `
                -Target "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\HwSchMode" `
                -Values @{ RegistryValue = if ($actualHags) { $actualHags.HwSchMode } else { "null" } } `
                -Result "Error" `
                -Message "HAGS validation failed - registry incorrect" `
                -Level "ERROR"

            # CONTEXT: HAGS Still Disabled (no reboot) - Halt, instruct user to reboot
            Write-Host "[ERROR] HAGS is not enabled. Please reboot and re-run this module." -ForegroundColor Red
            $errorCount++
        }
        #endregion

        #region Summary Display
        #endregion
    }

    end {
        $stopwatch.Stop()

        Write-Host "`n=== GPU/DWM Optimization Summary ===" -ForegroundColor Cyan
        Write-Host "Successful: $successCount | Skipped: $skipCount | Warnings: $warningCount | Errors: $errorCount" -ForegroundColor White
        Write-Host "Elapsed Time: $($stopwatch.Elapsed.ToString('mm\:ss'))" -ForegroundColor White

        if ($errorCount -gt 0) {
            Write-Host "[WARNING] Errors occurred during GPU optimization. Review log for details." -ForegroundColor Yellow
        }

        if ($warningCount -gt 0) {
            Write-Host "[INFO] Warnings occurred. Some optimizations may not be fully active." -ForegroundColor Cyan
        }

        return $errorCount -eq 0
    }
}
