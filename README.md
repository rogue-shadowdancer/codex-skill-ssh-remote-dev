# codex-ssh-remote-dev-skill

`ssh-remote-dev` is a Codex skill for inspecting, editing, syncing, and testing code on a remote Linux or POSIX host over SSH.

It is designed around a local-first workflow:

- fetch remote files into a local staging area
- edit them with `apply_patch`
- push them back safely with backups
- run targeted validation on the remote host

The skill supports both key-based SSH and password-based SSH. When `-Password` is supplied, the PowerShell wrappers automatically fall back to a bundled `paramiko` backend.

On Windows, the wrappers prefer the built-in OpenSSH binaries from `C:\Windows\System32\OpenSSH\` when available. This avoids a class of failures where Git for Windows `ssh.exe` or a mismatched sandbox user context breaks key-based auth before the remote handshake starts.

## Repository Layout

- `SKILL.md`: skill instructions and trigger metadata
- `agents/openai.yaml`: Codex UI metadata
- `references/`: usage notes and workflow examples
- `scripts/`: PowerShell wrappers and the Python password-auth backend

## Included Scripts

- `scripts/ssh_exec.ps1`
- `scripts/ssh_fetch.ps1`
- `scripts/ssh_push.ps1`
- `scripts/setup_sandbox_ssh.ps1`
- `scripts/ssh_paramiko.py`

## Installation

Copy this directory into your Codex skills directory as `ssh-remote-dev`:

```powershell
Copy-Item -Recurse -Force . 'C:\Users\<you>\.codex\skills\ssh-remote-dev'
```

## Typical Usage

Read-only remote command:

```powershell
scripts/ssh_exec.ps1 -Target app-staging -RemoteDir /srv/app -Command "git status --short"
```

Windows or sandbox-local SSH bundle:

```powershell
scripts/setup_sandbox_ssh.ps1 `
  -DestinationDir tmp/ssh-sandbox/demo-host `
  -HostAlias demo-host `
  -HostName 203.0.113.10 `
  -Username dev `
  -IdentityFile C:/Users/<you>/.ssh/id_ed25519

scripts/ssh_exec.ps1 `
  -Target demo-host `
  -ConfigFile tmp/ssh-sandbox/demo-host/config `
  -IdentityFile tmp/ssh-sandbox/demo-host/id_ed25519 `
  -IdentitiesOnly `
  -Command "exit"
```

Password-based command:

```powershell
scripts/ssh_exec.ps1 -Target dev@203.0.113.10 -Password "<password>" -Command "pwd"
```

Fetch a remote file:

```powershell
scripts/ssh_fetch.ps1 -Target app-staging -RemotePath /srv/app/src/api/routes.py -LocalPath tmp/ssh-remote-dev/app-staging/src/api/routes.py
```

Push a local file back:

```powershell
scripts/ssh_push.ps1 -Target app-staging -LocalPath tmp/ssh-remote-dev/app-staging/src/api/routes.py -RemotePath /srv/app/src/api/routes.py -BackupExisting
```

Git push with an explicit Windows OpenSSH config:

```powershell
git -c core.sshCommand='C:/Windows/System32/OpenSSH/ssh.exe -F "C:/path/to/tmp/ssh-sandbox/demo-host/config"' push origin my-branch
```

## Notes

- The skill assumes the remote host has a POSIX shell and common file utilities.
- If a sandboxed or alternate Windows user cannot safely read the real `~/.ssh`, generate a minimal workspace-local config instead of copying the full profile blindly.
- The generated sandbox config writes host keys to the local bundle's `known_hosts`, which avoids polluting the real user profile.
- Remote service restarts, destructive commands, and production-impacting actions should still be treated as explicit approvals.
- Passwords should be passed transiently and not committed to disk.
