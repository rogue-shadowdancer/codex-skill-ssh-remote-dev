#!/usr/bin/env python3

from __future__ import annotations

from pathlib import Path
import shlex
import subprocess
import sys


def format_display_token(token: str, sensitive_values: list[str] | None = None) -> str:
    if sensitive_values and token in sensitive_values:
        return "<redacted>"
    if any(char.isspace() for char in token) or '"' in token or "`" in token:
        return '"' + token.replace('"', '\\"') + '"'
    return token


def write_dry_run_command(
    executable: str, arguments: list[str], sensitive_values: list[str] | None = None
) -> None:
    tokens = [executable] + [
        format_display_token(argument, sensitive_values) for argument in arguments
    ]
    print("DRYRUN: " + " ".join(tokens))


def invoke_external_command(
    executable: str,
    arguments: list[str],
    *,
    dry_run: bool = False,
    sensitive_values: list[str] | None = None,
) -> int:
    if dry_run:
        write_dry_run_command(executable, arguments, sensitive_values)
        return 0

    completed = subprocess.run([executable, *arguments], check=False)
    return completed.returncode


def get_paramiko_helper_path() -> Path:
    return Path(__file__).with_name("ssh_paramiko.py")


def resolve_target_connection_info(
    target: str, username: str | None, host_name: str | None
) -> tuple[str | None, str]:
    resolved_user = username
    resolved_host = host_name

    if not resolved_host:
        if "@" in target:
            target_user, target_host = target.split("@", 1)
            if not resolved_user:
                resolved_user = target_user
            resolved_host = target_host
        else:
            resolved_host = target

    return resolved_user, resolved_host


def quote_posix_literal(value: str) -> str:
    return shlex.quote(value)


def get_remote_shell_command(command: str, remote_dir: str | None) -> str:
    wrapped_command = command
    if remote_dir:
        wrapped_command = f"cd {quote_posix_literal(remote_dir)} && {wrapped_command}"
    return f"sh -lc {quote_posix_literal(wrapped_command)}"


def new_ssh_base_arguments(
    target: str, port: int, identity_file: str | None
) -> list[str]:
    arguments = [
        "-o",
        "BatchMode=yes",
        "-o",
        "ServerAliveInterval=15",
        "-o",
        "ServerAliveCountMax=3",
        "-o",
        "ConnectTimeout=10",
        "-o",
        "StrictHostKeyChecking=accept-new",
    ]

    if port > 0:
        arguments.extend(["-p", str(port)])

    if identity_file:
        arguments.extend(["-i", identity_file])

    arguments.append(target)
    return arguments


def new_scp_base_arguments(port: int, identity_file: str | None) -> list[str]:
    arguments = [
        "-o",
        "BatchMode=yes",
        "-o",
        "ConnectTimeout=10",
        "-o",
        "StrictHostKeyChecking=accept-new",
    ]

    if port > 0:
        arguments.extend(["-P", str(port)])

    if identity_file:
        arguments.extend(["-i", identity_file])

    return arguments


def get_remote_spec(target: str, remote_path: str) -> str:
    normalized_path = remote_path.replace("\\", "/")
    return f"{target}:{quote_posix_literal(normalized_path)}"


def get_remote_directory(remote_path: str) -> str:
    normalized_path = remote_path.replace("\\", "/")
    last_slash = normalized_path.rfind("/")
    if last_slash < 0:
        return "."
    if last_slash == 0:
        return "/"
    return normalized_path[:last_slash]


def get_remote_leaf_name(remote_path: str) -> str:
    normalized_path = remote_path.replace("\\", "/")
    last_slash = normalized_path.rfind("/")
    if last_slash < 0:
        return normalized_path
    return normalized_path[last_slash + 1 :]


def ensure_local_parent(local_path: str, *, dry_run: bool = False) -> None:
    parent = Path(local_path).parent
    if str(parent) in ("", "."):
        return
    if dry_run:
        print(f"DRYRUN: mkdir -p {parent}")
        return
    parent.mkdir(parents=True, exist_ok=True)


def exit_with_command(executable: str, arguments: list[str], **kwargs: object) -> None:
    raise SystemExit(invoke_external_command(executable, arguments, **kwargs))


def current_python() -> str:
    return sys.executable or "python3"
