# D — UniFi switch + UniFi gateway (proposed, not field-tested here)

[Back to scenarios](../README.md#choose-your-topology) · [Discover your handoff](discover-your-handoff.md)

Substitute your verified host-facing Internet tag for `ISP_VLAN` and an unused local management transport tag for `MGMT_VLAN`. The tested site used 881 and 4000 respectively. These examples assume tagged Internet and untagged management; see the handoff guide for other bridge/tagging arrangements. DHCP and priority 0 are also case-study values: preserve your own service protocol, credentials and required priority when they differ.

This keeps the stick in a managed SFP+ switch and uses a **dedicated gateway WAN connection**, plus an isolated management access port. It avoids needing an untagged management IP on the gateway's WAN parent. Use a WAN Ethernet/SFP+ connection capable of your service rate.

The following port numbers are examples, not the tested site's port numbers:

| Switch port | Native network | Tagged VLANs | Connected device |
| --- | --- | --- | --- |
| 1 | Management MGMT_VLAN | ISP_VLAN only | X-ONU-SFPP |
| 2 | Management MGMT_VLAN | ISP_VLAN only | Dedicated UniFi gateway WAN |
| 3 | Management MGMT_VLAN | Block all | Admin laptop or dedicated management host |

Create these as transport networks with **Third-party Gateway / VLAN-only** handling; do not create LAN routing or a DHCP server on ISP_VLAN. The gateway obtains its ISP address through **Settings > Internet**, with IPv4 DHCP and WAN tag **ISP_VLAN**. Port 2's native management traffic is unused by the gateway unless separately configured. Retain the established WAN MAC.

Do not connect gateway LAN to the same unisolated transport network. A separate gateway LAN uplink may serve ordinary LAN VLANs, but do not allow ISP_VLAN there. Keep management VLAN MGMT_VLAN restricted to the intended ports.

## Management host

Connect an admin host to port 3 and assign **192.168.11.2/24**, **no default gateway** and no DHCP service on this adapter. Use a separate connection for normal LAN/Internet access if needed. Do not enable connection sharing or bridge its adapters.

Verify that the host reaches 192.168.11.1, then use this desktop SSH alias (no ProxyJump):

```sshconfig
Host stick
    HostName 192.168.11.1
    User root
    ConnectTimeout 10
    ServerAliveInterval 5
    ServerAliveCountMax 2
```

Browse directly to `https://192.168.11.1` from that host. Follow [stick setup](stick-setup.md) and [persistence/testing](persistence-and-recovery.md). As with other proposed scenarios, confirm exact gateway and switch interoperability before treating this as production-tested.

## Alternative: untagged gateway WAN

If the gateway is to receive untagged Internet, set **port 2 native VLAN ISP_VLAN, tagged VLANs blocked**, and set the gateway's WAN VLAN option **off/untagged**. Port 1 remains native MGMT_VLAN, tagged ISP_VLAN. The switch strips/adds tag ISP_VLAN between these ports. Management stays on port 3. This variant is also untested here. Choose one handoff consistently; do not enable WAN tag ISP_VLAN on an access port that only permits untagged traffic.

## Rollback

Return the fiber and gateway WAN cable to their previous Nokia arrangement, then restore that connection's saved tagging and MAC settings. Keep the old physical path documented before changing anything.
