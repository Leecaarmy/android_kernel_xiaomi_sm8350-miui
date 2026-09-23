# Dynamic kernel-only AK3 package

Author: Dynamic. Uses the AnyKernel3 recovery ZIP layout and the existing upstream BusyBox; upstream licenses remain in LICENSE.

- Device admission is limited to Xiaomi 11 Pro (`mars` / `M2102K1AC`) and Xiaomi 11 Ultra (`star` / `M2102K1G`). This is the only installer admission check. Recovery, Horizon Kernel Flasher, Android, zygote state, Bootloader state, boot header, kernel length, Image format and checksum are not used to reject the install.
- The installer resolves the active boot slot and writes the packaged `Image` at the kernel offset of that boot partition. Slot resolution and the underlying `dd` result are required to perform the requested write; there is no additional layout or compatibility gate.
- Uses the standard AnyKernel3 working directory and the existing BusyBox. No partition is mounted and no POSTINSTALL app-data workspace is required.
- It does not unpack or patch ramdisk, cmdline, vbmeta, DTB/DTBO, modules or other partitions, and does not change slots or reboot. Kernel and boot-container compatibility is left to the caller's selected Image and device.
- The package builder includes only Image, its checksum file, this installer, `tools/kernel-only.sh`, BusyBox and license/readme files. Legacy `ak3-core.sh` and ramdisk/patch/modules directories are not included.
- The package builder includes only Image, its checksum, this installer, `tools/kernel-only.sh`, BusyBox and license/readme files. Legacy `ak3-core.sh` and ramdisk/patch/modules directories are not included.

The kernel is tested on mars with HyperOS 4 / Android 17. Star is whitelisted by device family but has not been tested on hardware for this release.
