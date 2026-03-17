[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Target,

    [Parameter(Mandatory = $true)]
    [string]$LocalPath,

    [Parameter(Mandatory = $true)]
    [string]$RemotePath,

    [int]$Port,

    [string]$IdentityFile,

    [string]$Username,

    [string]$HostName,

    [string]$Password,

    [switch]$BackupExisting,

    [switch]$DryRun
)

Set-StrictMode -Version Latest
. "$PSScriptRoot\ssh_common.ps1"

if (-not (Test-Path -LiteralPath $LocalPath -PathType Leaf)) {
    throw "Local file does not exist: $LocalPath"
}

if (-not [string]::IsNullOrWhiteSpace($Password)) {
    $connection = Resolve-TargetConnectionInfo -Target $Target -Username $Username -HostName $HostName

    if ([string]::IsNullOrWhiteSpace($connection.Username)) {
        throw "Username is required for password authentication. Pass user@host as -Target or provide -Username."
    }

    $pythonArguments = @(
        (Get-ParamikoHelperPath),
        "push",
        "--host", $connection.HostName,
        "--user", $connection.Username,
        "--password", $Password,
        "--local-path", $LocalPath,
        "--remote-path", $RemotePath
    )

    if ($Port -gt 0) {
        $pythonArguments += "--port"
        $pythonArguments += [string]$Port
    }

    if ($BackupExisting) {
        $pythonArguments += "--backup-existing"
    }

    Invoke-ExternalCommand -Executable "python" -Arguments $pythonArguments -DryRun:$DryRun -SensitiveValues @($Password)
    return
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$remoteDirectory = Get-RemoteDirectory -RemotePath $RemotePath
$remoteLeafName = Get-RemoteLeafName -RemotePath $RemotePath

if ($remoteDirectory -eq "/") {
    $temporaryRemotePath = "/.codex-upload-$timestamp-$remoteLeafName"
}
elseif ($remoteDirectory -eq ".") {
    $temporaryRemotePath = ".codex-upload-$timestamp-$remoteLeafName"
}
else {
    $temporaryRemotePath = "$remoteDirectory/.codex-upload-$timestamp-$remoteLeafName"
}

$backupRemotePath = "$RemotePath.bak.$timestamp"

$sshArguments = New-SshBaseArguments -Target $Target -Port $Port -IdentityFile $IdentityFile
$scpArguments = New-ScpBaseArguments -Port $Port -IdentityFile $IdentityFile

$prepareCommand = Get-RemoteShellCommand -Command "mkdir -p $(Quote-PosixLiteral -Value $remoteDirectory)"
$prepareArguments = $sshArguments + $prepareCommand
Invoke-ExternalCommand -Executable "ssh" -Arguments $prepareArguments -DryRun:$DryRun

$uploadArguments = $scpArguments + @(
    $LocalPath,
    (Get-RemoteSpec -Target $Target -RemotePath $temporaryRemotePath)
)
Invoke-ExternalCommand -Executable "scp" -Arguments $uploadArguments -DryRun:$DryRun

$finalizeParts = @()

if ($BackupExisting) {
    $finalizeParts += "if [ -e $(Quote-PosixLiteral -Value $RemotePath) ]; then cp -p $(Quote-PosixLiteral -Value $RemotePath) $(Quote-PosixLiteral -Value $backupRemotePath); fi"
}

$finalizeParts += "if [ -e $(Quote-PosixLiteral -Value $RemotePath) ]; then chmod --reference=$(Quote-PosixLiteral -Value $RemotePath) $(Quote-PosixLiteral -Value $temporaryRemotePath) 2>/dev/null || true; fi"
$finalizeParts += "mv $(Quote-PosixLiteral -Value $temporaryRemotePath) $(Quote-PosixLiteral -Value $RemotePath)"

$finalizeCommand = Get-RemoteShellCommand -Command ($finalizeParts -join "; ")
$finalizeArguments = $sshArguments + $finalizeCommand
Invoke-ExternalCommand -Executable "ssh" -Arguments $finalizeArguments -DryRun:$DryRun

if ($BackupExisting) {
    Write-Output "Backup path: $backupRemotePath"
}
