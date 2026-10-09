# Troubleshooting by symptom

[Back to README](../README.md)

| Symptom | Check next | Avoid assuming |
| --- | --- | --- |
| No SSH and no ARP for management IP | Host SFP link, native/tagged management path, boot time, subnet conflict | That root password or OMCI is necessarily the cause |
| LOS / no received optical power | Fiber connection, optics, matching PON service | That absent fiber proves the stick is broken |
| O5 but no service MEs | Live MIB, identity, required VEIP model/instance | That DHCP options alone will repair missing provisioning |
| MEs present, no DHCP | Mapper/GEM binding, actual WAN handoff tag, key-error counters | That the first VLAN found in a table is the WAN tag |
| Downstream key errors rise with traffic | Class 268 instance and attribute 10 on the Internet GEM | That every nonzero cumulative error count means current failure |
| Works until reboot | Raw mib_file key, persistent profile, failsafe guards, hook monitor | That `/tmp` or a UCI-only change persists |
| Enc03 but no IP | Router WAN VLAN/MAC, gateway path, packet capture, DHCP | That the encryption workaround fixes every fault |

## Management loss during experimentation

This installation had both profile-related access loss and a UniFi port configuration change that reverted the intended management network. Check the switch port configuration against your saved table. A blue indicator or a 10 Gb link does not prove IP/ARP reachability. Pinging the router's own 192.168.11.2 address does not test the stick.

## VLAN 400 versus 881 versus local transport

An OMCI filter contained VLAN 400, while another filter and extended rules contained 881. The final working handoff remained 881. No complete Nokia-side OMCI dump was obtained, so this case does **not** establish a 400-to-881 translation inside the Nokia. The earlier filter experiment was reverted before success. See [the handoff worksheet](discover-your-handoff.md).

## MAC and DHCP

Preserve the router WAN identity that already worked behind your original ONT. In this site's earlier Nokia setup, one router MAC saw offers without completing a lease; another locally administered MAC worked. An option-61 experiment did not resolve that earlier problem. The actual working MAC is private and should not be copied by other subscribers.

Once the stick's encryption was corrected, DHCP worked without another MAC change or custom DHCP-option change. The stick LCT MAC, PON serial and router WAN MAC are separate values.

## Automatic VLAN selection

Here the detector chose an empty pmapper1 instead of the provisioned pmapper2. The successful configuration preserved OLT-generated rules and used the existing monitor only to run the encryption hook. This does not establish that automatic VLAN fixes should be disabled on every provider or firmware version.

Hardware-offloaded traffic-control rules may report zero software counters even while traffic flows. We relied on GEM counters, captures and actual connectivity rather than treating a zero TC statistic as proof of packet loss.

## Waiting after installation

The original Nokia had been in service since Monday before the Friday cutover. A public PON.wiki **AT&T** guide recommends waiting roughly one to two weeks and until the install ticket closes. That is not a verified Tillman timer or a promise that bypass will remain accepted indefinitely. No public Tillman-specific cutoff cause was established in this investigation. Keep the original ONT and configuration available, and check installation/order completion if uncertain. [Reference](sources.md).

## Stop conditions

If the installer refuses a different profile hash, a custom existing hook, missing tools, wrong live GEM state or an existing backup directory, read the error and review the mismatch. Those guards protect a very specific tested combination. Changing VLAN/GEM/model values requires a reviewed adaptation of the scripts, not only substitution in the router examples.
