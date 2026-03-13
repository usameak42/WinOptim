#Requires -Version 5.1

<#
.SYNOPSIS
    Tests Administrator elevation status and relaunches script with elevated privileges.

.DESCRIPTION
    The Invoke-AdminRelaunch module provides two functions for Administrator
    elevation detection and self-relaunch. Test-AdminElevation checks if the
    current process is running as Administrator. Invoke-AdminRelaunch relaunches
    the script with elevated privileges using Start-Process with -Verb RunAs.

.PARAMETER KnownArgs
    Array of known argument strings from the original script invocation.
    Only safe arguments (-Silent, -RunAll, -Rollback) are preserved during relaunch.

.EXAMPLE
    . .\lib\Invoke-AdminRelaunch.ps1

    if (-not (Test-AdminElevation)) {
        Invoke-AdminRelaunch -KnownArgs @('-Silent')
    }

.NOTES
    Author: WinOptimizer Project
    Version: 1.0.0
    Exit code 5 (ERROR_ACCESS_DENIED) if elevation fails or user cancels UAC.
#>

#region Function: Test-AdminElevation
<#
.SYNOPSIS
    Tests if the current process is running as Administrator.

.DESCRIPTION
    Test-AdminElevation uses .NET Security.Principal.WindowsPrincipal to check
    if the current process is a member of the Windows Built-in Administrator role.

.OUTPUTS
    System.Boolean
    Returns $true if running as Administrator, $false otherwise.

.EXAMPLE
    $isAdmin = Test-AdminElevation
    if (-not $isAdmin) {
        Write-Warning "Administrator privileges required"
    }

.NOTES
    Uses [Security.Principal.WindowsPrincipal]::IsInRole("Administrator") pattern.
    No parameters required.
#>
function Test-AdminElevation {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        #region Principal Construction
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        #endregion

        #region Administrator Role Check
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        return $isAdmin
        #endregion
    }
    catch {
        Write-Error "Test-AdminElevation failed: $_"
        return $false
    }
}
#endregion

#region Function: Invoke-AdminRelaunch
<#
.SYNOPSIS
    Relaunches the current script with Administrator privileges.

.DESCRIPTION
    Invoke-AdminRelaunch restarts the script using Start-Process with -Verb RunAs
    to trigger UAC elevation. Only known safe arguments are preserved during relaunch.
    The original process exits after spawning the elevated process.

.PARAMETER KnownArgs
    Array of known argument strings from the original script invocation.
    Only -Silent, -RunAll, and -Rollback arguments are preserved for security.

.OUTPUTS
    None. Function exits the current process after relaunch.

.EXAMPLE
    Invoke-AdminRelaunch -KnownArgs @('-Silent', '-RunAll')

.NOTES
    Exit code 0 after successful relaunch (original process terminates).
    Exit code 5 (ERROR_ACCESS_DENIED) if elevation fails or user cancels UAC.
#>
function Invoke-AdminRelaunch {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$KnownArgs = @()
    )

    #region Pre-Relaunch Message
    Write-Host "WinOptimizer requires Administrator privileges. Restarting with elevation..." -ForegroundColor Yellow
    #endregion

    #region Process Argument Construction
    $argumentList = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "`"$PSCommandPath`""
    )

    # Pass only known safe arguments
    if ($KnownArgs -contains '-Silent') {
        $argumentList += '-Silent'
    }
    if ($KnownArgs -contains '-RunAll') {
        $argumentList += '-RunAll'
    }
    if ($KnownArgs -contains '-Rollback') {
        $argumentList += '-Rollback'
    }
    #endregion

    #region Elevated Process Launch
    try {
        $processParams = @{
            FilePath     = "powershell.exe"
            ArgumentList = $argumentList
            Verb         = "RunAs"
            NoNewWindow  = $true
        }

        Start-Process @processParams

        # Log elevation relaunch action
        $null = Write-OptLog -Module "SafetyGates" -Operation "ElevationRelaunch" -Target "PowerShellProcess" -Values @{
            Arguments = $argumentList -join ' '
        } -Result "Success" -Message "Script relaunched with Administrator privileges" -Level "INFO"

        # Exit original process after successful relaunch
        exit 0
    }
    catch {
        Write-Host "Elevation failed or user cancelled UAC prompt." -ForegroundColor Red

        # Log elevation failure
        $null = Write-OptLog -Module "SafetyGates" -Operation "ElevationRelaunch" -Target "PowerShellProcess" -Values @{
            Error = $_.Exception.Message
        } -Result "Error" -Message "Elevation failed or user cancelled UAC" -Level "ERROR"

        # Exit with ERROR_ACCESS_DENIED
        exit 5
    }
    #endregion
}
#endregion
