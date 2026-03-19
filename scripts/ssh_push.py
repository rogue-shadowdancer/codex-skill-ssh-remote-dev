#!/usr/bin/env python3

from __future__ import annotations

import argparse
from datetime import datetime
from pathlib import Path

from ssh_script_common import (
    current_python,
    get_paramiko_helper_path,
    get_remote_directory,
    get_remote_leaf_name,
    get_remote_shell_command,
    get_remote_spec,
    invoke_external_command,
    new_scp_base_arguments,
    new_ssh_base_arguments,
    quote_posix_literal,
    resolve_target_connection_info,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Upload one local file to a remote path with optional backup."
    )
    parser.add_argument("-Target", "--target", dest="target", required=True)
    parser.add_argument("-LocalPath", "--local-path", dest="local_path", required=True)
    parser.add_argument("-RemotePath", "--remote-path", dest="remote_path", required=True)
    parser.add_argument("-Port", "--port", dest="port", type=int, default=0)
    parser.add_argument(
        "-IdentityFile", "--identity-file", dest="identity_file"
    )
    parser.add_argument("-Username", "--username", dest="username")
    parser.add_argument("-HostName", "--host-name", dest="host_name")
    parser.add_argument("-Password", "--password", dest="password")
    parser.add_argument(
        "-BackupExisting",
        "--backup-existing",
        dest="backup_existing",
        action="store_true",
    )
    parser.add_argument("-DryRun", "--dry-run", dest="dry_run", action="store_true")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    if not Path(args.local_path).is_file():
        raise SystemExit(f"Local file does not exist: {args.local_path}")

    if args.password:
        username, host_name = resolve_target_connection_info(
            args.target, args.username, args.host_name
        )
        if not username:
            raise SystemExit(
                "Username is required for password authentication. "
                "Pass user@host as --target or provide --username."
            )

        python_arguments = [
            str(get_paramiko_helper_path()),
            "push",
            "--host",
            host_name,
            "--user",
            username,
            "--password",
            args.password,
            "--local-path",
            args.local_path,
            "--remote-path",
            args.remote_path,
        ]

        if args.port > 0:
            python_arguments.extend(["--port", str(args.port)])
        if args.backup_existing:
            python_arguments.append("--backup-existing")

        raise SystemExit(
            invoke_external_command(
                current_python(),
                python_arguments,
                dry_run=args.dry_run,
                sensitive_values=[args.password],
            )
        )

    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    remote_directory = get_remote_directory(args.remote_path)
    remote_leaf_name = get_remote_leaf_name(args.remote_path)

    if remote_directory == "/":
        temporary_remote_path = f"/.codex-upload-{timestamp}-{remote_leaf_name}"
    elif remote_directory == ".":
        temporary_remote_path = f".codex-upload-{timestamp}-{remote_leaf_name}"
    else:
        temporary_remote_path = (
            f"{remote_directory}/.codex-upload-{timestamp}-{remote_leaf_name}"
        )

    backup_remote_path = f"{args.remote_path}.bak.{timestamp}"

    ssh_arguments = new_ssh_base_arguments(args.target, args.port, args.identity_file)
    scp_arguments = new_scp_base_arguments(args.port, args.identity_file)

    prepare_command = get_remote_shell_command(
        f"mkdir -p {quote_posix_literal(remote_directory)}", None
    )
    status = invoke_external_command(
        "ssh", [*ssh_arguments, prepare_command], dry_run=args.dry_run
    )
    if status != 0:
        raise SystemExit(status)

    upload_arguments = [
        *scp_arguments,
        args.local_path,
        get_remote_spec(args.target, temporary_remote_path),
    ]
    status = invoke_external_command("scp", upload_arguments, dry_run=args.dry_run)
    if status != 0:
        raise SystemExit(status)

    finalize_parts: list[str] = []
    if args.backup_existing:
        finalize_parts.append(
            f"if [ -e {quote_posix_literal(args.remote_path)} ]; then cp -p "
            f"{quote_posix_literal(args.remote_path)} {quote_posix_literal(backup_remote_path)}; fi"
        )

    finalize_parts.append(
        f"if [ -e {quote_posix_literal(args.remote_path)} ]; then chmod "
        f"--reference={quote_posix_literal(args.remote_path)} {quote_posix_literal(temporary_remote_path)} "
        "2>/dev/null || true; fi"
    )
    finalize_parts.append(
        f"mv {quote_posix_literal(temporary_remote_path)} {quote_posix_literal(args.remote_path)}"
    )

    finalize_command = get_remote_shell_command("; ".join(finalize_parts), None)
    status = invoke_external_command(
        "ssh", [*ssh_arguments, finalize_command], dry_run=args.dry_run
    )
    if status != 0:
        raise SystemExit(status)

    if args.backup_existing:
        print(f"Backup path: {backup_remote_path}")
    return 0


if __name__ == "__main__":
    main()
