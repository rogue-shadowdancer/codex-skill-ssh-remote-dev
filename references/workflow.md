# SSH Workflow Recipes

## Minimum Inputs

- SSH target or alias
- Remote project root
- Remote file path or paths
- Narrow validation command

## Inspect The Remote Repo

Use read-only probes first.

```powershell
scripts/ssh_exec.ps1 -Target app-staging -RemoteDir /srv/app -Command "git status --short"
scripts/ssh_exec.ps1 -Target app-staging -RemoteDir /srv/app -Command "git branch --show-current"
scripts/ssh_exec.ps1 -Target app-staging -RemoteDir /srv/app -Command "git rev-parse --show-toplevel"
```

If the server is password-only, add `-Password` and prefer `user@host` in `-Target`:

```powershell
scripts/ssh_exec.ps1 -Target radio@10.203.52.6 -Password "<password>" -Command "pwd"
```

## Stage One File Locally

Mirror the remote path under `tmp/ssh-remote-dev/<target>/`.

```powershell
scripts/ssh_fetch.ps1 `
  -Target app-staging `
  -RemotePath /srv/app/src/api/routes.py `
  -LocalPath tmp/ssh-remote-dev/app-staging/src/api/routes.py
```

After fetching, edit the local staged copy with `apply_patch`.

## Push A Changed File Back

Use a backup unless the user explicitly says not to.

```powershell
scripts/ssh_push.ps1 `
  -Target app-staging `
  -LocalPath tmp/ssh-remote-dev/app-staging/src/api/routes.py `
  -RemotePath /srv/app/src/api/routes.py `
  -BackupExisting
```

The backup naming pattern is `<remote-path>.bak.<yyyyMMdd-HHmmss>`.

## Run Targeted Validation

Start narrow.

```powershell
scripts/ssh_exec.ps1 `
  -Target app-staging `
  -RemoteDir /srv/app `
  -Command "pytest tests/api/test_routes.py -q"
```

If the project needs environment setup, include it in the command:

```powershell
scripts/ssh_exec.ps1 `
  -Target app-staging `
  -RemoteDir /srv/app `
  -Command "source venv/bin/activate && pytest tests/api/test_routes.py -q"
```

## Dry Run

All bundled scripts support `-DryRun`. Use it when first assembling a command or when checking quoting. Password values are redacted in dry-run output.

## Common Failures

- `Permission denied (publickey)`: confirm the SSH alias, username, agent, or `-IdentityFile`.
- `Host key verification failed`: verify the host key and establish trust before retrying.
- `command not found`: the remote shell may not load the expected environment. Use full paths or source the required profile inside `-Command`.
- `scp` path errors: keep remote paths absolute when possible and avoid spaces unless required.
