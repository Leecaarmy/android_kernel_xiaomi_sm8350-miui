#!/bin/sh
# SPDX-License-Identifier: GPL-2.0
# Dynamic kernel-only installer, using the AnyKernel3 recovery ZIP layout.
set -eu
set -o pipefail
OUTFD="$1"
WORK="$2"
cd "$WORK"
ui_print() { printf 'ui_print %s\nui_print\n' "$*" > "/proc/self/fd/$OUTFD"; }
abort() { ui_print "ERROR: $*"; exit 1; }
. ./tools/kernel-only.sh
ui_print 'Dynamic kernel: Xiaomi 11 Pro / Ultra only'
# Do not mount partitions or invoke the legacy AK3 ramdisk/vbmeta patchers.
if ps -A 2>/dev/null | grep -E '(^|[[:space:]])zygote(64)?([[:space:]]|$)' >/dev/null; then
    abort 'Install from recovery, not a running Android system'
fi
matched=0
for prop in ro.product.device ro.product.vendor.device ro.vendor.product.device ro.build.product; do
    device=$(getprop "$prop" 2>/dev/null || true)
    if is_supported_device "$device"; then matched=1; break; fi
done
[ "$matched" = 1 ] || abort 'Unsupported device: only mars / star are allowed'
locked=$(getprop ro.boot.flash.locked 2>/dev/null || true)
verified=$(getprop ro.boot.verifiedbootstate 2>/dev/null || true)
[ "$locked" = 0 ] || [ "$verified" = orange ] || abort 'Cannot confirm an unlocked bootloader'
slot=$(getprop ro.boot.slot_suffix 2>/dev/null || true)
if [ -z "$slot" ]; then slot="_$(getprop ro.boot.slot 2>/dev/null || true)"; fi
case "$slot" in _a|_b) ;; *) abort 'Cannot determine current slot';; esac
block="/dev/block/by-name/boot$slot"
[ -b "$block" ] || block="/dev/block/bootdevice/by-name/boot$slot"
[ -b "$block" ] || abort 'Active boot partition not found'
block=$(readlink -f "$block")
case "$block" in /dev/block/*) ;; *) abort 'Unexpected boot block path';; esac
sha256sum -c kernel.sha256 >/dev/null || abort 'Image checksum mismatch'
ui_print "Checking $device boot$slot; preserving every byte outside the kernel"
dd if="$block" of=boot-before.img bs=1048576 2>/dev/null || abort 'Boot backup failed'
prepare_kernel boot-before.img Image boot-expected.img || abort 'Boot layout check failed; nothing flashed'
# Check for a changed source partition before the only partition write.
before=$(sha256sum boot-before.img | cut -d ' ' -f1)
[ "$(sha256sum "$block" | cut -d ' ' -f1)" = "$before" ] || abort 'Boot changed during preparation'
ui_print "Writing only the kernel region of boot$slot"
dd if=Image of="$block" bs=4096 seek=1 conv=notrunc 2>/dev/null || abort "Kernel write failed; original backup: $WORK/boot-before.img"
sync
dd if="$block" of=boot-after.img bs=1048576 2>/dev/null || abort 'Read-back failed'
cmp -s boot-expected.img boot-after.img || abort "Verification failed; original backup: $WORK/boot-before.img"
ui_print 'Verified: kernel installed; ramdisk, header and all other bytes preserved'
ui_print 'No other partition was written. No slot change or automatic reboot.'
