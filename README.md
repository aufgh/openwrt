# Netcore N30 Pro OpenWrt 25.12 build

This repository builds official OpenWrt `openwrt-25.12` firmware for Netcore N30 Pro through GitHub Actions.

## Target

OpenWrt profile:

```text
netis_nx30v2
```

OpenWrt 25.12 defines this target as `netis NX30 V2` with `Netcore N30 Pro` as an alternate model. The DTS file is:

```text
target/linux/mediatek/dts/mt7981b-netis-nx30v2.dts
```

## USB fix

The workflow replaces the upstream DTS with `patches/mt7981b-netis-nx30v2.dts`, based on the CSDN article you provided. The fix explicitly enables USB2/USB3 PHY nodes, xHCI clocks, and the USB VBUS regulator so USB power and RNDIS tethering can work.

## Fixed TTL

The firmware overlay installs:

```text
/etc/nftables.d/99-fixed-ttl.nft
```

OpenWrt firewall4 includes `/etc/nftables.d/*.nft` inside `table inet fw4`, so this uses nftables directly. It does not use iptables. The rule sets both IPv4 `ttl` and IPv6 `hoplimit` in postrouting. Default value is `64`.

## Included packages

Custom source packages:

- `Zesuy/luci-app-multi-login` -> `luci-app-multilogin`
- `Zesuy/UA-Mask` -> `UAmask`, firewall4/nftables version
- `linkease/istore` -> `luci-app-store`, plus `luci-lib-taskd`, `luci-lib-xterm`, and `taskd` dependencies
- `jerrykuku/luci-theme-argon` -> `luci-theme-argon`
- `pppoex/openwrt-packages/luci-app-syncdial` -> newer syncdial package without the old `shellsync` dependency
- `immortalwrt/luci/applications/luci-app-zerotier` -> LuCI page for ZeroTier, because it is not present in official LuCI 25.12

OpenWrt feed packages:

- `mwan3`, `luci-app-mwan3`
- Chinese LuCI translation
- `zerotier`, `luci-app-zerotier`
- IPv6 support via `luci-proto-ipv6`, `odhcp6c`, `odhcpd-ipv6only`
- USB storage and USB network sharing modules including RNDIS, CDC Ethernet, NCM, MBIM, and QMI WWAN

`ipv6helper` is not added as a hard package name because I could not confirm it exists in OpenWrt 25.12. The included IPv6 packages are the practical equivalent for current OpenWrt.

## Build

Run the GitHub workflow manually. The artifact is named:

```text
netcore-n30-pro-openwrt-25.12
```

You can override TTL/hoplimit at workflow dispatch time.
