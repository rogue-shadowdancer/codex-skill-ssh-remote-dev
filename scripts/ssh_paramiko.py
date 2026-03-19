#!/usr/bin/env python3

from __future__ import annotations

import argparse
import os
import posixpath
import shlex
import sys
from datetime import datetime
from typing import Optional

try:
    import paramiko
except ImportError as exc:  # pragma: no cover - import failure path
    raise SystemExit(
        "paramiko is required for password-based SSH operations. "
        "Install it in the current Python environment with: python3 -m pip install paramiko"
    ) from exc


def create_client(host: str, port: int, user: str, password: str) -> paramiko.SSHClient:
    client = paramiko.SSHClient()
    client.load_system_host_keys()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(
        hostname=host,
        port=port,
        username=user,
        password=password,
        look_for_keys=False,
        allow_agent=False,
        timeout=10,
        banner_timeout=10,
        auth_timeout=10,
    )
    return client


def wrap_remote_command(command: str, remote_dir: Optional[str]) -> str:
    wrapped = command
    if remote_dir:
        wrapped = f"cd {shlex.quote(remote_dir)} && {wrapped}"
    return f"sh -lc {shlex.quote(wrapped)}"


def run_remote_command(
    client: paramiko.SSHClient,
    command: str,
    remote_dir: Optional[str] = None,
    tty: bool = False,
) -> int:
    stdin, stdout, stderr = client.exec_command(wrap_remote_command(command, remote_dir), get_pty=tty)
    out_bytes = stdout.read()
    err_bytes = stderr.read()
    status = stdout.channel.recv_exit_status()

    if out_bytes:
        sys.stdout.buffer.write(out_bytes)
    if err_bytes:
        sys.stderr.buffer.write(err_bytes)

    return status


def remote_directory(remote_path: str) -> str:
    directory = posixpath.dirname(remote_path)
    return directory or "."


def ensure_local_parent(local_path: str) -> None:
    parent = os.path.dirname(local_path)
    if parent:
        os.makedirs(parent, exist_ok=True)


def handle_exec(args: argparse.Namespace) -> int:
    client = create_client(args.host, args.port, args.user, args.password)
    try:
        return run_remote_command(client, args.command, args.remote_dir, args.tty)
    finally:
        client.close()


def handle_fetch(args: argparse.Namespace) -> int:
    client = create_client(args.host, args.port, args.user, args.password)
    try:
        ensure_local_parent(args.local_path)
        sftp = client.open_sftp()
        try:
            sftp.get(args.remote_path, args.local_path)
        finally:
            sftp.close()
        return 0
    finally:
        client.close()


def handle_push(args: argparse.Namespace) -> int:
    client = create_client(args.host, args.port, args.user, args.password)
    try:
        remote_dir = remote_directory(args.remote_path)
        leaf_name = posixpath.basename(args.remote_path)
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        temp_name = f".codex-upload-{timestamp}-{leaf_name}"
        temp_path = posixpath.join(remote_dir, temp_name) if remote_dir != "/" else f"/{temp_name}"
        backup_path = f"{args.remote_path}.bak.{timestamp}"

        status = run_remote_command(client, f"mkdir -p {shlex.quote(remote_dir)}")
        if status != 0:
            return status

        sftp = client.open_sftp()
        try:
            sftp.put(args.local_path, temp_path)
        finally:
            sftp.close()

        commands = []
        if args.backup_existing:
            commands.append(
                f"if [ -e {shlex.quote(args.remote_path)} ]; then cp -p {shlex.quote(args.remote_path)} {shlex.quote(backup_path)}; fi"
            )
        commands.append(
            f"if [ -e {shlex.quote(args.remote_path)} ]; then chmod --reference={shlex.quote(args.remote_path)} {shlex.quote(temp_path)} 2>/dev/null || true; fi"
        )
        commands.append(f"mv {shlex.quote(temp_path)} {shlex.quote(args.remote_path)}")

        status = run_remote_command(client, "; ".join(commands))
        if status == 0 and args.backup_existing:
            print(f"Backup path: {backup_path}")
        return status
    finally:
        client.close()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Password-capable SSH/SFTP helper for ssh-remote-dev.")
    subparsers = parser.add_subparsers(dest="subcommand", required=True)

    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--host", required=True)
    common.add_argument("--port", type=int, default=22)
    common.add_argument("--user", required=True)
    common.add_argument("--password", required=True)

    exec_parser = subparsers.add_parser("exec", parents=[common])
    exec_parser.add_argument("--command", required=True)
    exec_parser.add_argument("--remote-dir")
    exec_parser.add_argument("--tty", action="store_true")
    exec_parser.set_defaults(handler=handle_exec)

    fetch_parser = subparsers.add_parser("fetch", parents=[common])
    fetch_parser.add_argument("--remote-path", required=True)
    fetch_parser.add_argument("--local-path", required=True)
    fetch_parser.set_defaults(handler=handle_fetch)

    push_parser = subparsers.add_parser("push", parents=[common])
    push_parser.add_argument("--local-path", required=True)
    push_parser.add_argument("--remote-path", required=True)
    push_parser.add_argument("--backup-existing", action="store_true")
    push_parser.set_defaults(handler=handle_push)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return args.handler(args)


if __name__ == "__main__":
    sys.exit(main())
