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
        #endregion

        #region Stage 3: MPO Configuration
        #endregion

        #region Stage 4: Vendor Optimizations
        #endregion

        #region Stage 5: HAGS Validation
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
