[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DestinationDir,

    [Parameter(Mandatory = $true)]
    [string]$HostAlias,

    [Parameter(Mandatory = $true)]
    [string]$HostName,

    [Parameter(Mandatory = $true)]
    [string]$IdentityFile,

    [string]$Username,

    [int]$Port,

    [string]$KnownHostsFile,

    [switch]$DryRun
)

Set-StrictMode -Version Latest

function Resolve-LocalPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
}

function Convert-ToSshConfigPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return (Resolve-LocalPath -Path $Path).Replace('\', '/')
}

function Ensure-Directory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [switch]$DryRun
    )

    if (Test-Path -LiteralPath $Path -PathType Container) {
        return
    }

    if ($DryRun) {
        Write-Output "DRYRUN: New-Item -ItemType Directory -Force -Path $Path"
        return
    }

    New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

function Copy-OrCreateFile {
    param(
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,
        [switch]$DryRun
    )

    if ([string]::IsNullOrWhiteSpace($SourcePath)) {
        if ($DryRun) {
            Write-Output "DRYRUN: New-Item -ItemType File -Force -Path $DestinationPath"
            return
        }

        if (-not (Test-Path -LiteralPath $DestinationPath -PathType Leaf)) {
            New-Item -ItemType File -Force -Path $DestinationPath | Out-Null
        }

        return
    }

    $resolvedSourcePath = Resolve-LocalPath -Path $SourcePath

    if (-not (Test-Path -LiteralPath $resolvedSourcePath -PathType Leaf)) {
        throw "Source file does not exist: $SourcePath"
    }

    if ($DryRun) {
        Write-Output "DRYRUN: Copy-Item -LiteralPath $resolvedSourcePath -Destination $DestinationPath -Force"
        return
    }

    Copy-Item -LiteralPath $resolvedSourcePath -Destination $DestinationPath -Force
}

$resolvedDestinationDir = Resolve-LocalPath -Path $DestinationDir
$resolvedIdentityFile = Resolve-LocalPath -Path $IdentityFile

if (-not (Test-Path -LiteralPath $resolvedIdentityFile -PathType Leaf)) {
    throw "Identity file does not exist: $IdentityFile"
}

Ensure-Directory -Path $resolvedDestinationDir -DryRun:$DryRun

$destinationIdentityFile = Join-Path $resolvedDestinationDir (Split-Path -Leaf $resolvedIdentityFile)
$destinationPublicKeyFile = "$destinationIdentityFile.pub"
$sourcePublicKeyFile = "$resolvedIdentityFile.pub"
$destinationKnownHostsFile = Join-Path $resolvedDestinationDir "known_hosts"
$destinationConfigFile = Join-Path $resolvedDestinationDir "config"

Copy-OrCreateFile -SourcePath $resolvedIdentityFile -DestinationPath $destinationIdentityFile -DryRun:$DryRun

if (Test-Path -LiteralPath $sourcePublicKeyFile -PathType Leaf) {
    Copy-OrCreateFile -SourcePath $sourcePublicKeyFile -DestinationPath $destinationPublicKeyFile -DryRun:$DryRun
}

Copy-OrCreateFile -SourcePath $KnownHostsFile -DestinationPath $destinationKnownHostsFile -DryRun:$DryRun

$configLines = @(
    "Host $HostAlias",
    "    HostName $HostName"
)

if (-not [string]::IsNullOrWhiteSpace($Username)) {
    $configLines += "    User $Username"
}

if ($Port -gt 0) {
    $configLines += "    Port $Port"
}

$configLines += @(
    "    IdentityFile $(Convert-ToSshConfigPath -Path $destinationIdentityFile)",
    "    IdentitiesOnly yes",
    "    BatchMode yes",
    "    ServerAliveInterval 15",
    "    ServerAliveCountMax 3",
    "    ConnectTimeout 10",
    "    StrictHostKeyChecking accept-new",
    "    UserKnownHostsFile $(Convert-ToSshConfigPath -Path $destinationKnownHostsFile)"
)

$configContent = ($configLines -join [Environment]::NewLine) + [Environment]::NewLine

if ($DryRun) {
    Write-Output "DRYRUN: Set-Content -LiteralPath $destinationConfigFile -Value <generated sandbox ssh config>"
    Write-Output ""
    Write-Output $configContent.TrimEnd()
}
else {
    Set-Content -LiteralPath $destinationConfigFile -Value $configContent -NoNewline
    Write-Output "Config path: $destinationConfigFile"
    Write-Output "Identity path: $destinationIdentityFile"
    Write-Output "Known hosts path: $destinationKnownHostsFile"
}
