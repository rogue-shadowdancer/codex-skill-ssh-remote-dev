[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Target,

    [Parameter(Mandatory = $true)]
    [string]$RemotePath,

    [Parameter(Mandatory = $true)]
    [string]$LocalPath,

    [int]$Port,

    [string]$IdentityFile,

    [string]$Username,

    [string]$HostName,

    [string]$Password,

    [switch]$DryRun
)

Set-StrictMode -Version Latest
. "$PSScriptRoot\ssh_common.ps1"

$parentDirectory = Split-Path -Parent $LocalPath

if (-not [string]::IsNullOrWhiteSpace($parentDirectory) -and -not (Test-Path -LiteralPath $parentDirectory)) {
    if ($DryRun) {
        Write-Output "DRYRUN: New-Item -ItemType Directory -Force -Path $parentDirectory"
    }
    else {
        New-Item -ItemType Directory -Force -Path $parentDirectory | Out-Null
    }
}

if (-not [string]::IsNullOrWhiteSpace($Password)) {
    $connection = Resolve-TargetConnectionInfo -Target $Target -Username $Username -HostName $HostName

    if ([string]::IsNullOrWhiteSpace($connection.Username)) {
        throw "Username is required for password authentication. Pass user@host as -Target or provide -Username."
    }

    $pythonArguments = @(
        (Get-ParamikoHelperPath),
        "fetch",
        "--host", $connection.HostName,
        "--user", $connection.Username,
        "--password", $Password,
        "--remote-path", $RemotePath,
        "--local-path", $LocalPath
    )

    if ($Port -gt 0) {
        $pythonArguments += "--port"
        $pythonArguments += [string]$Port
    }

    Invoke-ExternalCommand -Executable "python" -Arguments $pythonArguments -DryRun:$DryRun -SensitiveValues @($Password)
    return
}

$arguments = New-ScpBaseArguments -Port $Port -IdentityFile $IdentityFile
$arguments += Get-RemoteSpec -Target $Target -RemotePath $RemotePath
$arguments += $LocalPath

Invoke-ExternalCommand -Executable "scp" -Arguments $arguments -DryRun:$DryRun
