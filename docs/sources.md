# Sources and credits

[Back to README](../README.md)

The case-specific findings come from the operator's device captures and testing on October 9, 2026. The public sources below support the underlying tools, firmware behavior and platform configuration. Proposed scenarios are reasoned adaptations, not vendor certification of this ONT bypass.

## 8311 and PON.wiki

- [PON.wiki: troubleshooting WAS-110 / X-ONU-SFPP](https://pon.wiki/guides/troubleshoot-connectivity-issues-with-the-was-110-or-x-onu-sfpp/). The Nokia OLT / GEM encryption section documents checking key errors and class 268 attribute 10, then setting 3 for the described 0/1 failure. The encryption workaround is community knowledge; it was not invented by this repository.
- [8311 firmware builder](https://github.com/djGrrr/8311-was-110-firmware-builder), reviewed revision `7d89440c7d9e1f209140910bb039f5d5a24dfbed`.
- [Firmware VLAN monitor at that revision](https://github.com/djGrrr/8311-was-110-firmware-builder/blob/7d89440c7d9e1f209140910bb039f5d5a24dfbed/files/common/usr/sbin/8311-vlansd.sh). Source for the hook, mode handling and topology-hash retry behavior.
- [Firmware helpers](https://github.com/djGrrr/8311-was-110-firmware-builder/blob/7d89440c7d9e1f209140910bb039f5d5a24dfbed/files/common/lib/8311.sh) and [PON initialization](https://github.com/djGrrr/8311-was-110-firmware-builder/blob/7d89440c7d9e1f209140910bb039f5d5a24dfbed/files/common/etc/init.d/_8311-poninit.sh). The installed `/etc/init.d/omcid.sh` and `/etc/rc.local` were also inspected directly; their installed behavior matters more than assumptions from a newer branch.
- [PON.wiki AT&T BGW320 guide](https://pon.wiki/guides/masquerade-as-the-att-inc-bgw320-500-505-with-the-was-110/). Cited only for the new-install waiting advice discussed in troubleshooting; it is not a Tillman setup guide.

## Router and switch documentation

- [Netgate: VLAN configuration](https://docs.netgate.com/pfsense/en/latest/vlan/configuration.html): create a VLAN with a parent/tag, then assign it as an interface.
- [Netgate: interface configuration](https://docs.netgate.com/pfsense/en/latest/config/interface-configuration.html): physical/VLAN assignment and IP configuration.
- [Netgate: IPv4 configuration types](https://docs.netgate.com/pfsense/en/latest/interfaces/configure-ipv4.html): DHCP/static addressing and gateway selection.
- [Ubiquiti: switch port VLAN assignment](https://help.ui.com/hc/en-us/articles/26136855808919-Switch-Port-VLAN-Assignment-Trunk-Access-Ports): native traffic versus allowed tagged networks.
- [Ubiquiti: virtual networks](https://help.ui.com/hc/en-us/articles/9761080275607-Creating-Virtual-Networks-VLANs): third-party routing and VLAN creation.
- [Ubiquiti: gateway port remapping](https://help.ui.com/hc/en-us/articles/360008365334-UniFi-Gateway-Port-Remapping): mapping supported ports to WAN roles.

UI labels and supported controls change over time. These sources establish configuration concepts, not blanket compatibility between every listed platform and an X-ONU-SFPP.

## Distribution boundary

The original scripts in this repository call firmware utilities already installed on the stick. They do not bundle those utilities, firmware binaries or full MIB templates. The profile builder transforms the device's existing template. Vendor/community software retains its own licensing. Evidence is selected diagnostic output from the operator's installation.
