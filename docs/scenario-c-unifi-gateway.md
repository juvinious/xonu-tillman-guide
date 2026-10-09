# C — Stick directly in a UniFi gateway (proposed, not field-tested here)

[Back to scenarios](../README.md#choose-your-topology) · [Discover your handoff](discover-your-handoff.md)

Substitute your verified host-facing Internet tag for `ISP_VLAN` and an unused local management transport tag for `MGMT_VLAN`. The tested site used 881 and 4000 respectively. These examples assume tagged Internet and untagged management; see the handoff guide for other bridge/tagging arrangements. DHCP and priority 0 are also case-study values: preserve your own service protocol, credentials and required priority when they differ.

This scenario requires a **gateway/router with a suitable WAN-capable SFP+ port**. A USW Aggregation is a switch and does not replace pfSense's router, DHCP-client, NAT and firewall roles. Gateway models and UniFi versions differ; none was validated for direct attachment in this case study.

## WAN setup

1. Back up the gateway configuration and record the current WAN port, tagging, MAC and DHCP settings.
2. Confirm ONT-stick compatibility, power/thermal capacity and 10 Gb link operation for your exact gateway and firmware.
3. In **Settings > Internet**, select the intended connection and map it to the SFP+ WAN port. Port-remapping controls vary by model/version.
4. Configure **IPv4 DHCP** and **WAN VLAN ID ISP_VLAN**, priority **0/default**, for the provisioning observed here. Configure the tag on the **Internet/WAN connection**, not by making a LAN network with that VLAN ID.
5. Retain your own established WAN MAC when migrating an existing DHCP service. Leave custom DHCP options at their existing working values. IPv6 was not tested in this case study.
6. Confirm DHCP address, gateway, DNS and browsing. Continue with the common encryption diagnosis if the ONT is O5 but Internet is absent.

| Frame type at the stick | Expected handling |
| --- | --- |
| Internet VLAN ISP_VLAN | Gateway's tagged DHCP WAN |
| Untagged management, 192.168.11.1 | Separate management mechanism required |

The local `MGMT_VLAN` transport is not required with direct attachment. It was a local switch transport label in scenario A. VLAN 400 appearing in one OMCI filter is also not a reason to replace the confirmed WAN tag.

## Management access is the unresolved model-specific part

Do not assume that setting the DHCP WAN tag also makes the stick's untagged management address reachable. Persistent IP aliases, routing and source NAT on the physical WAN parent depend on the gateway/software. Generic Linux `ip addr` shell commands may disappear after provisioning or reboot and are not supplied as a supported permanent solution here.

Prepare the stick using an isolated, compatible SFP+ host or the managed-switch approach in [scenario D](scenario-d-unifi-switch-gateway.md). Establish a way to collect diagnostics before choosing direct attachment for ongoing use. A maintenance move to that host interrupts Internet while the stick is moved.

Scenario D provides an explicit management-port design without gateway-specific shell modifications; it still requires validation on your hardware. If you validate direct management on a particular gateway, contribute the exact model, UniFi OS/Network versions, supported configuration method and reboot evidence.

## Shared setup, tests and rollback

The ONT identity, VEIP and encryption steps are in [stick setup](stick-setup.md). The persistence installer runs **on the stick**, never on the UniFi gateway. Only use it when its exact-case preconditions match.

Validate Internet, reconnect, reboot and key-error behavior using [the test sequence](persistence-and-recovery.md#validation). For rollback, reconnect the original Nokia and restore the original gateway WAN port and VLAN/MAC settings. Do not assume that an original Nokia Ethernet handoff requires tag ISP_VLAN merely because the stick does.
