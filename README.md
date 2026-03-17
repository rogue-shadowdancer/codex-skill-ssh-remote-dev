# ssh-remote-dev-skill

`ssh-remote-dev` is a Codex skill for inspecting, editing, syncing, and testing code on a remote Linux or POSIX host over SSH.

It is designed around a local-first workflow:

- fetch remote files into a local staging area
- edit them with `apply_patch`
- push them back safely with backups
- run targeted validation on the remote host

The skill supports both key-based SSH and password-based SSH. When `-Password` is supplied, the PowerShell wrappers automatically fall back to a bundled `paramiko` backend.

## Repository Layout

- `SKILL.md`: skill instructions and trigger metadata
- `agents/openai.yaml`: Codex UI metadata
- `references/`: usage notes and workflow examples
- `scripts/`: PowerShell wrappers and the Python password-auth backend

## Included Scripts

- `scripts/ssh_exec.ps1`
- `scripts/ssh_fetch.ps1`
- `scripts/ssh_push.ps1`
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

Password-based command:

```powershell
scripts/ssh_exec.ps1 -Target radio@10.203.52.6 -Password "<password>" -Command "pwd"
```

Fetch a remote file:

```powershell
scripts/ssh_fetch.ps1 -Target app-staging -RemotePath /srv/app/src/api/routes.py -LocalPath tmp/ssh-remote-dev/app-staging/src/api/routes.py
```

Push a local file back:

```powershell
scripts/ssh_push.ps1 -Target app-staging -LocalPath tmp/ssh-remote-dev/app-staging/src/api/routes.py -RemotePath /srv/app/src/api/routes.py -BackupExisting
```

## Notes

- The skill assumes the remote host has a POSIX shell and common file utilities.
- Remote service restarts, destructive commands, and production-impacting actions should still be treated as explicit approvals.
- Passwords should be passed transiently and not committed to disk.
