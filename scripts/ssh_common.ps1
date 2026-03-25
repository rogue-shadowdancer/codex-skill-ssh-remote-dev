Set-StrictMode -Version Latest

function Format-DisplayToken {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Token,

        [string[]]$SensitiveValues = @()
    )

    if ($SensitiveValues -contains $Token) {
        return "<redacted>"
    }

    if ($Token -match '[\s"`]') {
        return '"' + $Token.Replace('"', '\"') + '"'
    }

    return $Token
}

function Write-DryRunCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Executable,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [string[]]$SensitiveValues = @()
    )

    $tokens = @($Executable) + ($Arguments | ForEach-Object { Format-DisplayToken -Token $_ -SensitiveValues $SensitiveValues })
    Write-Output ("DRYRUN: " + ($tokens -join " "))
}

function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Executable,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [switch]$DryRun,

        [string[]]$SensitiveValues = @()
    )

    if ($DryRun) {
        Write-DryRunCommand -Executable $Executable -Arguments $Arguments -SensitiveValues $SensitiveValues
        return
    }

    & $Executable @Arguments

    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

function Get-ParamikoHelperPath {
    return Join-Path $PSScriptRoot "ssh_paramiko.py"
}

function Resolve-OpenSshExecutable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DefaultExecutable,

        [string]$PreferredExecutable
    )

    if (-not [string]::IsNullOrWhiteSpace($PreferredExecutable)) {
        return $PreferredExecutable
    }

    $runningOnWindows = $false

    if ($env:OS -eq "Windows_NT") {
        $runningOnWindows = $true
    }
    elseif ($PSVersionTable.PSVersion.Major -ge 6 -and $IsWindows) {
        $runningOnWindows = $true
    }

    if ($runningOnWindows) {
        $windowsDirectory = $env:WINDIR

        if (-not [string]::IsNullOrWhiteSpace($windowsDirectory)) {
            $candidatePath = Join-Path $windowsDirectory "System32\OpenSSH\$DefaultExecutable"

            if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
                return $candidatePath
            }
        }
    }

    return $DefaultExecutable
}

function Resolve-TargetConnectionInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Target,

        [string]$Username,

        [string]$HostName
    )

    $resolvedUser = $Username
    $resolvedHost = $HostName

    if ([string]::IsNullOrWhiteSpace($resolvedHost)) {
        if ($Target -match '^(?<user>[^@]+)@(?<host>.+)$') {
            if ([string]::IsNullOrWhiteSpace($resolvedUser)) {
                $resolvedUser = $Matches.user
            }

            $resolvedHost = $Matches.host
        }
        else {
            $resolvedHost = $Target
        }
    }

    return [pscustomobject]@{
        Username = $resolvedUser
        HostName = $resolvedHost
    }
}

function Quote-PosixLiteral {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    return "'" + ($Value -replace "'", "'`"`'`"`'") + "'"
}

function Get-RemoteShellCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,

        [string]$RemoteDir
    )

    $wrappedCommand = $Command

    if (-not [string]::IsNullOrWhiteSpace($RemoteDir)) {
        $wrappedCommand = "cd $(Quote-PosixLiteral -Value $RemoteDir) && $wrappedCommand"
    }

    return "sh -lc $(Quote-PosixLiteral -Value $wrappedCommand)"
}

function New-SshBaseArguments {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Target,

        [int]$Port,

        [string]$IdentityFile,

        [string]$ConfigFile,

        [switch]$IdentitiesOnly
    )

    $arguments = @(
        "-o", "BatchMode=yes",
        "-o", "ServerAliveInterval=15",
        "-o", "ServerAliveCountMax=3",
        "-o", "ConnectTimeout=10",
        "-o", "StrictHostKeyChecking=accept-new"
    )

    if ($Port -gt 0) {
        $arguments += "-p"
        $arguments += [string]$Port
    }

    if (-not [string]::IsNullOrWhiteSpace($ConfigFile)) {
        $arguments += "-F"
        $arguments += $ConfigFile
    }

    if (-not [string]::IsNullOrWhiteSpace($IdentityFile)) {
        $arguments += "-i"
        $arguments += $IdentityFile
    }

    if ($IdentitiesOnly) {
        $arguments += "-o"
        $arguments += "IdentitiesOnly=yes"
    }

    $arguments += $Target
    return $arguments
}

function New-ScpBaseArguments {
    param(
        [int]$Port,

        [string]$IdentityFile,

        [string]$ConfigFile,

        [switch]$IdentitiesOnly
    )

    $arguments = @(
        "-o", "BatchMode=yes",
        "-o", "ConnectTimeout=10",
        "-o", "StrictHostKeyChecking=accept-new"
    )

    if ($Port -gt 0) {
        $arguments += "-P"
        $arguments += [string]$Port
    }

    if (-not [string]::IsNullOrWhiteSpace($ConfigFile)) {
        $arguments += "-F"
        $arguments += $ConfigFile
    }

    if (-not [string]::IsNullOrWhiteSpace($IdentityFile)) {
        $arguments += "-i"
        $arguments += $IdentityFile
    }

    if ($IdentitiesOnly) {
        $arguments += "-o"
        $arguments += "IdentitiesOnly=yes"
    }

    return $arguments
}

function Get-RemoteSpec {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Target,

        [Parameter(Mandatory = $true)]
        [string]$RemotePath
    )

    $normalizedPath = $RemotePath.Replace('\', '/')
    return "${Target}:$(Quote-PosixLiteral -Value $normalizedPath)"
}

function Get-RemoteDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RemotePath
    )

    $normalizedPath = $RemotePath.Replace('\', '/')
    $lastSlash = $normalizedPath.LastIndexOf('/')

    if ($lastSlash -lt 0) {
        return "."
    }

    if ($lastSlash -eq 0) {
        return "/"
    }

    return $normalizedPath.Substring(0, $lastSlash)
}

function Get-RemoteLeafName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RemotePath
    )

    $normalizedPath = $RemotePath.Replace('\', '/')
    $lastSlash = $normalizedPath.LastIndexOf('/')

    if ($lastSlash -lt 0) {
        return $normalizedPath
    }

    return $normalizedPath.Substring($lastSlash + 1)
}
