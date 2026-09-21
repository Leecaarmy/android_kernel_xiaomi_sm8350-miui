#!/bin/sh
# SPDX-License-Identifier: GPL-2.0
# Dynamic: boot-v3 kernel-region replacement without ramdisk repacking.
fail() { echo "ERROR: $*" >&2; return 1; }
is_supported_device() {
    case "$1" in mars|star|M2102K1AC|M2102K1G) return 0;; *) return 1;; esac
}
file_size() { stat -c %s "$1"; }
header_u32() { od -An -tu4 -j "$2" -N4 "$1" | tr -d ' \n'; }
header_hex() { od -An -tx1 -j "$2" -N "$3" "$1" | tr -d ' \n'; }
prepare_kernel() {
    local original="$1" kernel="$2" output="$3" size old_size rd_size rd_end after
    [ "$original" != "$output" ] || { fail "Input and output must differ"; return 1; }
    size=$(file_size "$original") || return 1
    [ "$size" -ge 4096 ] || { fail "Truncated boot header"; return 1; }
    [ "$(header_hex "$original" 0 8)" = 414e44524f494421 ] || { fail "Not an Android boot image"; return 1; }
    [ "$(header_u32 "$original" 40)" = 3 ] || { fail "Only boot header v3 is supported"; return 1; }
    [ "$(header_u32 "$original" 20)" = 1580 ] || { fail "Unexpected boot-v3 header size"; return 1; }
    old_size=$(header_u32 "$original" 8)
    [ "$old_size" -ge 64 ] || { fail "Invalid kernel length"; return 1; }
    [ "$(file_size "$kernel")" = "$old_size" ] || { fail "Kernel length differs; refusing to move ramdisk or modify boot header"; return 1; }
    [ "$(header_hex "$kernel" 56 4)" = 41524d64 ] || { fail "Expected an uncompressed ARM64 Image"; return 1; }
    rd_size=$(header_u32 "$original" 12)
    rd_end=$((4096 + (old_size + 4095) / 4096 * 4096 + (rd_size + 4095) / 4096 * 4096))
    [ "$rd_end" -le "$size" ] || { fail "Truncated boot payload"; return 1; }
    cp "$original" "$output" || return 1
    dd if="$kernel" of="$output" bs=4096 seek=1 conv=notrunc 2>/dev/null || return 1
    [ "$(file_size "$output")" = "$size" ] || return 1
    [ "$(dd if="$original" bs=4096 count=1 2>/dev/null | sha256sum)" = "$(dd if="$output" bs=4096 count=1 2>/dev/null | sha256sum)" ] || { fail "Boot header changed"; return 1; }
    after=$((4096 + old_size + 1))
    [ "$(tail -c +"$after" "$original" | sha256sum)" = "$(tail -c +"$after" "$output" | sha256sum)" ] || { fail "Non-kernel bytes changed"; return 1; }
}
