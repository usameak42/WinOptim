#Requires -Version 5.1

<#
.SYNOPSIS
    Transfers registry key ownership from TrustedInstaller to Administrators.

.DESCRIPTION
    The Take-RegistryOwnership function uses .NET System.Security.AccessControl
    classes to take ownership of a registry key and grant FullControl to the
    Administrators group. This is required for modifying keys owned by
    TrustedInstaller (e.g., Windows Search keys).

.PARAMETER Path
    The registry path to take ownership of (e.g., "HKLM:\SOFTWARE\Microsoft\Windows Search").

.EXAMPLE
    Take-RegistryOwnership -Path "HKLM:\SOFTWARE\Microsoft\Windows Search"

.NOTES
    Requires elevation. Use with caution - ownership changes are irreversible without manual intervention.
    Author: WinOptimizer Project
    Version: 1.0.0
#>
function Take-RegistryOwnership {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    #region Security Critical
    # This function modifies registry ACLs. Test thoroughly in VM environment.
    #endregion

    try {
        #region Open Registry Key with TakeOwnership Rights
        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
            $Path.Replace('HKLM:', ''),
            [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
            [System.Security.AccessControl.RegistryRights]::TakeOwnership
        )

        if ($null -eq $key) {
            throw "Failed to open registry key: $Path"
        }
        #endregion

        #region Get Current ACL and Set Owner
        $acl = $key.GetAccessControl()
        $adminGroup = [System.Security.Principal.NTAccount]"Administrators"
        $acl.SetOwner($adminGroup)
        #endregion

        #region Apply Modified ACL
        $key.SetAccessControl($acl)
        $key.Close()
        #endregion

        #region Grant FullControl to Administrators
        $acl = Get-Acl -Path $Path
        $accessRule = New-Object System.Security.AccessControl.RegistryAccessRule(
            $adminGroup,
            [System.Security.AccessControl.RegistryRights]::FullControl,
            [System.Security.AccessControl.InheritanceFlags]::ContainerInherit,
            [System.Security.AccessControl.PropagationFlags]::None,
            [System.Security.AccessControl.AccessControlType]::Allow
        )
        $acl.SetAccessRule($accessRule)
        Set-Acl -Path $Path -AclObject $acl
        #endregion

        return $true
    }
    catch {
        Write-Error "Failed to take ownership of $Path`: $_"
        return $false
    }
}
