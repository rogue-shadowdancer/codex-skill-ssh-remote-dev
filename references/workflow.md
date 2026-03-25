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
scripts/ssh_exec.ps1 -Target dev@203.0.113.10 -Password "<password>" -Command "pwd"
```

If the local session is sandboxed or Windows OpenSSH rejects the real `~/.ssh` ACLs, generate a workspace-local SSH bundle first:

```powershell
scripts/setup_sandbox_ssh.ps1 `
  -DestinationDir tmp/ssh-sandbox/demo-host `
  -HostAlias demo-host `
  -HostName 203.0.113.10 `
  -Username dev `
  -IdentityFile C:/Users/<you>/.ssh/id_ed25519 `
  -KnownHostsFile C:/Users/<you>/.ssh/known_hosts

scripts/ssh_exec.ps1 `
  -Target demo-host `
  -ConfigFile tmp/ssh-sandbox/demo-host/config `
  -IdentityFile tmp/ssh-sandbox/demo-host/id_ed25519 `
  -IdentitiesOnly `
  -Command "exit"
```

The generated config pins `IdentityFile`, enables `IdentitiesOnly yes`, and writes host keys into the local bundle's `known_hosts`.

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

The key-based wrappers also accept:

- `-ConfigFile`: pass an explicit OpenSSH config file such as `tmp/ssh-sandbox/<target>/config`
- `-IdentityFile`: pin the key file when the config does not already do it
- `-IdentitiesOnly`: prevent OpenSSH from falling back to unrelated agent or default keys
- `-SshExecutable` and `-ScpExecutable`: override the binary path when the default Windows OpenSSH path is not the right choice

## Git Over SSH On Windows

When Git operations fail because Git for Windows `usr/bin/ssh.exe` behaves differently from Windows OpenSSH, set `core.sshCommand` explicitly:

```powershell
git -c core.sshCommand='C:/Windows/System32/OpenSSH/ssh.exe -F "C:/path/to/tmp/ssh-sandbox/demo-host/config"' push origin my-branch
```

## Common Failures

- `Permission denied (publickey)`: confirm the SSH alias, username, `-ConfigFile`, `-IdentityFile`, and `-IdentitiesOnly`. On Windows, make sure the config points to the copied key inside the workspace-local bundle instead of the real `~/.ssh`.
- `Bad owner or permissions on ...\.ssh\config`: stop using the live profile from the sandboxed session. Generate a workspace-local bundle and point the wrappers at it.
- `Host key verification failed`: verify the host key and establish trust before retrying.
- `command not found`: the remote shell may not load the expected environment. Use full paths or source the required profile inside `-Command`.
- `scp` path errors: keep remote paths absolute when possible and avoid spaces unless required.
