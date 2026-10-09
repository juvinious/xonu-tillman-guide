#!/bin/sh
# Generate only the exact XS-2426X-A profile used in this case study.
# This does not select the profile, restart OMCI, or change boot settings.
set -eu
umask 077
SOURCE=/etc/mibs/prx300_1V.ini
TARGET=/tmp/veip-aligned.ini
EXPECTED=c6df242aa457421b980c6c6d685669c6800965fb948ec5d0e81bb34818ed6020
die() { echo "ERROR: $*" >&2; exit 1; }
[ "$#" -eq 0 ] || die 'This exact-case helper accepts no parameters.'
[ -r "$SOURCE" ] || die "Missing firmware template: $SOURCE"
[ ! -e "$TARGET" ] && [ ! -L "$TARGET" ] || die "Target already exists: $TARGET"
command -v sha256sum >/dev/null || die 'sha256sum is required.'
work=$(mktemp -d /tmp/xonu-profile.XXXXXX)
trap 'rm -rf "$work"' EXIT
trap 'exit 1' HUP INT TERM
sed -e 's/INTC/ALCL/g' -e 's/^256 .*/256 0 ALCL 3FE49691AABA 00000000 2 0 0 0 0/' -e 's/^5 0x0101 /5 0x0100 /' -e 's/^6 0x0101 /6 0x0100 /' -e '/^[^#]/s/0x0101/0x0001/g' "$SOURCE" > "$work/profile.ini"
actual=$(sha256sum "$work/profile.ini" | awk '{print $1}')
[ "$actual" = "$EXPECTED" ] || die "Generated profile differs from the verified profile ($actual); no target installed. Review the firmware template instead of bypassing the check."
# Link fails rather than replacing a target created during generation.
ln "$work/profile.ini" "$TARGET"
echo "Created $TARGET; boot settings and OMCI are unchanged."
sha256sum "$TARGET"
