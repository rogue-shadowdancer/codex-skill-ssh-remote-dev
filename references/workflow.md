# SSH Workflow Recipes

When using the bundled helpers, prefer `python3 scripts/*.py` on macOS/Linux and `.\scripts\*.ps1` in Windows PowerShell.

## Minimum Inputs

- SSH target or alias
- Remote project root
- Remote file path or paths
- Narrow validation command

## Inspect The Remote Repo

Use read-only probes first.

```bash
python3 scripts/ssh_exec.py --target app-staging --remote-dir /srv/app --command "git status --short"
python3 scripts/ssh_exec.py --target app-staging --remote-dir /srv/app --command "git branch --show-current"
python3 scripts/ssh_exec.py --target app-staging --remote-dir /srv/app --command "git rev-parse --show-toplevel"
# Windows PowerShell: .\scripts\ssh_exec.ps1 -Target app-staging -RemoteDir /srv/app -Command "git status --short"
```

If the server is password-only, add `-Password` and prefer `user@host` in `-Target`:

```bash
python3 scripts/ssh_exec.py --target radio@10.203.52.6 --password "<password>" --command "pwd"
# Windows PowerShell: .\scripts\ssh_exec.ps1 -Target radio@10.203.52.6 -Password "<password>" -Command "pwd"
```

## Stage One File Locally

Mirror the remote path under `tmp/ssh-remote-dev/<target>/`.

```bash
python3 scripts/ssh_fetch.py \
  --target app-staging \
  --remote-path /srv/app/src/api/routes.py \
  --local-path tmp/ssh-remote-dev/app-staging/src/api/routes.py
# Windows PowerShell: .\scripts\ssh_fetch.ps1 -Target app-staging -RemotePath /srv/app/src/api/routes.py -LocalPath tmp/ssh-remote-dev/app-staging/src/api/routes.py
```

After fetching, edit the local staged copy with `apply_patch`.

## Push A Changed File Back

Use a backup unless the user explicitly says not to.

```bash
python3 scripts/ssh_push.py \
  --target app-staging \
  --local-path tmp/ssh-remote-dev/app-staging/src/api/routes.py \
  --remote-path /srv/app/src/api/routes.py \
  --backup-existing
# Windows PowerShell: .\scripts\ssh_push.ps1 -Target app-staging -LocalPath tmp/ssh-remote-dev/app-staging/src/api/routes.py -RemotePath /srv/app/src/api/routes.py -BackupExisting
```

The backup naming pattern is `<remote-path>.bak.<yyyyMMdd-HHmmss>`.

## Run Targeted Validation

Start narrow.

```bash
python3 scripts/ssh_exec.py \
  --target app-staging \
  --remote-dir /srv/app \
  --command "pytest tests/api/test_routes.py -q"
# Windows PowerShell: .\scripts\ssh_exec.ps1 -Target app-staging -RemoteDir /srv/app -Command "pytest tests/api/test_routes.py -q"
```

If the project needs environment setup, include it in the command:

```bash
python3 scripts/ssh_exec.py \
  --target app-staging \
  --remote-dir /srv/app \
  --command "source venv/bin/activate && pytest tests/api/test_routes.py -q"
# Windows PowerShell: .\scripts\ssh_exec.ps1 -Target app-staging -RemoteDir /srv/app -Command "source venv/bin/activate && pytest tests/api/test_routes.py -q"
```

## Dry Run

All bundled scripts support `-DryRun`. Use it when first assembling a command or when checking quoting. Password values are redacted in dry-run output.

## Common Failures

- `Permission denied (publickey)`: confirm the SSH alias, username, agent, or `-IdentityFile`.
- `Host key verification failed`: verify the host key and establish trust before retrying.
- `command not found`: the remote shell may not load the expected environment. Use full paths or source the required profile inside `-Command`.
- `scp` path errors: keep remote paths absolute when possible and avoid spaces unless required.
