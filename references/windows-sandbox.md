# Windows Sandbox SSH Recipe

Use this recipe when Codex runs under a different Windows user than the interactive owner of `C:\Users\<you>\.ssh`, or when OpenSSH rejects the live profile because of ACL or owner checks.

## Why

- Windows OpenSSH can fail before authentication with errors such as `Bad owner or permissions on ...\.ssh\config`.
- Sandboxed sessions often cannot safely reuse the interactive user's `~/.ssh` profile.
- Copying the full profile blindly is brittle because the copied `config` may still point back to the wrong key or agent.

## Preferred Flow

1. From a trusted user context, create a minimal bundle under `tmp/ssh-sandbox/<target>/` with `scripts/setup_sandbox_ssh.ps1`.
2. Use the generated `config`, copied key, and local `known_hosts` file for all wrapper calls.
3. Pass `-IdentitiesOnly` when you need to guarantee OpenSSH does not fall back to unrelated default keys or agent state.
4. For Git-over-SSH, use Windows OpenSSH explicitly with `core.sshCommand`.

## Example

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

git -c core.sshCommand='C:/Windows/System32/OpenSSH/ssh.exe -F "C:/path/to/tmp/ssh-sandbox/demo-host/config"' push origin my-branch
```

## What The Setup Script Generates

- `config`: a minimal host block with `IdentityFile`, `IdentitiesOnly yes`, and `UserKnownHostsFile`
- the copied private key and optional `.pub` file
- `known_hosts`: copied from the source file when provided, otherwise created locally

## Do Not

- Do not edit remote files inline when a staged local copy is practical.
- Do not keep writing new host keys into the real `~/.ssh` from a sandboxed session.
- Do not assume `ssh.exe` from Git for Windows behaves the same as Windows OpenSSH.
