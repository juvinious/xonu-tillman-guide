#!/bin/sh
# Read-only snapshots. Output is NOT guaranteed anonymous: review before sharing.
# Usage on stick: sh collect-status.sh [GEM_ID [INTERVAL_SECONDS]]
set -u
gem=${1:-1028}
interval=${2:-15}
case "$gem" in ''|*[!0-9]*) echo 'GEM_ID must be decimal.' >&2; exit 2;; esac
case "$interval" in ''|*[!0-9]*) echo 'Interval must be decimal.' >&2; exit 2;; esac
[ "$#" -le 2 ] && [ "$gem" -ge 1 ] && [ "$gem" -le 65534 ] && [ "$interval" -ge 1 ] && [ "$interval" -le 60 ] || { echo 'Usage: GEM_ID 1..65534; interval 1..60 seconds.' >&2; exit 2; }
command -v timeout >/dev/null 2>&1 || { echo 'Missing timeout.' >&2; exit 1; }
run() {
    printf '\nCOMMAND:'
    printf ' %s' "$@"
    printf '\n'
    timeout 10 "$@"
    result=$?
    [ "$result" -eq 0 ] || printf 'COMMAND_EXIT=%s\n' "$result"
    return 0
}
echo 'X-ONU case-study diagnostic: no configuration writes'
run uptime
run cat /usr/lib/lua/8311/version.lua
run fw_printenv -n mib_file
run fw_printenv -n 8311_fix_vlans
run uci -q get omci.default.mib_file
run sha256sum /ptconf/8311/xonu-persistence/veip-aligned.ini /ptconf/8311/vlan_fixes_hook.sh
echo 'VLAN MONITOR'
ps w | grep '[8]311-vlansd' || :
run pontop -b -g s
run pontop -b -g 'Optical Interface Status'
run omci_pipe.sh meadg 268 "$gem" 10
run omci_pipe.sh meg 329 1
echo 'COUNTERS_1'
run pontop -b -g 'GEM/XGEM Port Counters'
sleep "$interval"
echo 'COUNTERS_2'
run pontop -b -g 'GEM/XGEM Port Counters'
echo 'ENCRYPTION HOOK LOG'
logread | grep -F xonu-encryption | tail -n 10 || :
echo 'COLLECTION_COMPLETE (command results above require interpretation)'
