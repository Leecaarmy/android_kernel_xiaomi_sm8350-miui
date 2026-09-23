#!/bin/sh
# SPDX-License-Identifier: GPL-2.0
# Dynamic kernel-only installer, using the AnyKernel3 recovery ZIP layout.
set -eu
set -o pipefail
OUTFD="$1"
WORK="$2"
cd "$WORK"
ui_print() { printf 'ui_print %s\nui_print\n' "$*" >&"$OUTFD"; }
abort() { ui_print "ERROR: $*"; exit 1; }
. ./tools/kernel-only.sh
ui_print 'Dynamic kernel: Xiaomi 11 Pro / Ultra only'
# The only admission policy is the Xiaomi 11 Pro / Ultra device check.
matched=0
for prop in ro.product.device ro.product.vendor.device ro.vendor.product.device ro.build.product; do
    device=$(getprop "$prop" 2>/dev/null || true)
    if is_supported_device "$device"; then matched=1; break; fi
done
[ "$matched" = 1 ] || abort 'Unsupported device: only mars / star are allowed'
slot=$(getprop ro.boot.slot_suffix 2>/dev/null || true)
if [ -z "$slot" ]; then slot="_$(getprop ro.boot.slot 2>/dev/null || true)"; fi
block="/dev/block/by-name/boot$slot"
[ -e "$block" ] || block="/dev/block/bootdevice/by-name/boot$slot"
ui_print "Writing Image to boot$slot"
dd if=Image of="$block" bs=4096 seek=1 conv=notrunc 2>/dev/null || abort 'Kernel write failed'
sync
ui_print 'Kernel write completed. No slot change or automatic reboot.'
