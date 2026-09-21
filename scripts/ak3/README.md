# Dynamic kernel-only AK3 package

Author: Dynamic. Uses the AnyKernel3 recovery ZIP layout and the existing upstream BusyBox; upstream licenses remain in LICENSE.

- Recovery installation only; Xiaomi 11 Pro (`mars` / `M2102K1AC`) and Xiaomi 11 Ultra (`star` / `M2102K1G`).
- Requires an unlocked bootloader, an unambiguous current slot and boot header v3.
- **Requires the existing boot kernel payload length to exactly match the packaged uncompressed Image. A mismatch aborts before any partition write.** This deliberate restriction preserves the entire boot header and avoids moving the ramdisk or AVB metadata.
- Reads the current boot, constructs and checks an expected image in recovery RAM, writes only the kernel region at offset 4096, then compares a full read-back against the expected image.
- Never unpacks/recompresses ramdisk, changes cmdline/vbmeta/DTB/DTBO, installs modules, mounts system partitions, changes slots, or reboots.
- Preserves existing AVB metadata byte-for-byte; its old kernel digest is not regenerated. Unlocked bootloader required. This is not a signed image for a locked device.
- `boot-before.img` is a temporary recovery-RAM backup, not a persistent backup. On failure it stays in the reported `/tmp/dynamic-ak3.*` directory until reboot.
- The package builder includes only Image, its checksum, this installer, `tools/kernel-only.sh`, BusyBox and license/readme files. Legacy `ak3-core.sh` and ramdisk/patch/modules directories are not included.

The kernel is tested on mars with HyperOS 4 / Android 17. Star is whitelisted by device family but has not been tested on hardware for this release. Do not bypass a layout rejection.
