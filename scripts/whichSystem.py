#!/usr/bin/env python3
"""Identify the OS of a remote host by analysing the TTL of an ICMP echo reply.

Usage:
    whichSystem.py <ip-address>

TTL heuristic (using default OS values, before hops decrement the counter):
    1   - 64   → Linux/Unix
    65  - 128  → Windows
    129 - 255  → Cisco/Solaris/other network gear

Example:
    $ whichSystem.py 10.10.10.5
        10.10.10.5 (ttl -> 64): Linux
"""

from __future__ import annotations

import ipaddress
import re
import subprocess
import sys

PING_TIMEOUT_SECONDS = 3
TTL_REGEX = re.compile(r"ttl[=:](\d+)", re.IGNORECASE)


def validate_ip(value: str) -> str:
    """Return the canonical IP string if valid, else raise ValueError."""
    return str(ipaddress.ip_address(value))


def fetch_ttl(ip: str) -> int | None:
    """Send one ICMP echo and parse the TTL from the reply.

    Returns the TTL as an integer, or None if the host is unreachable
    or the ping output cannot be parsed.
    """
    try:
        result = subprocess.run(
            ["/usr/bin/ping", "-c", "1", "-W", str(PING_TIMEOUT_SECONDS), ip],
            capture_output=True,
            text=True,
            timeout=PING_TIMEOUT_SECONDS + 1,
            check=False,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None

    if result.returncode != 0:
        return None

    match = TTL_REGEX.search(result.stdout)
    return int(match.group(1)) if match else None


def classify_os(ttl: int) -> str:
    if 1 <= ttl <= 64:
        return "Linux"
    if 65 <= ttl <= 128:
        return "Windows"
    if 129 <= ttl <= 255:
        return "Cisco/Solaris"
    return "Unknown"


def main() -> int:
    if len(sys.argv) != 2:
        print(f"\n[!] Usage: {sys.argv[0]} <ip-address>\n", file=sys.stderr)
        return 1

    try:
        ip = validate_ip(sys.argv[1])
    except ValueError:
        print(f"\n[!] Invalid IP address: {sys.argv[1]}\n", file=sys.stderr)
        return 1

    ttl = fetch_ttl(ip)
    if ttl is None:
        print(f"\n\t{ip}: host unreachable or no reply")
        return 2

    os_name = classify_os(ttl)
    print(f"\n\t{ip} (ttl -> {ttl}): {os_name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
