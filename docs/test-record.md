# Test record — October 9, 2026

[Back to README](../README.md)

These are observations from one live T-Mobile/Tillman installation using scenario A. The evidence files are selected device output with identifiers removed where needed. They are not generated examples. The stick's calendar was incorrect; timestamps showing September 2025 are retained as device output, not the actual test date.

## Sequence and results

| Stage | Observation | Meaning / limitation |
| --- | --- | --- |
| Stock 1U profile | O5.1, missing service/extended-VLAN entities | Optical registration alone was insufficient |
| Partial VEIP changes | Management loss; power-cycle recovery needed in earlier trials | Do not change only the VEIP instance |
| Aligned 1V-derived profile | VEIP 1 and service entities present; management reachable | Profile passed this OLT's provisioning stage |
| Automatic VLAN detector | Selected pmapper1, empty Internet GEM list | Did not match the observed pmapper2/GEM1028 Internet path |
| Automatic VLAN changes disabled | Provisioned traffic-control path preserved | Necessary context for the successful test; not an isolated proof that all auto-fix behavior is defective |
| VLAN 400 filter override | Removing that filter did not obtain DHCP; change reverted | Not part of the working solution |
| Before encryption change | Downstream packets and key errors rose together, no lease | Directed diagnosis toward encryption |
| Attribute 10 set to 3 | DHCP lease appeared without release/renew | Final blocking change in the tested state |
| Persistent installation | Correct saved profile and hook-only mode | No OMCI restart during installation |
| Fiber reconnect | O5.1, enc03; hook setter logged | Automatic recovery after optical interruption |
| Software reboot | Uptime 2 min, monitor running, profile checksum correct, enc03 | Boot persistence demonstrated |
| Final two snapshots | Traffic grew, key errors remained 4 | No continuing key errors over the observed interval |

## Counter evidence

All rows below refer to GEM 1028.

| Capture / stage | Upstream packets | Downstream packets | Key errors |
| --- | ---: | ---: | ---: |
| Encryption test, before | 233 | 3,035 | 3,035 |
| Encryption test, first snapshot after write | 234 | 3,036 | 3,036 |
| Encryption test, last snapshot | 9,349 | 17,652 | 3,036 |
| Persistence install | 35,121 | 47,396 | 3,036 |
| Separate monitor check | 46,715 | 60,498 | 3,036 |
| Reconnect | 53,478 | 67,371 | 3,272 |
| Reboot | 6,481 | 9,764 | 4 |
| Final snapshot 1 | 12,469 | 16,616 | 4 |
| Final snapshot 2, 15 seconds later | 14,753 | 20,583 | 4 |

The reconnect interval accumulated 236 additional key errors. This is consistent with packets arriving before the hook corrected the setting; the capture does not timestamp each packet/error. Counters reset across the reboot. Final samples add 3,967 downstream packets without adding key errors.

The user explicitly confirmed Internet use through the stick after the runtime encryption change. Reconnect/reboot captures subsequently demonstrated O5, successful hook application and bidirectional GEM traffic. Those captures do not independently measure DNS, end-to-end application availability, a DHCP-renewal cycle, or throughput.

## What was not tested

- Direct pfSense attachment or any UniFi gateway scenario.
- A second subscriber, alternate VLAN/GEM/ONT, or another 8311 release.
- IPv6, voice, IPTV, multi-GEM Internet or upstream encryption requirements.
- Continuous long-term uptime, a firmware upgrade, a monitor crash, or an encryption change without topology change.
- Installer rollback after successful deployment, sudden power loss during installation, or automatic recovery from every possible partial write.

## Offline repository tests

Run from the repository root with Python 3 and a POSIX shell:

```sh
python3 -m unittest discover -s tests -v
```

Tests exercise the extracted hook with fake device commands, shell syntax, input validation, refusal to install a mismatched generated profile, relative documentation links, and the final counter evidence. They do not execute the installer against host firmware or claim to emulate an OLT.
