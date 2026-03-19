#!/usr/bin/env python3

from __future__ import annotations

import argparse

from ssh_script_common import (
    current_python,
    exit_with_command,
    get_paramiko_helper_path,
    get_remote_shell_command,
    new_ssh_base_arguments,
    resolve_target_connection_info,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Run a remote command with consistent ssh options."
    )
    parser.add_argument("-Target", "--target", dest="target", required=True)
    parser.add_argument("-Command", "--command", dest="command", required=True)
    parser.add_argument("-RemoteDir", "--remote-dir", dest="remote_dir")
    parser.add_argument("-Port", "--port", dest="port", type=int, default=0)
    parser.add_argument(
        "-IdentityFile", "--identity-file", dest="identity_file"
    )
    parser.add_argument("-Username", "--username", dest="username")
    parser.add_argument("-HostName", "--host-name", dest="host_name")
    parser.add_argument("-Password", "--password", dest="password")
    parser.add_argument("-Tty", "--tty", dest="tty", action="store_true")
    parser.add_argument("-DryRun", "--dry-run", dest="dry_run", action="store_true")
    return parser


def main() -> int:
    args = build_parser().parse_args()

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
            "exec",
            "--host",
            host_name,
            "--user",
            username,
            "--password",
            args.password,
            "--command",
            args.command,
        ]

        if args.port > 0:
            python_arguments.extend(["--port", str(args.port)])
        if args.remote_dir:
            python_arguments.extend(["--remote-dir", args.remote_dir])
        if args.tty:
            python_arguments.append("--tty")

        exit_with_command(
            current_python(),
            python_arguments,
            dry_run=args.dry_run,
            sensitive_values=[args.password],
        )

    ssh_arguments = new_ssh_base_arguments(args.target, args.port, args.identity_file)
    if args.tty:
        ssh_arguments = ["-tt", *ssh_arguments]
    ssh_arguments.append(get_remote_shell_command(args.command, args.remote_dir))
    exit_with_command("ssh", ssh_arguments, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
