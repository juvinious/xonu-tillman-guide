#!/bin/sh
# X-ONU-SFPP, 8311 basic v2.8.3: preserve the verified VEIP profile and
# downstream-only encryption for this installation's Internet GEM 1028.
# Run on the stick: sh xonu-persist.sh install|status|rollback
# Does not restart OMCI, reboot, change VLAN tags, or change the WAN MAC.
# Source reviewed: firmware revision 7d89440 and uploaded installed scripts.
set -eu
umask 077

BASE=/ptconf/8311/xonu-persistence
BACKUP=$BASE/before
PROFILE=$BASE/veip-aligned.ini
HOOK=/ptconf/8311/vlan_fixes_hook.sh
DAEMON=/usr/sbin/8311-vlansd.sh

die() { echo "ERROR: $*" >&2; exit 1; }
hash_file() { sha256sum "$1" | awk '{print $1}'; }
save_env() {
    if fw_printenv -n "$1" > "$BACKUP/$1.value" 2>/dev/null; then
        touch "$BACKUP/$1.present"
    fi
}
restore_env() {
    if [ -f "$BACKUP/$1.present" ]; then
        fwenv_set "$1" "$(cat "$BACKUP/$1.value")"
    else
        fwenv_set "$1"
    fi
}
stop_vlan_daemon() {
    # Read exact command-line arguments, never match the SSH command string.
    for entry in /proc/[0-9]*/cmdline; do
        [ -r "$entry" ] || continue
        if tr '\000' '\n' < "$entry" 2>/dev/null | grep -Fxq "$DAEMON"; then
            pid=${entry#/proc/}; pid=${pid%/cmdline}
            kill "$pid" 2>/dev/null || :
        fi
    done
}
start_vlan_daemon() {
    "$DAEMON" </dev/null >>/tmp/xonu-vlansd.log 2>&1 &
    echo "VLAN hook monitor started: PID $!"
}
status() {
    echo 'BOOT PROFILE (raw mib_file environment variable)'
    fw_printenv -n mib_file 2>/dev/null || :
    echo 'CURRENT UCI PROFILE'
    uci -q get omci.default.mib_file || :
    echo 'VLAN MODE (2 = custom hook only)'
    fw_printenv -n 8311_fix_vlans 2>/dev/null || :
    echo 'PROFILE CHECKSUM'
    [ ! -f "$PROFILE" ] || sha256sum "$PROFILE"
    echo 'HOOK CHECKSUM'
    [ ! -f "$HOOK" ] || sha256sum "$HOOK"
    echo 'GEM ENCRYPTION (03 expected while provisioned)'
    timeout 10 omci_pipe.sh meadg 268 1028 10 || :
    echo 'GEM COUNTERS'
    timeout 10 pontop -b -g 'GEM/XGEM Port Counters' || :
    echo 'RECENT HOOK MONITOR OUTPUT'
    [ ! -f /tmp/xonu-vlansd.log ] || tail -n 15 /tmp/xonu-vlansd.log
}
rollback() {
    [ -f "$BACKUP/complete" ] || die 'No complete rollback backup exists.'
    stop_vlan_daemon
    restore_env mib_file
    restore_env 8311_fix_vlans
    if [ -f "$BACKUP/hook.present" ]; then
        cp -p "$BACKUP/hook.sh" "$HOOK"
    else
        rm -f "$HOOK"
    fi
    # Restore the temporary disabled-fix configuration used by the working test.
    cp -p "$BACKUP/runtime-config.sh" /tmp/8311-config.sh
    old_profile=$(cat "$BACKUP/uci-profile")
    [ -f "$old_profile" ] || old_profile=/etc/mibs/prx300_1U.ini
    uci set "omci.default.mib_file=$old_profile"
    uci commit omci
    sync
    start_vlan_daemon
    echo 'Persistence settings restored. Current OMCI and encryption left running.'
    echo 'The backup and saved profile remain available under /ptconf/8311/xonu-persistence.'
}
install() {
    [ "$(id -u)" = 0 ] || die 'Run as root on the stick.'
    for cmd in fwenv_set fw_printenv sha256sum timeout omci_pipe.sh ip uci flock; do
        command -v "$cmd" >/dev/null 2>&1 || die "Missing command: $cmd"
    done
    [ ! -e "$BASE" ] || die 'Installation directory already exists; use status or rollback.'
    [ ! -s "$HOOK" ] || die 'An existing custom VLAN hook needs review; nothing changed.'
    [ ! -L "$HOOK" ] || die 'Existing hook is a symbolic link; nothing changed.'
    for guard in /root/.failsafe /tmp/.failsafe /ptconf/.failsafe; do
        [ ! -e "$guard" ] || die "Failsafe guard present: $guard"
    done
    grep -Eq '[[:space:]]/ptconf[[:space:]]' /proc/mounts || die '/ptconf is not mounted.'
    [ "$(hash_file /tmp/veip-aligned.ini)" = c6df242aa457421b980c6c6d685669c6800965fb948ec5d0e81bb34818ed6020 ] || die 'Working profile differs from the reviewed backup.'
    [ "$(hash_file /etc/init.d/omcid.sh)" = 4acaa2574bf87a4f7ea0f4e21c22aeb1eccfe777e8afabd1ff32b03da3dff1f3 ] || die 'OMCI startup script differs from the reviewed backup.'
    [ "$(hash_file "$DAEMON")" = 93697dd306f2a50f4804d35d4af350c090fe8741aa90d345c7be17c268d42f7a ] || die 'VLAN daemon differs from the reviewed backup.'
    [ "$(uci -q get omci.default.mib_file)" = /tmp/veip-aligned.ini ] || die 'Active profile is not the verified temporary profile.'
    grep -Eq '^FIX_ENABLED=0$' /tmp/8311-config.sh || die 'Expected temporary VLAN-fix disable is missing.'
    timeout 10 omci_pipe.sh meadg 268 1028 10 | grep -Eq 'errorcode=0 attr_data=03([[:space:]]|$)' || die 'GEM 1028 is not currently using the verified encryption setting.'

    mkdir -p "$BACKUP"
    save_env mib_file
    save_env 8311_fix_vlans
    uci -q get omci.default.mib_file > "$BACKUP/uci-profile"
    uci export omci > "$BACKUP/omci-export.txt"
    cp -p /tmp/8311-config.sh "$BACKUP/runtime-config.sh"
    if [ -f "$HOOK" ]; then
        cp -p "$HOOK" "$BACKUP/hook.sh"
        touch "$BACKUP/hook.present"
    fi
    cp /tmp/veip-aligned.ini "$PROFILE"
    cmp -s /tmp/veip-aligned.ini "$PROFILE" || die 'Profile copy verification failed.'
    touch "$BACKUP/complete"

    # The firmware sources this file under flock after each topology change.
    # A failure makes the daemon retry, including while GEM creation is pending.
    cat > "$BASE/hook.new" <<'XONU_HOOK'
# XONU-GEM1028-DOWNSTREAM-ENCRYPTION-v1
xonu_gem1028_downstream_encryption() {
    xonu_detail=$(ip -d link show dev gem1028 2>/dev/null) || return 1
    printf '%s\n' "$xonu_detail" | grep -Eq 'id: 1028 .*dir: 3 .*mc: 0([[:space:]]|$)' || return 1
    printf '%s\n' "$xonu_detail" | grep -Eq 'enc: 3([[:space:]]|$)' && return 0
    xonu_result=$(timeout 10 omci_pipe.sh meads 268 1028 10 3 2>&1) || return 1
    printf '%s\n' "$xonu_result" | grep -Eq '(^|[[:space:]])errorcode=0([[:space:]]|$)' || return 1
    ip -d link show dev gem1028 2>/dev/null | grep -Eq 'enc: 3([[:space:]]|$)' || return 1
    logger -t xonu-encryption 'Applied downstream-only encryption to GEM 1028'
    echo 'GEM 1028: downstream encryption applied.'
    return 0
}
xonu_gem1028_downstream_encryption
XONU_HOOK
    sh -n "$BASE/hook.new"
    chmod 700 "$BASE/hook.new"
    # The connection already works: this should read enc:3 and make no write.
    sh "$BASE/hook.new" || die 'Hook preflight failed; boot settings untouched.'

    completed=0
    trap 'if [ "$completed" = 0 ]; then echo "Install interrupted; restoring persistence settings." >&2; (set +e; rollback) || :; fi' EXIT
    trap 'exit 1' HUP INT TERM
    stop_vlan_daemon
    mv "$BASE/hook.new" "$HOOK"
    # Important: this is the raw mib_file key, NOT 8311_mib_file.
    # S85 omcid.boot reads it after S79 8311 initialization, before rc.local starts OMCI.
    fwenv_set mib_file "$PROFILE"
    fwenv_set --8311 fix_vlans 2
    uci set "omci.default.mib_file=$PROFILE"
    uci commit omci
    [ "$(fw_printenv -n mib_file)" = "$PROFILE" ] || die 'Boot profile verification failed.'
    [ "$(fw_printenv -n 8311_fix_vlans)" = 2 ] || die 'Hook-only setting verification failed.'
    sync
    start_vlan_daemon
    completed=1
    trap - EXIT HUP INT TERM
    echo 'INSTALLED: profile persisted; VLAN daemon in hook-only mode.'
    echo 'OMCI was not restarted. Reconnect/reboot recovery is not yet tested.'
    status
}

case "${1:-status}" in
    install) install ;;
    status) status ;;
    rollback) rollback ;;
    *) die 'Usage: sh xonu-persist.sh install|status|rollback' ;;
esac
