#Requires -Version 5.1

<#
.SYNOPSIS
    Validates WSL2 and Hyper-V virtualization stack using WMI.

.DESCRIPTION
    The Test-VirtStack function checks the status of WSL2 and Hyper-V
    using WMI queries and Get-Service cmdlet. This approach avoids calling
    wsl.exe which fails under LOCAL_SYSTEM context (elevated PowerShell).

.EXAMPLE
    $virtStatus = Test-VirtStack

.NOTES
    NEVER calls wsl.exe from elevated context due to LOCAL_SYSTEM limitation.
    Author: WinOptimizer Project
    Version: 1.0.0
#>
function Test-VirtStack {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    try {
        #region WMI Feature Detection
        $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
        $vmPlatformFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
        $hypervisorPresent = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty Hypervisor
        #endregion

        #region Service State Detection
        $hvHostService = Get-Service -Name HvHost -ErrorAction SilentlyContinue
        $vmmsService = Get-Service -Name vmms -ErrorAction SilentlyContinue
        $wslService = Get-Service -Name WslService -ErrorAction SilentlyContinue
        $lxssManagerService = Get-Service -Name LxssManager -ErrorAction SilentlyContinue
        #endregion

        #region Status Hashtable
        $status = [ordered]@{
            WSL_Enabled            = ($wslFeature.State -eq 'Enabled')
            VirtualMachine_Enabled = ($vmPlatformFeature.State -eq 'Enabled')
            Hypervisor_Present     = ($hypervisorPresent -eq $true)
            HvHost_Running         = if ($null -ne $hvHostService) { $hvHostService.Status -eq 'Running' } else { $false }
            vmms_Running           = if ($null -ne $vmmsService) { $vmmsService.Status -eq 'Running' } else { $false }
            WslService_Running     = if ($null -ne $wslService) { $wslService.Status -eq 'Running' } else { $false }
            LxssManager_Running    = if ($null -ne $lxssManagerService) { $lxssManagerService.Status -eq 'Running' } else { $false }
            Overall_Healthy        = $false
        }

        $status.Overall_Healthy = (
            $status.WSL_Enabled -and
            $status.VirtualMachine_Enabled -and
            $status.Hypervisor_Present -and
            $status.HvHost_Running -and
            $status.vmms_Running -and
            $status.WslService_Running -and
            $status.LxssManager_Running
        )
        #endregion

        return $status
    }
    catch {
        Write-Error "Test-VirtStack failed: $_"
        return @{
            WSL_Enabled            = $false
            VirtualMachine_Enabled = $false
            Hypervisor_Present     = $false
            HvHost_Running         = $false
            vmms_Running           = $false
            WslService_Running     = $false
            LxssManager_Running    = $false
            Overall_Healthy        = $false
        }
    }
}
