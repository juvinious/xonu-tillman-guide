# A — pfSense + UniFi switch (tested)

[Back to scenarios](../README.md#choose-your-topology)

The X-ONU-SFPP occupies **USW Aggregation port 1**. **Port 8** connects to pfSense's 10 Gb interface **mce1**. The parent mce1 already serves the untagged LAN; Internet and stick management use separate tagged children over the same uplink.

## Switch configuration

Create corresponding VLAN networks in UniFi with **Third-party Gateway** (formerly VLAN-only), because pfSense performs routing. Do not create a UniFi DHCP server for the WAN transport or stick management networks.

| Switch port / role | Native / untagged network | Allowed tagged VLANs |
| --- | --- | --- |
| Aggregation 1 — X-ONU-SFPP | 4000, stick management | 881 only |
| Aggregation 8 — pfSense mce1 | Existing LAN | Add 881 and 4000; preserve all existing required tags |
| Previous Nokia Ethernet port, Pro Max 47 | 3000, previous WAN transport | Block all tagged traffic |
| Inter-switch uplinks carrying the Nokia fallback | Preserve their existing native network | Preserve 3000 end to end |

Preserve all existing required VLANs on the pfSense uplink. Port 1 used a manually selected **10 Gb** link speed. Preserve switch management reachability while editing uplinks.

The switch classifies untagged stick management traffic as VLAN 4000 and carries it tagged to pfSense. Internet traffic remains tagged 881. **Do not set 881 as native on the stick port in this tested arrangement.** Do not allow this WAN VLAN on ordinary client ports or Wi-Fi networks.

## pfSense configuration

Export a backup under **Diagnostics > Backup & Restore**. Before reusing 881, inspect existing VLAN objects, assignments, firewall rules, NAT, gateways and policy-routing references. This installation had a stale 881 VLAN on a gigabit parent; the intended parent was the **10 Gb mce1**, not igb0–igb3.

Under **Interfaces > Assignments > VLANs**, create C-tag/802.1Q VLANs **881** and **4000** on **mce1**, priority **0** (or default). Assign them as follows:

| Setting | TMOBILE_WAN | XONU_SFPP management |
| --- | --- | --- |
| Network port | mce1.881 | mce1.4000 |
| Enabled | Yes | Yes |
| IPv4 | DHCP | Static 192.168.11.2/24 |
| IPv6 | None in this test | None in this test |
| Upstream gateway | DHCP-derived | None |
| DHCP server | None | None |
| MTU | 1500/default in this test | 1500/default |
| DHCP send/request/require/options/modifiers | Blank | Not applicable |
| Block private / bogon networks | Unchecked in this test | Unchecked |

The observed service used a CGNAT address. The checkbox state above records this working setup; it does not instruct everyone to remove unrelated firewall protections.

**Reassign the existing logical TMOBILE_WAN interface** from `mce1.3000` to `mce1.881` at cutover. This retains its logical firewall/NAT associations better than creating a second competing WAN. Check that its gateway, gateway-group references, default route and outbound NAT still reference the intended WAN. Preserve the established WAN MAC and DHCP settings; the stick's management MAC is a different identity.

This installation needed no new permissive WAN inbound rule. Normal LAN access, outbound NAT and return-state handling were already working through the Nokia. If building a fresh pfSense configuration, establish those routing/firewall functions separately.

## Management access

On pfSense, verify the management interface before touching OMCI:

```sh
ifconfig mce1.4000
ping -S 192.168.11.2 -c 3 192.168.11.1
arp -an | grep 192.168.11.1
ssh -b 192.168.11.2 root@192.168.11.1
```

On your desktop, add these entries to `~/.ssh/config`, substituting the LAN address of your pfSense router:

```sshconfig
Host router
    HostName 192.0.2.1
    User root
    ConnectTimeout 10
    ServerAliveInterval 5
    ServerAliveCountMax 2

Host stick
    HostName 192.168.11.1
    User root
    ProxyJump router
    ConnectTimeout 10
    ServerAliveInterval 5
    ServerAliveCountMax 2
```

`192.0.2.1` is a documentation placeholder, not a router address to copy. pfSense SSH must be enabled and reachable from your trusted admin machine. Verify host keys normally.

SSH through the router originates on the directly connected management subnet, avoiding the need to add a return route on the stick. To use its HTTPS GUI from the desktop:

```sh
ssh -N -T -o ExitOnForwardFailure=yes -L 127.0.0.1:8443:192.168.11.1:443 router
```

Open `https://127.0.0.1:8443` and use the stick's credentials. Keep that terminal open. A self-signed certificate is expected. No WAN-facing GUI port-forward is needed. Direct routed desktop access would additionally require appropriate LAN rules and a working return path; this guide uses the tested SSH tunnel instead.

Continue with [stick setup](stick-setup.md), then [persistence](persistence-and-recovery.md).

## Fallback

Leave the original Nokia bridge setup and VLAN 3000 path intact. Move the fiber back to the Nokia and reassign TMOBILE_WAN to **mce1.3000**. Preserve its working MAC. Confirm DHCP, routing and browsing; renew DHCP only if necessary. This is the original site's fallback, not a universal VLAN mapping.
