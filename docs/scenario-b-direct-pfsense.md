# B — Stick directly in pfSense (proposed, not field-tested here)

[Back to scenarios](../README.md#choose-your-topology) · [Discover your handoff](discover-your-handoff.md)

Substitute your verified host-facing Internet tag for `ISP_VLAN` and an unused local management transport tag for `MGMT_VLAN`. The tested site used 881 and 4000 respectively. These examples assume tagged Internet and untagged management; see the handoff guide for other bridge/tagging arrangements. DHCP and priority 0 are also case-study values: preserve your own service protocol, credentials and required priority when they differ.

Use a dedicated SFP+ NIC port supported by your pfSense/FreeBSD release and compatible with this ONT stick. An Ethernet SFP+ port accepting ordinary transceivers does not by itself establish ONT-stick compatibility, power, cooling or loss-of-signal behavior. This repository does not validate a NIC model for direct attachment.

For this example, call the dedicated port **ix1**. Substitute the actual interface name. Keep LAN on a **different physical port**; do not repurpose the shared LAN parent from scenario A while relying on it for management.

| Function | pfSense interface | Configuration |
| --- | --- | --- |
| Internet | ix1.ISP_VLAN | VLAN ISP_VLAN, IPv4 DHCP, priority 0 |
| Untagged stick management | ix1 | Static 192.168.11.2/24, no upstream gateway, no DHCP server |
| LAN | Separate NIC | Existing LAN configuration |

There is no switch to translate untagged management into VLAN MGMT_VLAN, so **do not create ix1.MGMT_VLAN for a stick whose management remains untagged**. The tagged Internet VLAN and untagged management interface share the dedicated physical port.

## Procedure

1. Export the pfSense configuration and record the existing WAN assignment/MAC.
2. Verify that the dedicated port links with the stick. Use a compatible 10 Gb host setting where required; keep management reachable with the fiber disconnected.
3. Assign the physical parent as an OPT management interface with 192.168.11.2/24. Ensure that subnet is not already assigned elsewhere.
4. Create VLAN ISP_VLAN on that parent under **Interfaces > Assignments > VLANs**, then select it for the existing logical WAN at cutover. Substitute your discovered tag for ISP_VLAN; the exact-case stick installer still has its own fixed requirements.
5. Keep the known-working WAN MAC/DHCP identity and verify existing LAN rules, outbound NAT, gateway and default route.
6. From pfSense, test `ping -S 192.168.11.2 -c 3 192.168.11.1` and SSH to the stick.
7. Use the desktop `router`/`stick` SSH aliases and HTTPS tunnel from [scenario A](scenario-a-pfsense-unifi.md#management-access).
8. Follow [stick setup](stick-setup.md), then [persistence and testing](persistence-and-recovery.md).

If management fails, check link state and ARP before diagnosing SSH credentials. Do not globally disable pfSense's firewall to compensate for a tagging or host compatibility problem.

## Fallback and validation

Reconnect the Nokia to its original Ethernet WAN path and restore the saved WAN assignment. Use the port/tag mapping recorded in your saved `OLD_WAN_PATH`.

To promote this scenario to tested, record the exact NIC model, driver, firmware, pfSense version, link settings, management access with/without fiber, DHCP success, reconnect recovery, reboot recovery, and stable GEM key-error counters.
