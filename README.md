# T-Mobile / Tillman Fiber: Nokia XS-2426X-A to X-ONU-SFPP

A working case study using an Exen-supplied X-ONU-SFPP, 8311 basic **v2.8.3**, pfSense CE **2.9.0**, and a UniFi USW Aggregation switch. Recorded **October 9, 2026**.

The stick reached O5 before it could pass Internet traffic. Three changes mattered in this installation:

1. Align the VEIP profile and related managed-entity references with the OLT's expected instance **1**.
2. Stop the automatic VLAN fix from choosing the wrong mapper; retain the provisioned **VLAN 881** handoff.
3. Set Internet **GEM 1028**, class **268**, attribute **10**, to **3** (downstream-only encryption), then persist that workaround using the firmware's existing hook.

The connection passed a fiber reconnect and a software reboot. Final samples showed growing traffic with key errors unchanged at **4**. Long-term stability and other installations remain unverified.

## Choose your topology

| Scenario | Read this | Validation |
| --- | --- | --- |
| Stick in UniFi switch, pfSense router | [A — pfSense + UniFi switch](docs/scenario-a-pfsense-unifi.md) | **Tested** on the equipment above |
| Stick directly in pfSense SFP+ NIC | [B — Direct pfSense](docs/scenario-b-direct-pfsense.md) | Proposed adaptation; NIC/driver compatibility untested |
| Stick directly in UniFi gateway WAN SFP+ | [C — Direct UniFi gateway](docs/scenario-c-unifi-gateway.md) | Proposed adaptation; gateway model and management access untested |
| Stick in UniFi switch, UniFi gateway router | [D — UniFi switch + UniFi gateway](docs/scenario-d-unifi-switch-gateway.md) | Proposed adaptation; explicit management access port |

Start with [discovering your ONT bridge and VLAN handoff](docs/discover-your-handoff.md). Even identical ONT models can have different provider profiles.

All paths use the same [stick setup and diagnosis](docs/stick-setup.md), followed by [persistence and recovery](docs/persistence-and-recovery.md). Read your topology first so SSH access works before changing OMCI.

## Scope: discover your values

This is one T-Mobile/Tillman line, **not a universal T-Mobile Fiber preset**. Other infrastructure partners, OLTs, ONT models, firmware releases, VLANs and GEM IDs may differ. Use the identity from your own issued ONT. The user's serial, WAN MAC, hostnames, credentials and full device backups are not included.

| Value | Observed here | How to treat it |
| --- | --- | --- |
| Issued ONT | Nokia XS-2426X-A | Exact model matters |
| Vendor / hardware version | ALCL / 3FE49691AABA | Model-specific; verify yours |
| Advertised software A / B | 3FE49940IJML51 / V0.01 | Observed working values, not universal requirements |
| Equipment ID | Twenty ASCII zero characters | Observed working value; not proof of Nokia factory value |
| OMCC / interoperability mask | 0xA3 / 18 | Working runtime values |
| Internet VLAN / priority | 881 / 0 | Discover from your provisioning |
| Internet mapper / GEM | pmapper2 / 1028 | Discover; installer is deliberately fixed to GEM 1028 |
| Management VLAN | 4000 | Local switch transport choice; stick management was untagged |
| Previous Nokia transport VLAN | 3000 | Local transport choice, not an ISP requirement |
| Stick management IP | 192.168.11.1/24 | Example/default; avoid subnet conflicts |

**The installer is intentionally narrow.** It installs persistence only after the temporary exact profile is working and GEM 1028 already has encryption 03. It does not set your serial, discover VLANs, flash firmware, or configure your router. If a checksum/precondition fails, investigate the mismatch instead of removing the guard.

## Files

| File | Purpose | Tested status |
| --- | --- | --- |
| `scripts/xonu-persist.sh` | Install, inspect or roll back the saved profile and hook | Exact script used on the live stick; included unchanged |
| `scripts/prepare-profile.sh` | Build the exact profile from the template already on the stick | New packaging of the field-used transformation; offline checked |
| `scripts/collect-status.sh` | Read-only status and two counter snapshots | New helper; offline checked, not field-run as a whole |
| `scripts/backup-private.sh` | Stream a private configuration archive over SSH | New helper; offline checked, not field-run as a whole |
| `evidence/` | Selected sanitized captures | Real device output, not simulated |
| `tests/` | Offline syntax, hook behavior, input and evidence checks | Never connects to an ONT |

## Start here

1. Save your router/switch configuration and keep the original ONT available.
2. Choose a topology above and establish stick management access.
3. Follow the common setup in stages: identity, VEIP, forwarding, encryption.
4. Confirm Internet access before installing persistence.
5. Validate reconnect, reboot, and stable error counters; save a private final backup.

Desktop command examples use SSH host aliases `router` and `stick` defined in the scenario guides. They are single-line commands compatible with fish. Commands explicitly labeled **on the stick** run under its `/bin/sh`.

## Evidence and limitations

See [the test record](docs/test-record.md), [troubleshooting](docs/troubleshooting.md), and [sources and credits](docs/sources.md). The community's published encryption workaround is credited there; this repository documents how it fit this particular provisioning problem.

No Nokia exploit, superuser password, binary patch, firmware image, or complete vendor MIB template is included. IPv6, voice, IPTV, speed tiers, long-term uptime, firmware upgrades, and direct-host SFP interoperability were not validated here.

Original repository code and documentation use the [MIT license](LICENSE). See [publishing notes](docs/publishing.md) before uploading your own captures.
