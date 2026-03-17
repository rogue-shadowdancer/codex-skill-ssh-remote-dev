[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Target,

    [Parameter(Mandatory = $true)]
    [string]$Command,

    [string]$RemoteDir,

    [int]$Port,

    [string]$IdentityFile,

    [string]$Username,

    [string]$HostName,

    [string]$Password,

    [switch]$Tty,

    [switch]$DryRun
)

Set-StrictMode -Version Latest
. "$PSScriptRoot\ssh_common.ps1"

if (-not [string]::IsNullOrWhiteSpace($Password)) {
    $connection = Resolve-TargetConnectionInfo -Target $Target -Username $Username -HostName $HostName

    if ([string]::IsNullOrWhiteSpace($connection.Username)) {
        throw "Username is required for password authentication. Pass user@host as -Target or provide -Username."
    }

    $pythonArguments = @(
        (Get-ParamikoHelperPath),
        "exec",
        "--host", $connection.HostName,
        "--user", $connection.Username,
        "--password", $Password,
        "--command", $Command
    )

    if ($Port -gt 0) {
        $pythonArguments += "--port"
        $pythonArguments += [string]$Port
    }

    if (-not [string]::IsNullOrWhiteSpace($RemoteDir)) {
        $pythonArguments += "--remote-dir"
        $pythonArguments += $RemoteDir
    }

    if ($Tty) {
        $pythonArguments += "--tty"
    }

    Invoke-ExternalCommand -Executable "python" -Arguments $pythonArguments -DryRun:$DryRun -SensitiveValues @($Password)
    return
}

$arguments = New-SshBaseArguments -Target $Target -Port $Port -IdentityFile $IdentityFile

if ($Tty) {
    $arguments = @("-tt") + $arguments
}

$arguments += Get-RemoteShellCommand -Command $Command -RemoteDir $RemoteDir

Invoke-ExternalCommand -Executable "ssh" -Arguments $arguments -DryRun:$DryRun
