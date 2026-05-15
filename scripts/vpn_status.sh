#!/bin/sh
set -eu

# IPv4 address of tun0 (the OpenVPN/HTB tunnel), if up.
# Uses iproute2 instead of the deprecated `ifconfig` from net-tools.
ip_addr=$(/usr/sbin/ip -4 -br addr show tun0 2>/dev/null | awk '{print $3}' | cut -d/ -f1)

if [ -n "$ip_addr" ]; then
	echo "%{F#ffffff}  %{F#ffffff}${ip_addr}%{u-}"
else
	echo "%{F#ffffff} %{u-} Disconnected"
fi
