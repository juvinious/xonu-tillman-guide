# Persistence, validation and recovery

[Back to README](../README.md) · [Common setup](stick-setup.md)

## What the exact-case installer does

`scripts/xonu-persist.sh` is unchanged from the script installed and tested on the live stick. It checks the active profile, file hashes, disabled temporary VLAN fixes, absent failsafe guards and live encryption `03`. It backs up the relevant prior settings under `/ptconf/8311/xonu-persistence/before` before changing boot configuration.

| Item | Installed value |
| --- | --- |
| Saved profile | `/ptconf/8311/xonu-persistence/veip-aligned.ini` |
| Raw firmware environment key `mib_file` | Saved profile path above |
| UCI `omci.default.mib_file` | Same path, committed |
| Environment key `8311_fix_vlans` | `2` — custom hook only on the reviewed daemon |
| Firmware hook | `/ptconf/8311/vlan_fixes_hook.sh` |

The raw **`mib_file`** key is deliberate. Do not substitute `fwenv_set --8311 mib_file`: that writes **`8311_mib_file`**, whose helper only accepts profiles under `/etc/mibs` on this release.

The reviewed boot order is S79 8311 initialization (including VLAN monitor), S85 OMCI boot configuration (reads raw `mib_file`), then the delayed `rc.local` OMCI start. The saved `/ptconf` profile survives the tested reboot. We did not enable whole-root persistence or replace init scripts.

The hook validates `gem1028` as bidirectional/unicast, leaves `enc: 3` alone, otherwise applies attribute 10 = 3 and confirms the kernel state. It returns failure while the GEM is missing so the existing monitor retries. Mode 2 runs the hook without the ordinary VLAN rewrite script.

**Limits:** the monitor uses topology-change hashes, not continuous encryption monitoring. A key-ring change without a detected topology change may be missed. It does not discover a new GEM ID, supervise itself after a crash, guarantee survival across firmware upgrades, or provide a vendor-supported management API. Saving the 8311 GUI can reapply firmware defaults; recheck this custom arrangement after configuration changes.

## Install from a working temporary setup

From the repository root on the desktop:

```sh
ssh -T stick 'cat > /tmp/xonu-persist.sh && sh /tmp/xonu-persist.sh install' < scripts/xonu-persist.sh > ../xonu-persistence-install.txt 2>&1
```

Expected: `INSTALLED`, persistent profile path, VLAN mode `2`, encryption `03`. The script restarts only the VLAN monitor; it does not restart OMCI or reboot.

Check the monitor in a separate SSH session:

```sh
ssh -T stick 'ps w | grep "[8]311-vlansd"; sh /tmp/xonu-persist.sh status' > ../xonu-persistence-check.txt 2>&1
```

The installer is not idempotent: a second install refuses an existing installation directory. Use `status`. Do not delete the backup to force an install. If preflight stopped partway through creating a backup, inspect that specific state before retrying.

## Validation

1. Confirm the router acquired an address and real browsing works; check the expected speed separately if desired.
2. Disconnect only the fiber for about 10 seconds, leaving the stick powered. Reconnect and allow up to two minutes. Do not manually set encryption during this test.
3. Collect status using the helper below. Require O5.1, encryption 03, traffic growth and automatic recovery. A hook log shows whether the setter ran; if encryption remained 03, no new setter log is required.
4. Reboot the stick using `ssh -T stick 'sync; reboot'`. SSH disconnect is expected. Allow up to five minutes; earlier boots in this project took several minutes to expose management reliably.
5. Collect again. Require the persistent profile/checksum, running monitor and recovered service.
6. Compare two counter samples during normal traffic. Initial key errors may accumulate before the hook applies; they should stop increasing afterward.

Read-only collection from the desktop (15-second interval, GEM 1028):

```sh
ssh -T stick 'sh -s -- 1028 15' < scripts/collect-status.sh > ../xonu-status-private.txt 2>&1
```

To use the original field-tested status function after a reboot clears `/tmp`:

```sh
ssh -T stick 'uptime; ps w | grep "[8]311-vlansd"; pontop -b -g s; sh -s -- status; logread | grep -F xonu-encryption | tail -n 10' < scripts/xonu-persist.sh > ../xonu-reboot-check.txt 2>&1
```

The installer status function may show an empty `/tmp/xonu-vlansd.log`: the firmware routes messages to its console/logger, and the background boot launch does not use that temporary redirection. `logread` with `xonu-encryption` is the important setter evidence. Device calendar timestamps in this test were stale; use uptime and capture order rather than treating them as wall-clock dates.

## Save the final configuration privately

```sh
ssh -T stick 'sh -s' < scripts/backup-private.sh > ../xonu-working-private.tgz
```

Verify SSH success and list the archive locally. Also retain the installer, this repository, a current router backup, and switch configuration. No firmware/flash restore is automated by this bundle.

## Recovery has two different meanings

**Return household Internet to the Nokia:** follow your scenario's saved original WAN path. In the tested site, move fiber back and reassign the existing pfSense WAN from mce1.881 to mce1.3000, preserving MAC/DHCP settings. This does not require undoing the stick's stored configuration.

**Undo this installer's settings on the stick:** while management is reachable, run:

```sh
ssh -T stick 'sh -s -- rollback' < scripts/xonu-persist.sh > ../xonu-persistence-rollback.txt 2>&1
```

Rollback restores the backed-up raw environment keys, prior hook and temporary disabled-fix configuration, then restarts the VLAN monitor. It leaves running OMCI and encryption alone. If the old `/tmp` profile no longer exists, the original script falls back to `prx300_1U.ini`; that stock profile did **not** provide working bypass on this line. Rollback is therefore a persistence-settings rollback, not guaranteed Internet restoration. The rollback code was reviewed but a post-success live rollback was not tested.

If management is reachable but OMCI prevents a safe boot, the reviewed `rc.local` honors `/ptconf/.failsafe`. Create it and sync before a planned recovery reboot, then investigate with OMCI stopped. Do not leave it present when expecting automatic service recovery.

## Checksums enforced by the original installer

| File | SHA-256 |
| --- | --- |
| Temporary working profile | `c6df242aa457421b980c6c6d685669c6800965fb948ec5d0e81bb34818ed6020` |
| `/etc/init.d/omcid.sh` | `4acaa2574bf87a4f7ea0f4e21c22aeb1eccfe777e8afabd1ff32b03da3dff1f3` |
| `/usr/sbin/8311-vlansd.sh` | `93697dd306f2a50f4804d35d4af350c090fe8741aa90d345c7be17c268d42f7a` |

Different identity/template requirements may legitimately produce a different hash. That is a reason for a separately reviewed adaptation, not permission to remove all guards or to force someone else's model fields.
