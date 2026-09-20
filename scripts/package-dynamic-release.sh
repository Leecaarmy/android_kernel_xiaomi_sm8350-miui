#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
# Package a reproducible Xiaomi 11 Pro HyperOS 4 / Android 17 release.
set -euo pipefail

src=$(cd -- "$(dirname -- "$0")/.." && pwd)
cd "$src"

out=${OUT:-"$src/../out-dynamic-mars-a17"}
stock_boot=${STOCK_BOOT:-"/mnt/d/codex/sm8350-kernel/evidence/hyperos4-restore-v101-temp-20260918/boot-hyperos4-original.img"}
release_dir=${RELEASE_DIR:-"$src/../release-dynamic-mars-a17"}

out=$(cd -- "$out" && pwd)
release_dir=$(mkdir -p "$release_dir" && cd -- "$release_dir" && pwd)
stock_boot=$(cd -- "$(dirname -- "$stock_boot")" && pwd)/$(basename -- "$stock_boot")

commit=$(git rev-parse --verify HEAD)
short=${commit:0:7}
kernel_release=$(cat "$out/include/config/kernel.release")
expected="5.4.302-Dynamic-g${short}"
test "$kernel_release" = "$expected"
case "$kernel_release" in
    5.4.302-Dynamic-g???????) ;;
    *) echo "unexpected kernel release: $kernel_release" >&2; exit 1 ;;
esac
test -f "$out/arch/arm64/boot/Image"
test -f "$out/.config"
test -f "$stock_boot"

source_date_epoch=$(git show -s --format=%ct HEAD)
source_commit_time=$(TZ=Asia/Shanghai git show -s --date=format-local:%Y-%m-%dT%H:%M:%S%z --format=%cd HEAD)
stamp=$(TZ=Asia/Shanghai git show -s --date=format-local:%Y%m%d-%H%M --format=%cd HEAD)
base="${kernel_release}-${stamp}"

rm -rf "$release_dir/staging-ak3" "$release_dir/manifest.tmp"
mkdir -p "$release_dir/staging-ak3"

image="$release_dir/Image-${base}"
boot="$release_dir/boot-${base}.img"
config="$release_dir/config-${base}"
ak3="$release_dir/Dynamic-AK3-${base}.zip"
manifest="$release_dir/dynamic-build-manifest-${stamp}.txt"
sums="$release_dir/SHA256SUMS-${stamp}.txt"

rm -f "$image" "$boot" "$config" "$ak3" "$manifest" "$sums"
cp "$out/arch/arm64/boot/Image" "$image"
cp "$out/.config" "$config"
python3 scripts/dynamic/repack_boot_v3.py "$stock_boot" "$image" "$boot"
python3 scripts/dynamic/verify_boot_repack.py "$stock_boot" "$boot"

cp -a scripts/ak3/. "$release_dir/staging-ak3/"
cp "$image" "$release_dir/staging-ak3/Image"
(
    cd "$release_dir/staging-ak3"
    rm -f README.md
    zip -q -r9 "$ak3" . -x '.git/*' '*placeholder*'
)
unzip -Z1 "$ak3" | grep -qx 'Image'
unzip -Z1 "$ak3" | grep -qx 'anykernel.sh'

{
    printf 'source_commit=%s\n' "$commit"
    printf 'source_commit_time=%s\n' "$source_commit_time"
    printf 'source_date_epoch=%s\n' "$source_date_epoch"
    printf 'kernel_release=%s\n' "$kernel_release"
    printf 'artifact_timestamp=%s\n' "$stamp"
    printf 'build_user=%s\n' "${KBUILD_BUILD_USER:-Dynamic}"
    printf 'build_host=%s\n' "${KBUILD_BUILD_HOST:-mars}"
    printf 'compiler='; clang-17 --version | head -1
    printf 'linker='; ld.lld-17 --version | head -1
    printf 'stock_boot_sha256='; sha256sum "$stock_boot" | awk '{print $1}'
    printf 'stock_boot=%s\n' "$stock_boot"
    printf 'image=%s\n' "$(basename "$image")"
    printf 'boot=%s\n' "$(basename "$boot")"
    printf 'ak3=%s\n' "$(basename "$ak3")"
    printf 'config=%s\n' "$(basename "$config")"
    printf 'image_sha256='; sha256sum "$image" | awk '{print $1}'
    printf 'boot_sha256='; sha256sum "$boot" | awk '{print $1}'
    printf 'ak3_sha256='; sha256sum "$ak3" | awk '{print $1}'
    printf 'config_sha256='; sha256sum "$config" | awk '{print $1}'
} | tee "$manifest"

sha256sum "$image" "$boot" "$ak3" "$config" "$manifest" > "$sums"
rm -rf "$release_dir/staging-ak3"
printf 'release_dir=%s\n' "$release_dir"
printf 'stamp=%s\n' "$stamp"
