# Dynamic kernel-only AK3 package

Author: Dynamic. Uses the AnyKernel3 recovery ZIP layout and the existing upstream BusyBox; upstream licenses remain in LICENSE.

- Device admission is limited to Xiaomi 11 Pro (`mars` / `M2102K1AC`) and Xiaomi 11 Ultra (`star` / `M2102K1G`). Recovery and Android-based installers such as Horizon Kernel Flasher are permitted; no zygote or bootloader-state gate is applied.
- Requires an unambiguous current slot and boot header v3. These are write-target and layout checks, not device admission checks.
- **Requires the existing boot kernel payload length to exactly match the packaged uncompressed Image. A mismatch aborts before any partition write.** This deliberate restriction preserves the entire boot header and avoids moving the ramdisk or AVB metadata.
- Uses a writable /tmp workspace, or /dev when Android/Horizon does not provide /tmp. No directory is mounted and no POSTINSTALL app-data workspace is required. Reads the current boot, constructs and checks an expected image, writes only the kernel region at offset 4096, then compares a full read-back against the expected image.
- Never unpacks/recompresses ramdisk, changes cmdline/vbmeta/DTB/DTBO, installs modules, mounts system partitions, changes slots, or reboots.
- Preserves existing AVB metadata byte-for-byte; its old kernel digest is not regenerated. Removing the bootloader-state gate does not make this a signed image for a locked device.
- `boot-before.img` is a temporary installer backup, not a persistent backup. On failure it stays in the reported `/tmp/dynamic-ak3.*` or `/dev/dynamic-ak3.*` directory until the installer cleans it or the device reboots.
- The package builder includes only Image, its checksum, this installer, `tools/kernel-only.sh`, BusyBox and license/readme files. Legacy `ak3-core.sh` and ramdisk/patch/modules directories are not included.

The kernel is tested on mars with HyperOS 4 / Android 17. Star is whitelisted by device family but has not been tested on hardware for this release. Do not bypass a layout rejection.
