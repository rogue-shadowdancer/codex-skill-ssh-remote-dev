---
name: "ssh-remote-dev"
description: "Safely inspect, edit, sync, and test code on a remote server over SSH and SCP by staging files locally, patching them with apply_patch, pushing them back with backups, and running targeted remote validation. Use when Codex needs to work on a project that lives on a remote Linux or POSIX host, VM, VPS, container host, or bastion-reachable machine and the user wants changes made or tests run over SSH instead of only in the local workspace, including Windows or sandboxed sessions that need a workspace-local SSH config and key copy to avoid ~/.ssh ACL or owner issues."
---

# SSH Remote Dev

Operate on a remote project through `ssh` and `scp` while keeping edits local-first. Pull remote files into a local staging area, edit them with `apply_patch`, push them back with a backup, then run the smallest useful remote validation command.

Default to SSH keys or aliases. If the user only has a password, use the same wrapper scripts with `-Password`; they fall back to the bundled `paramiko` helper instead of OpenSSH batch mode.

On Windows or in sandboxed sessions, do not assume the live `~/.ssh` directory is usable. If OpenSSH rejects `config` or key ACLs, or the agent runs under a different Windows identity than the interactive user, create a workspace-local SSH bundle under `tmp/ssh-sandbox/<target>/` with `scripts/setup_sandbox_ssh.ps1`, then pass `-ConfigFile`, `-IdentityFile`, and `-IdentitiesOnly` to the wrappers as needed.

Assume the remote host is POSIX-like and has `sh`, `cp`, `mv`, `mkdir`, `ssh`, and `scp` available. If the target is Windows-only, WinRM-only, or lacks a POSIX shell, do not use this skill unchanged.

## Quick Start

1. Prefer an SSH config alias as `Target`. If Windows ACLs or sandbox identity mismatches make `~/.ssh` unusable, generate a minimal workspace-local config and use that alias instead.
2. Gather three inputs up front: `Target`, remote project root, and the smallest useful validation command.
3. Inspect before editing: confirm repo root, branch, dirty state, and whether the host is production-like.
4. Stage only the files you need under `tmp/ssh-remote-dev/<target>/...`.
5. Use `scripts/ssh_fetch.ps1` to copy remote files locally, edit locally with `apply_patch`, then use `scripts/ssh_push.ps1 -BackupExisting` to upload safely.
6. Run targeted validation first with `scripts/ssh_exec.ps1`. Broaden scope only if the narrow check passes or the user asks for more.
7. Report exactly which remote files changed, which backup suffix was created, and which remote commands were run.

## Workflow

### 1. Build context

- Ask or detect: SSH target, remote shell, project path, service impact, and whether sudo or restarts are allowed.
- Prefer read-only probes first:
  - `git status --short`
  - `git branch --show-current`
  - `git rev-parse --show-toplevel`
  - `pwd`
  - `ls`
- Use `scripts/ssh_exec.ps1` for remote commands instead of rebuilding ssh flags by hand.
- On Windows, the wrappers prefer `C:\Windows\System32\OpenSSH\ssh.exe` and `scp.exe` automatically when available. Override with `-SshExecutable` or `-ScpExecutable` only when the user explicitly needs a different binary.
- If the user provides a password instead of a key, pass `-Password` and prefer `user@host` in `-Target`.
- If the session cannot safely use the live `~/.ssh`, generate a minimal workspace-local config with `scripts/setup_sandbox_ssh.ps1` and point the wrappers at it with `-ConfigFile`. Keep host keys in the local bundle instead of polluting the real profile.

### 2. Stage files locally

- Create a staging area under `tmp/ssh-remote-dev/<target>/`.
- Pull only the files that will be edited. Do not clone the entire repo unless the user explicitly wants that.
- Keep the remote relative path in the local staging path so uploads are easy to reason about.
- When using a workspace-local SSH bundle, keep it under `tmp/ssh-sandbox/<target>/` and ensure the generated config has an explicit `IdentityFile` plus `IdentitiesOnly yes`. Do not blindly copy a full `~/.ssh/config` and hope OpenSSH resolves the right key.

### 3. Edit locally

- Use `apply_patch` on the staged local copy.
- Do not inline-edit remote files with `sed`, `perl`, or heredocs unless the change is truly tiny and the user explicitly prefers it.
- Keep diffs surgical. Assume the remote worktree may contain unrelated changes.

### 4. Push safely

- Use `scripts/ssh_push.ps1 -BackupExisting` for normal file updates.
- The push script uploads to a temporary remote file, optionally creates a timestamped backup, then replaces the target path.
- Push one file at a time unless the project already has a user-approved sync or deploy mechanism.

### 5. Validate remotely

- Start with the narrowest relevant command: one test file, one package, one formatter target, or one build target.
- Escalate to wider validation only if the user asks or the narrow check is insufficient.
- Capture the exact command, remote working directory, and exit result.

## Safety Rules

- Treat unknown hosts as high risk until the user confirms the environment.
- Ask before any destructive or service-affecting action: restarts, migrations, data writes, package installs, deleting files, force pushes, or broad `chmod` and `chown` changes.
- Never run `git reset --hard`, `git checkout --`, `rm -rf`, or restart a production service unless the user explicitly asks.
- Prefer `systemctl status`, `journalctl -n`, and read-only inspection before `restart`.
- Preserve evidence: do not delete staged local copies or remote backups until the user is done.

## Bundled Tools

- `scripts/ssh_exec.ps1`: Run a remote command with consistent ssh options and an optional remote working directory.
- `scripts/ssh_fetch.ps1`: Copy one remote file to a local staging path.
- `scripts/ssh_push.ps1`: Upload one local file to a remote path with optional backup and a safe replace sequence.
- `scripts/setup_sandbox_ssh.ps1`: Create a minimal workspace-local SSH config, key copy, and known-hosts file for Windows or sandboxed sessions.
- `scripts/ssh_paramiko.py`: Password-capable backend used automatically when `-Password` is supplied.
- `references/workflow.md`: Example commands, staging conventions, and common failures.
- `references/windows-sandbox.md`: Windows-specific guidance for sandbox-local SSH config bundles and Git-over-SSH.

## Decision Points

- Many files or full repo sync needed: prefer a user-approved clone or project-native deploy mechanism. Do not invent an `rsync` workflow unless `rsync` is already installed and the user wants it.
- Production or shared server: prefer the smallest possible edit and the narrowest validation. Back up first.
- No SSH alias available: accept `user@host`, plus `-Port`, `-IdentityFile`, `-ConfigFile`, and `-IdentitiesOnly` on the bundled scripts.
- Password-only access: pass `-Password`; the wrappers route through `paramiko` and do not require `sshpass`, `plink`, or `pscp`.
- Git over SSH is failing on Windows: prefer `git -c core.sshCommand="C:/Windows/System32/OpenSSH/ssh.exe -F <config>" ...` instead of Git for Windows `usr/bin/ssh.exe`.

## Output Expectations

Report:

- SSH target and remote project root
- Files fetched and pushed
- Backup suffix created by uploads
- Remote validation commands and results
- Any remaining manual steps or risks
