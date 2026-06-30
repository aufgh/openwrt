#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "${ROOT_DIR}/build.env"

TTL_VALUE="${INPUT_TTL_VALUE:-${TTL_VALUE}}"
OPENWRT_DIR="${ROOT_DIR}/openwrt"

if ! [[ "${TTL_VALUE}" =~ ^[0-9]+$ ]] || (( TTL_VALUE < 1 || TTL_VALUE > 255 )); then
  echo "TTL_VALUE must be an integer from 1 to 255." >&2
  exit 2
fi

rm -rf "${OPENWRT_DIR}"
git clone --depth 1 --branch "${OPENWRT_BRANCH}" "${OPENWRT_REPO}" "${OPENWRT_DIR}"

cd "${OPENWRT_DIR}"
mkdir -p package/custom files
cp -a "${ROOT_DIR}/files/." files/
find files -type f -name '*.nft' -exec sed -i "s/@TTL_VALUE@/${TTL_VALUE}/g" {} +

cp "${ROOT_DIR}/patches/mt7981b-netis-nx30v2.dts" target/linux/mediatek/dts/mt7981b-netis-nx30v2.dts

git clone --depth 1 https://github.com/Zesuy/luci-app-multi-login.git package/custom/luci-app-multilogin
git clone --depth 1 https://github.com/Zesuy/UA-Mask.git package/custom/UAmask
git clone --depth 1 https://github.com/linkease/istore.git package/custom/istore
git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon.git package/custom/luci-theme-argon
git clone --depth 1 https://github.com/pppoex/openwrt-packages.git /tmp/pppoex-openwrt-packages
cp -a /tmp/pppoex-openwrt-packages/luci-app-syncdial package/custom/luci-app-syncdial

./scripts/feeds update -a
./scripts/feeds install -a

cat > .config <<EOF
CONFIG_TARGET_${TARGET_BOARD}=y
CONFIG_TARGET_${TARGET_BOARD}_${TARGET_SUBTARGET}=y
CONFIG_TARGET_${TARGET_BOARD}_${TARGET_SUBTARGET}_DEVICE_${TARGET_PROFILE}=y

CONFIG_DEVEL=y
CONFIG_CCACHE=y

CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-base=y
CONFIG_PACKAGE_luci-ssl=y
CONFIG_PACKAGE_luci-compat=y
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y
CONFIG_PACKAGE_luci-proto-ipv6=y
CONFIG_PACKAGE_luci-theme-argon=y

CONFIG_PACKAGE_mwan3=y
CONFIG_PACKAGE_luci-app-mwan3=y
CONFIG_PACKAGE_luci-i18n-mwan3-zh-cn=y

CONFIG_PACKAGE_luci-app-multilogin=y
CONFIG_PACKAGE_UAmask=y
CONFIG_PACKAGE_luci-app-store=y
CONFIG_PACKAGE_luci-app-syncdial=y
CONFIG_PACKAGE_luci-app-zerotier=y
CONFIG_PACKAGE_luci-i18n-zerotier-zh-cn=y
CONFIG_PACKAGE_zerotier=y

CONFIG_PACKAGE_odhcp6c=y
CONFIG_PACKAGE_odhcpd-ipv6only=y

CONFIG_PACKAGE_kmod-nft-core=y
CONFIG_PACKAGE_kmod-nft-nat=y
CONFIG_PACKAGE_kmod-nft-tproxy=y
CONFIG_PACKAGE_nftables-json=y

CONFIG_PACKAGE_kmod-usb-core=y
CONFIG_PACKAGE_kmod-usb2=y
CONFIG_PACKAGE_kmod-usb3=y
CONFIG_PACKAGE_kmod-usb-storage=y
CONFIG_PACKAGE_kmod-usb-storage-extras=y
CONFIG_PACKAGE_kmod-usb-net=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ether=y
CONFIG_PACKAGE_kmod-usb-net-cdc-mbim=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ncm=y
CONFIG_PACKAGE_kmod-usb-net-rndis=y
CONFIG_PACKAGE_kmod-usb-net-qmi-wwan=y
CONFIG_PACKAGE_kmod-usb-serial=y
CONFIG_PACKAGE_kmod-usb-serial-option=y
CONFIG_PACKAGE_usbutils=y
CONFIG_PACKAGE_uqmi=y
EOF

make defconfig

required_packages=(
  luci
  luci-i18n-base-zh-cn
  luci-proto-ipv6
  luci-theme-argon
  mwan3
  luci-app-mwan3
  luci-app-multilogin
  UAmask
  luci-app-store
  luci-app-syncdial
  luci-app-zerotier
  zerotier
  odhcp6c
  odhcpd-ipv6only
  kmod-usb3
  kmod-usb-storage
  kmod-usb-net-rndis
  kmod-usb-net-cdc-ether
  kmod-usb-net-cdc-ncm
  kmod-usb-net-cdc-mbim
  kmod-usb-net-qmi-wwan
)

missing=0
for package_name in "${required_packages[@]}"; do
  if ! grep -q "^CONFIG_PACKAGE_${package_name}=y$" .config; then
    echo "::error::Package was not selected after defconfig: ${package_name}" >&2
    missing=1
  fi
done

if (( missing != 0 )); then
  echo "One or more requested packages are missing. Check package source compatibility or package names." >&2
  exit 3
fi

make download -j"$(nproc)" V=s
make -j"$(nproc)" V=s || make -j1 V=s
