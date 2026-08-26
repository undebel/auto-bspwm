#!/bin/sh
set -eu

# Lock the screen behind a blurred screenshot of the current desktop.
# Replaces the abandoned i3lock-fancy wrapper (Kali packages a 2016 git
# snapshot of it) using only maintained tools that setup.sh already
# installs: scrot + imagemagick + i3lock.
#
# Fail-closed: if the screenshot/blur pipeline (or i3lock -i itself)
# fails for any reason, lock anyway on a solid black background instead
# of leaving the desktop exposed.

umask 077

# Prefer tmpfs-backed dirs so the sensitive screenshot never touches
# persistent disk (it would survive a SIGKILL or power loss in /tmp).
img="$(mktemp --suffix=.png -p "${XDG_RUNTIME_DIR:-/dev/shm}" 2>/dev/null \
	|| mktemp --suffix=.png)"
trap 'rm -f "$img"' EXIT INT TERM

lock_blurred() {
	# Full-screen capture (-o: overwrite the file mktemp already created).
	scrot -o "$img" || return 1

	# Blur: downscale + blur + upscale back to the exact original size,
	# which is much faster than blurring at full resolution.
	size="$(identify -format '%wx%h' "$img")" || return 1
	if command -v magick >/dev/null 2>&1; then
		magick "$img" -scale 10% -blur 0x2.5 -resize "${size}!" "$img" || return 1
	else
		convert "$img" -scale 10% -blur 0x2.5 -resize "${size}!" "$img" || return 1
	fi

	# -e: ignore empty password submissions; --nofork keeps the trap
	# alive so the screenshot is deleted as soon as the screen is
	# unlocked (no `exec` on purpose: it would skip the cleanup trap).
	i3lock --nofork -e -i "$img"
}

lock_blurred || i3lock --nofork -e -c 000000
