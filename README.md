# codex-skill-ssh-remote-dev

`ssh-remote-dev` is a Codex skill for inspecting, editing, syncing, and testing code on a remote Linux or POSIX host over SSH.

It is designed around a local-first workflow:

- fetch remote files into a local staging area
- edit them with `apply_patch`
- push them back safely with backups
- run targeted validation on the remote host

The skill supports both key-based SSH and password-based SSH. When `--password` or `-Password` is supplied, the platform wrappers automatically fall back to a bundled `paramiko` backend.

## Repository Layout

- `SKILL.md`: skill instructions and trigger metadata
- `agents/openai.yaml`: Codex UI metadata
- `references/`: usage notes and workflow examples
- `scripts/`: PowerShell wrappers, cross-platform Python wrappers, and the Python password-auth backend

## Included Scripts

- `scripts/ssh_exec.ps1`
- `scripts/ssh_fetch.ps1`
- `scripts/ssh_push.ps1`
- `scripts/ssh_exec.py`
- `scripts/ssh_fetch.py`
- `scripts/ssh_push.py`
- `scripts/ssh_paramiko.py`

## Platform Support

Use the `.ps1` wrappers in Windows PowerShell and the `.py` wrappers with `python3` on macOS/Linux. The Python wrappers shell out to native `ssh` and `scp` for key-based access and only require `paramiko` when password-based mode is used.

## Installation

Install the skill contents into your Codex skills directory as `ssh-remote-dev`. The installed skill folder should contain the skill files only:

- `SKILL.md`
- `agents/`
- `references/`
- `scripts/`

macOS/Linux validation setup:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install PyYAML paramiko
PYTHONDONTWRITEBYTECODE=1 .venv/bin/python "$CODEX_HOME/skills/.system/skill-creator/scripts/quick_validate.py" .
```

Install on macOS/Linux:

```bash
mkdir -p "$CODEX_HOME/skills/ssh-remote-dev"
rsync -a --delete \
  --exclude '.git' \
  --exclude '.venv' \
  --exclude '__pycache__' \
  ./ "$CODEX_HOME/skills/ssh-remote-dev/"
```

Install on Windows PowerShell:

```powershell
Copy-Item -Recurse -Force . 'C:\Users\<you>\.codex\skills\ssh-remote-dev'
```

## Typical Usage

Read-only remote command:

```bash
python3 scripts/ssh_exec.py --target app-staging --remote-dir /srv/app --command "git status --short"
# Windows PowerShell: .\scripts\ssh_exec.ps1 -Target app-staging -RemoteDir /srv/app -Command "git status --short"
```

Password-based command:

```bash
python3 scripts/ssh_exec.py --target radio@10.203.52.6 --password "<password>" --command "pwd"
# Windows PowerShell: .\scripts\ssh_exec.ps1 -Target radio@10.203.52.6 -Password "<password>" -Command "pwd"
```

Fetch a remote file:

```bash
python3 scripts/ssh_fetch.py --target app-staging --remote-path /srv/app/src/api/routes.py --local-path tmp/ssh-remote-dev/app-staging/src/api/routes.py
# Windows PowerShell: .\scripts\ssh_fetch.ps1 -Target app-staging -RemotePath /srv/app/src/api/routes.py -LocalPath tmp/ssh-remote-dev/app-staging/src/api/routes.py
```

Push a local file back:

```bash
python3 scripts/ssh_push.py --target app-staging --local-path tmp/ssh-remote-dev/app-staging/src/api/routes.py --remote-path /srv/app/src/api/routes.py --backup-existing
# Windows PowerShell: .\scripts\ssh_push.ps1 -Target app-staging -LocalPath tmp/ssh-remote-dev/app-staging/src/api/routes.py -RemotePath /srv/app/src/api/routes.py -BackupExisting
```

## Notes

- The skill assumes the remote host has a POSIX shell and common file utilities.
- Remote service restarts, destructive commands, and production-impacting actions should still be treated as explicit approvals.
- Passwords should be passed transiently and not committed to disk.
- Local-only directories such as `.venv/` and `__pycache__/` should remain untracked.
