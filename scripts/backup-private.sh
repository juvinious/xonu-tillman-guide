#!/bin/sh
# Emits a gzip tar archive on stdout. It contains PRIVATE device configuration.
# Stream over SSH to a file; do not publish the resulting archive.
# This is a configuration snapshot, not a firmware image or automatic restore.
set -eu
umask 077
[ "$(id -u)" -eq 0 ] || { echo 'Run as root on the stick.' >&2; exit 1; }
work=$(mktemp -d /tmp/xonu-backup.XXXXXX)
trap 'rm -rf "$work"' EXIT
trap 'exit 1' HUP INT TERM
fw_printenv > "$work/fwenv.txt"
uci export omci > "$work/omci.uci"
uci export gpon > "$work/gpon.uci"
uci export network > "$work/network.uci"
cp /usr/lib/lua/8311/version.lua "$work/version.lua"
cp /etc/rc.local "$work/rc.local"
if [ -d /ptconf/8311 ]; then cp -Rp /ptconf/8311 "$work/ptconf-8311"; fi
profile=$(uci -q get omci.default.mib_file)
printf '%s\n' "$profile" > "$work/profile-path.txt"
[ ! -f "$profile" ] || cp "$profile" "$work/active-profile.ini"
tar -czf - -C "$work" .
