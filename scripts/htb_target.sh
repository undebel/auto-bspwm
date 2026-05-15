#!/bin/sh
set -eu

# Theme-independent location of the active HTB target.
# `settarget` (from .zshrc) writes to this file; all polybar themes read from it
# via a symlink created at install time (setup.sh install_scripts).
TARGET_FILE="${HOME}/.config/polybar/target"

ip_target=""
name_target=""
if [ -r "$TARGET_FILE" ]; then
	ip_target=$(awk 'NR==1 {print $1}' "$TARGET_FILE")
	name_target=$(awk 'NR==1 {print $2}' "$TARGET_FILE")
fi

if [ -n "$ip_target" ] && [ -n "$name_target" ]; then
	echo "%{F#ffffff}什%{F#ffffff} $ip_target - $name_target "
elif [ -n "$ip_target" ]; then
	echo "%{F#ffffff}什%{F#ffffff} $ip_target "
else
	echo "%{F#ffffff}什%{u-}%{F#ffffff} No target "
fi
