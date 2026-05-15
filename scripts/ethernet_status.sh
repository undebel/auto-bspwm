#!/bin/sh
set -eu

# IPv4 address of eth0.
# Uses iproute2 instead of the deprecated `ifconfig` from net-tools.
ip_addr=$(/usr/sbin/ip -4 -br addr show eth0 2>/dev/null | awk '{print $3}' | cut -d/ -f1)

echo "%{F#ffffff}  %{F#ffffff}${ip_addr}%{u-}"
