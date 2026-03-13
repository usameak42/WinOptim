#Requires -Version 5.1

<#
.SYNOPSIS
    Validates PowerShell version compatibility for WinOptimizer execution.

.DESCRIPTION
    The Test-PowerShellVersion function checks the current PowerShell version
    against the minimum required version (5.1). For PowerShell 7+ (pwsh),
    an interactive prompt allows the user to proceed or exit. For PowerShell
    versions below 5.1, a fatal error is displayed and execution halts.

.OUTPUTS
    System.Collections.Hashtable
    Returns a hashtable with keys:
    - Passed (System.Boolean): Indicates if version validation passed
    - Version (System.Version): The current PowerShell version object

.EXAMPLE
    $versionResult = Test-PowerShellVersion
    if ($versionResult.Passed) {
        Write-Host "Version: $($versionResult.Version)"
    }

.NOTES
    Author: WinOptimizer Project
    Version: 1.0.0
    Exit code 1 if version validation fails.
#>

#region Function: Test-PowerShellVersion
<#
.SYNOPSIS
    Tests PowerShell version compatibility with interactive prompts for PowerShell 7+.

.DESCRIPTION
    Test-PowerShellVersion validates the current PowerShell version against
    the minimum required version (5.1). Handles three scenarios:
    1. PowerShell 7+: Shows interactive prompt allowing user to proceed or exit
    2. PowerShell < 5.1: Shows fatal error and exits
    3. PowerShell 5.1-6.x: Returns success

.OUTPUTS
    System.Collections.Hashtable
    Returns hashtable with:
    - Passed (bool): True if validation passed, false otherwise
    - Version (System.Version): Current PowerShell version object

.EXAMPLE
    $result = Test-PowerShellVersion
    Write-Host "Passed: $($result.Passed), Version: $($result.Version)"

.NOTES
    Logs all version checks via Write-OptLog.
    Exit code 1 if validation fails.
#>
function Test-PowerShellVersion {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    #region Version Detection
    $currentVersion = $PSVersionTable.PSVersion
    $minVersion = [version]"5.1"
    #endregion

    #region Scenario 1: PowerShell 7+ (pwsh)
    if ($currentVersion.Major -ge 7) {
        $message = "Detected PowerShell $($currentVersion.Major).$($currentVersion.Minor). This script is designed for PowerShell 5.1. Proceed? (Y/N)"
        $proceed = Read-Host -Prompt $message

        if ($proceed -ne 'Y' -and $proceed -ne 'y') {
            Write-Host "Exiting at user request." -ForegroundColor Yellow

            # Log user declined to proceed
            $null = Write-OptLog -Module "SafetyGates" -Operation "VersionCheck" -Target "PowerShellVersion" -Values @{
                CurrentVersion  = "$($currentVersion.Major).$($currentVersion.Minor)"
                RequiredVersion = "5.1+"
            } -Result "Error" -Message "User declined to proceed with PowerShell 7+" -Level "ERROR"

            exit 1
        }

        # Log proceeding with PowerShell 7+
        $null = Write-OptLog -Module "SafetyGates" -Operation "VersionCheck" -Target "PowerShellVersion" -Values @{
            CurrentVersion  = "$($currentVersion.Major).$($currentVersion.Minor)"
            RequiredVersion = "5.1+"
        } -Result "Warning" -Message "Proceeding with PowerShell 7+ despite design target" -Level "WARNING"

        return @{
            Passed  = $true
            Version = $currentVersion
        }
    }
    #endregion

    #region Scenario 2: PowerShell < 5.1
    if ($currentVersion -lt $minVersion) {
        $errorMsg = "ERROR: PowerShell 5.1+ required. Current version: $($currentVersion.Major).$($currentVersion.Minor) is not supported. Exiting."
        Write-Host $errorMsg -ForegroundColor Red

        # Log version error
        $null = Write-OptLog -Module "SafetyGates" -Operation "VersionCheck" -Target "PowerShellVersion" -Values @{
            CurrentVersion  = "$($currentVersion.Major).$($currentVersion.Minor)"
            RequiredVersion = "5.1+"
        } -Result "Error" -Message $errorMsg -Level "ERROR"

        exit 1
    }
    #endregion

    #region Scenario 3: PowerShell 5.1-6.x (Valid)
    $null = Write-OptLog -Module "SafetyGates" -Operation "VersionCheck" -Target "PowerShellVersion" -Values @{
        CurrentVersion  = "$($currentVersion.Major).$($currentVersion.Minor)"
        RequiredVersion = "5.1+"
    } -Result "Success" -Message "PowerShell version validation passed" -Level "SUCCESS"

    return @{
        Passed  = $true
        Version = $currentVersion
    }
    #endregion
}
#endregion
