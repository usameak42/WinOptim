#Requires -Version 5.1

<#
.SYNOPSIS
    Validates WSL2 and Hyper-V virtualization stack state before and after optimization.

.DESCRIPTION
    The Test-VirtualizationStack function calls Test-VirtStack to capture the current
    virtualization state, displays appropriate warnings to the user, logs results via
    Write-OptLog, and updates the rollback manifest. This is a critical safety gate
    that ensures WSL2 and Hyper-V remain functional throughout optimization.

.EXAMPLE
    $preState = Test-VirtualizationStack

.NOTES
    Author: WinOptimizer Project
    Version: 1.0.0
#>
function Test-VirtualizationStack {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    #region Call Test-VirtStack Helper
    try {
        $virtState = & "$PSScriptRoot\Test-VirtStack.ps1"
    }
    catch {
        Write-Host "[ERROR] Failed to validate virtualization stack: $_" -ForegroundColor Red
        Write-OptLog -Module "SafetyGates" -Operation "VirtualizationCheck" -Target "VirtualizationStack" -Values @{
            Error = $_.Exception.Message
        } -Result "Error" -Message "Virtualization validation failed" -Level "ERROR"
        exit 1
    }
    #endregion

    #region Display Virtualization Status
    if ($virtState.Overall_Healthy) {
        $wslStatus = if ($virtState.WSL_Enabled) { "Active" } else { "Inactive" }
        $hvStatus = if ($virtState.Hypervisor_Present) { "Active" } else { "Inactive" }

        Write-Host "[WARNING] Virtualization stack detected: WSL2: $wslStatus, Hyper-V: $hvStatus" -ForegroundColor Red
        Write-Host "This script will preserve virtualization features. No changes will be made to WSL2 or Hyper-V." -ForegroundColor Yellow
    }
    else {
        Write-Host "[INFO] No virtualization features detected" -ForegroundColor Cyan
    }
    #endregion

    #region Log and Store Virtualization State
    $wslStatus = if ($virtState.WSL_Enabled) { "Active" } else { "Inactive" }
    $hvStatus = if ($virtState.Hypervisor_Present) { "Active" } else { "Inactive" }

    Write-OptLog -Module "SafetyGates" -Operation "VirtualizationCheck" -Target "VirtualizationStack" -Values @{
        WSL2 = $wslStatus
        HyperV = $hvStatus
        HvHost = $virtState.HvHost_Running
        vmms = $virtState.vmms_Running
        WslService = $virtState.WslService_Running
        LxssManager = $virtState.LxssManager_Running
    } -Result "Success" -Message "Virtualization stack validation complete" -Level "INFO"

    $global:RollbackData.Virtualization = @{
        WSL2 = $wslStatus
        HyperV = $hvStatus
        Timestamp = Get-Date -Format "o"
    }
    #endregion

    return $virtState
}

<#
.SYNOPSIS
    Compares virtualization state before and after optimization execution.

.DESCRIPTION
    The Compare-VirtualizationState function compares the initial virtualization state
    captured before module execution with the final state after all modules complete.
    Displays warnings if any changes occurred, confirming virtualization stack preservation.

.PARAMETER InitialState
    The hashtable returned by Test-VirtualizationStack before module execution.

.PARAMETER FinalState
    The hashtable returned by Test-VirtStack after module execution.

.EXAMPLE
    Compare-VirtualizationState -InitialState $preState -FinalState $postState

.NOTES
    Author: WinOptimizer Project
    Version: 1.0.0
#>
function Compare-VirtualizationState {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable]$InitialState,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable]$FinalState
    )

    #region Compare WSL2 State
    $changes = @()

    if ($InitialState.WSL_Enabled -ne $FinalState.WSL_Enabled) {
        $initialWsl = if ($InitialState.WSL_Enabled) { "Active" } else { "Inactive" }
        $finalWsl = if ($FinalState.WSL_Enabled) { "Active" } else { "Inactive" }
        $changes += "WSL2 changed from $initialWsl to $finalWsl"
    }

    if ($InitialState.Hypervisor_Present -ne $FinalState.Hypervisor_Present) {
        $initialHv = if ($InitialState.Hypervisor_Present) { "Active" } else { "Inactive" }
        $finalHv = if ($FinalState.Hypervisor_Present) { "Active" } else { "Inactive" }
        $changes += "Hyper-V changed from $initialHv to $finalHv"
    }
    #endregion

    #region Display Comparison Results
    if ($changes.Count -gt 0) {
        Write-Host "[WARNING] Virtualization state changed during execution:" -ForegroundColor Yellow
        foreach ($change in $changes) {
            Write-Host "  - $change" -ForegroundColor Yellow
        }

        Write-OptLog -Module "SafetyGates" -Operation "VirtualizationCompare" -Target "VirtualizationStack" -Values @{
            Changes = $changes -join '; '
        } -Result "Warning" -Message "Virtualization state changed" -Level "WARNING"
    }
    else {
        Write-Host "[SUCCESS] Virtualization state unchanged" -ForegroundColor Green
    }
    #endregion
}
