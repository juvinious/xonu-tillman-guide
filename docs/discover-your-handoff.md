# Discover your ONT identity, bridge and VLAN handoff

[Back to scenarios](../README.md#choose-your-topology)

**The same ONT model can receive different provisioning on different lines.** A model number alone does not determine VLAN, bridge behavior, GEM ID or required OMCI entities. Complete this worksheet from your own working installation before adapting the examples.

| Item | Your observation | Tested case for comparison |
| --- | --- | --- |
| Provider and underlying fiber operator | Record both | T-Mobile / Tillman |
| ONT model, hardware and software versions | Read your device | XS-2426X-A, values in README |
| ONT identity | Keep serial and credentials private | Original issued identity retained |
| Nokia WAN connection type | DHCP / PPPoE / other | IPv4 DHCP |
| Bridge mode and selected LAN port | Record exact labels and binding | Bridge; 10 Gb LAN4 |
| Bridge VLAN mode | Tunnel / transparent / translation / other | UI reported Tunnel |
| Bridge VLAN ID and priority | Record exact values | UI reported 881, priority 0 |
| Tag on the Nokia Ethernet handoff | Establish from working router/switch or capture | Original local access path used VLAN 3000 |
| Tag on the stick's host-facing Internet traffic | Establish after OMCI provisioning | Tagged 881 |
| OMCI VEIP, mapper, GEM and VLAN rules | Inspect your live MIB and interfaces | VEIP 1, pmapper2, GEM 1028 |
| Stick management tagging/subnet | Establish separately | Untagged, 192.168.11.1/24 |
| Locally chosen transport VLANs | Choose unused IDs | Management 4000, old WAN 3000 |

The Nokia UI's **Tunnel** label and VLAN field do not, alone, tell you whether its LAN output is tagged, untagged or translated. Nor does the presence of VLAN 400 in an OMCI filter prove an Internet tag of 400 or a 400-to-881 translation. Keep device configuration, actual frame tagging and local switch transport as separate observations.

## Names used in the proposed scenarios

| Placeholder | Meaning |
| --- | --- |
| `ISP_VLAN` | The verified **host-facing Internet tag from the stick** in the tagged-handoff examples; it was 881 here. Internal PON/service tags need not be identical if translation is configured. |
| `MGMT_VLAN` | Locally chosen switch VLAN transporting untagged stick management; it was 4000 here. |
| `OLD_WAN_PATH` | The complete original ONT-to-router port/tag mapping, preserved for rollback. |
| `GEM_ID` | The live GEM carrying your Internet service; it was 1028 here. |

These are placeholders, not literal GUI inputs or preconfigured shell variables. Substitute observed values, including the WAN protocol and priority. DHCP and priority 0 are not universal requirements. The shipped persistence installer remains an **exact-case GEM-1028 implementation**, regardless of the placeholders in the topology examples.

## How to establish the handoff

1. Record the existing ONT bridge page, service VLAN fields, LAN-port binding and WAN protocol. Save screenshots privately.
2. Record the native/tagged state of every switch port in the existing path and the router's WAN VLAN configuration. A native switch VLAN can transport an untagged ONT handoff under an unrelated local tag.
3. If the wire format is still unclear, capture Ethernet frames on a mirror port adjacent to the ONT. Host VLAN offload can hide tags in software captures, so corroborate with port configuration. Keep captures private.
4. With the stick provisioned, inspect `omci_pipe.sh md`, `8311-extvlan-decode.sh -t`, `ip -d link`, and the relevant live entities. Determine which mapper leads to the actual Internet GEM. O5 alone does not establish service forwarding.
5. Match the router-facing handoff first, then troubleshoot DHCP and encryption. Change one layer at a time.

The scenario examples assume **tagged Internet plus separate untagged management**, which is what worked here. If your stick exports **untagged Internet**, the direct gateway WAN may need no VLAN tag, and a switch may assign a local transport VLAN before forwarding it to a router. However, untagged Internet and untagged management cannot be separated by assigning two different native VLANs to one physical switch port. Review the stick's supported management arrangement and your isolation requirements before adapting that case; no untagged-Internet design was validated in this project.

Do not copy another subscriber's serial, MAC, LOID, password or entire firmware environment. Preserve your own previously working router WAN MAC first; management MAC and PON serial serve different roles.
