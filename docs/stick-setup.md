# Common stick setup and diagnosis

[Choose a topology](../README.md#choose-your-topology) · [Discover your handoff](discover-your-handoff.md) · [Persistence](persistence-and-recovery.md)

This sequence reconstructs the successful case. Read the gates before running commands. Perform disruptive steps in a maintenance window with the original ONT and router configuration available. The serial and bridge/VLAN values must come from your own service. The helper profile is for the exact case described, not all Nokia ONTs.

## 1. Establish and record a baseline

Start with the original ONT providing working Internet and configure stick management using your scenario guide. Keep your known-working router WAN MAC. In this case an earlier Nokia DHCP problem had been resolved with a locally administered router MAC; changing the stick's management MAC was not the final fix.

On the stick, record:

```sh
cat /usr/lib/lua/8311/version.lua
sha256sum /etc/init.d/omcid.sh /usr/sbin/8311-vlansd.sh /usr/lib/libponnet.so.0.0.0
uci -q get omci.default.mib_file
```

The tested release was `variant = "basic"`, `version = "v2.8.3"`, `revision = "7d89440"`. PON FW was `3.21.0.3.16-1674463172`, PON SW `1.22.9`, and pontop `1.7.2`. The inspected libponnet was already suitable; **no binary patch was applied**. Its checksum was `687f88bda014c86e7c6bff59857d10ea3bfe7307d6204bc327c616e8b39b20bc`.

From the repository root on the desktop, capture a private backup:

```sh
ssh -T stick 'sh -s' < scripts/backup-private.sh > ../xonu-before-private.tgz
```

Check SSH's exit status and run `tar -tzf ../xonu-before-private.tgz` locally. The new backup helper collects configuration, not firmware or every device setting; it is not a one-command restore. It contains sensitive data and belongs outside the public repository. Also export pfSense and UniFi backups using their own interfaces.

## 2. Configure your own ONT identity

Use the firmware's 8311 configuration interface and save the identity of **your issued ONT** before making the custom MIB profile. Verify runtime identity after provisioning, not just the UI text. Useful checks on the stick:

```sh
omci_pipe.sh meg 256 0
omci_pipe.sh meg 257 0
omci_pipe.sh meg 7 0
omci_pipe.sh meg 7 1
```

The tested values are in the README. Serial is deliberately omitted. Relevant v2.8.3 environment keys are `gpon_sn`, `vendor_id`, `hw_ver`, `sw_verA`, `sw_verB`, `equipment_id`, `omcc_version` and `iop_mask` under the `8311_` prefix. The `fwenv_set --8311 KEY VALUE` helper writes that prefix. Use the release's UI/documentation to apply changes; writing an environment variable alone does not establish the current runtime state.

An observed software string or equipment ID is not evidence that all networks require it. This case used twenty ASCII zeros for equipment ID successfully. Copy your actual identity and inspect provider-specific guidance rather than treating every table entry as mandatory.

## 3. Verify optical registration

During the maintenance window, move the fiber to the stick and check:

```sh
pontop -b -g 'Optical Interface Status'
pontop -b -g s
omci_pipe.sh md
8311-extvlan-decode.sh -t
```

Observed here: RX `-13.79 dBm`, TX `6.49 dBm`, receiver OK, O5.1, FEC enabled. Initially the stock `prx300_1U.ini` profile reached O5 but had no extended VLAN table and lacked the service entities required for Internet. O5 was therefore only an intermediate success.

Return fiber to the original ONT if you need Internet while preparing the next stage. The examples below deliberately keep a boot failsafe until the temporary profile is proven.

## 4. Prepare the aligned VEIP profile (exact case only)

The working profile came from `prx300_1V.ini`. It changed vendor/model fields, moved cardholder/circuit-pack `0x0101` to `0x0100`, then aligned non-comment `0x0101` references to `0x0001`. This included the VEIP, hidden Ethernet UNI and queue references. Changing only the VEIP entity had previously caused management loss. The successful coordinated remap is not a universal rule for OMCI templates.

Confirm your issued model/hardware matches and the OLT behavior justifies this remap. If your current profile already provisions the correct service, do not change it merely to satisfy this installer.

While management is reachable, check whether any failsafe files already exist:

```sh
ls -l /root/.failsafe /tmp/.failsafe /ptconf/.failsafe
```

Missing-file messages are normal. If a guard already exists, understand why before proceeding. For this controlled trial, create the persistent guard **on the stick**, then stop OMCI:

```sh
touch /ptconf/.failsafe && sync
/etc/init.d/omcid.sh stop
```

This guard prevents the stock `rc.local` from starting OMCI at the next boot. It does not prevent the explicit manual start below. Stopping OMCI interrupts service if fiber is currently on the stick.

Generate the profile from the desktop:

```sh
ssh -T stick 'sh -s' < scripts/prepare-profile.sh > ../xonu-profile-prepare.txt 2>&1
```

The helper creates `/tmp/veip-aligned.ini` only if its SHA-256 matches the field-tested profile. It refuses an existing target, changed template or mismatched output. The full firmware MIB is not redistributed in this repository.

## 5. Test with automatic VLAN edits disabled

The detector selected `pmapper1` with an empty GEM list; the provisioned Internet path used `pmapper2` and GEM 1028. For the temporary test, back up `/tmp/8311-config.sh` privately if present, then write this **on the stick**:

```sh
printf 'FIX_ENABLED=0\n' > /tmp/8311-config.sh
```

On the reviewed firmware the fix script checks this before rewriting traffic-control rules. It suppresses subsequent automatic edits; it does not undo rules already applied. The OMCI stop/start here recreates the test's provisioning state. Do not run the detector manually in a mode that overwrites this file during the trial.

Select the temporary profile **without committing it**, then start OMCI:

```sh
uci set omci.default.mib_file=/tmp/veip-aligned.ini
/etc/init.d/omcid.sh start >/tmp/xonu-omcid-start.log 2>&1
```

Move the fiber to the stick if not already connected. Check management, O5 and the MIB:

```sh
omci_pipe.sh meg 329 1
omci_pipe.sh md
8311-extvlan-decode.sh -t
ip -d link show dev gem1028
```

For this line, provisioning created VEIP 1, GEMs 1028/2046, mapper entities 1/2 and an extended VLAN table. Internet mapped through pmapper2 and tagged 881. Follow your topology guide to switch the router WAN to that handoff while retaining the working MAC.

If SSH becomes unreachable, return Internet to the original ONT. Reboot/power-cycle the stick once and allow several minutes; the guard should keep OMCI stopped on this reviewed firmware. Confirm the switch port's native/tagged settings, which had also caused management loss during this project. Do not repeatedly apply different MIB edits through an unstable connection.

## 6. Diagnose the encryption blocker

On this line DHCP DISCOVERs went out but no lease arrived. Every downstream packet was initially accompanied by a key error. The significant read/write commands were:

```sh
pontop -b -g 'GEM/XGEM Port Counters'
omci_pipe.sh meadg 268 1028 10
omci_pipe.sh meads 268 1028 10 3
```

**Run the write only for a confirmed Internet GEM with the matching failure.** PON.wiki documents setting attribute 10 to 3 when the relevant key ring is 0 or 1 and key errors indicate this problem. Here it was 0. DHCP succeeded immediately after the write without a manual release/renew. [Source and credit](sources.md).

Class 268's instance here equaled the GEM ID, 1028; verify your mapping. `meads` is the attribute setter; `meas` is not interchangeable. Avoid applying this change indiscriminately to every GEM.

Check that attribute reads `03`, kernel `ip -d link` reports `enc: 3`, traffic increases and errors stop increasing. Nonzero cumulative errors alone do not mean the fix failed.

## 7. Gate before persistence

Only after management and Internet work, remove the test guard **you created**:

```sh
rm -f /ptconf/.failsafe && sync
```

Do not reboot yet: the profile is in `/tmp` and encryption is runtime-only. Verify no other failsafe guard remains, then follow [persistence and recovery](persistence-and-recovery.md). The installer will preserve the exact profile and arrange automatic encryption recovery.
