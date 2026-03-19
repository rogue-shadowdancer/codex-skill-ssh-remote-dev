#!/usr/bin/env python3

from __future__ import annotations

import argparse

from ssh_script_common import (
    current_python,
    ensure_local_parent,
    exit_with_command,
    get_paramiko_helper_path,
    get_remote_spec,
    new_scp_base_arguments,
    resolve_target_connection_info,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Copy one remote file to a local staging path."
    )
    parser.add_argument("-Target", "--target", dest="target", required=True)
    parser.add_argument("-RemotePath", "--remote-path", dest="remote_path", required=True)
    parser.add_argument("-LocalPath", "--local-path", dest="local_path", required=True)
    parser.add_argument("-Port", "--port", dest="port", type=int, default=0)
    parser.add_argument(
        "-IdentityFile", "--identity-file", dest="identity_file"
    )
    parser.add_argument("-Username", "--username", dest="username")
    parser.add_argument("-HostName", "--host-name", dest="host_name")
    parser.add_argument("-Password", "--password", dest="password")
    parser.add_argument("-DryRun", "--dry-run", dest="dry_run", action="store_true")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    ensure_local_parent(args.local_path, dry_run=args.dry_run)

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
            "fetch",
            "--host",
            host_name,
            "--user",
            username,
            "--password",
            args.password,
            "--remote-path",
            args.remote_path,
            "--local-path",
            args.local_path,
        ]

        if args.port > 0:
            python_arguments.extend(["--port", str(args.port)])

        exit_with_command(
            current_python(),
            python_arguments,
            dry_run=args.dry_run,
            sensitive_values=[args.password],
        )

    scp_arguments = new_scp_base_arguments(args.port, args.identity_file)
    scp_arguments.extend(
        [get_remote_spec(args.target, args.remote_path), args.local_path]
    )
    exit_with_command("scp", scp_arguments, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
