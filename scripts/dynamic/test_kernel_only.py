#!/usr/bin/env python3
"""Exercise actual shell prepare/guard logic against disposable boot fixtures."""
import hashlib
from pathlib import Path
import struct
import subprocess
import tempfile
src = Path(__file__).resolve().parents[2]
core = src / "scripts/ak3/tools/kernel-only.sh"
def run(original, kernel, output):
    return subprocess.run(["bash", "-c", 'set -e; . "$1"; prepare_kernel "$2" "$3" "$4"',
                           "test", str(core), str(original), str(kernel), str(output)], capture_output=True)
with tempfile.TemporaryDirectory(prefix="dynamic-ak3-test-") as tmp:
    root = Path(tmp)
    kernel = bytearray(b"K" * 8192)
    kernel[56:60] = b"ARM\x64"
    header = bytearray(b"H" * 4096)
    header[:8] = b"ANDROID!"
    for offset, value in ((8, len(kernel)), (12, 3000), (20, 1580), (40, 3)):
        struct.pack_into("<I", header, offset, value)
    original = bytes(header) + b"O" * 8192 + b"R" * 4096 + b"AVB-and-tail-preserved" * 128
    boot, image, result = root / "boot", root / "Image", root / "result"
    boot.write_bytes(original); image.write_bytes(kernel)
    assert run(boot, image, result).returncode == 0
    expected = original[:4096] + bytes(kernel) + original[12288:]
    assert result.read_bytes() == expected
    assert boot.read_bytes() == original
    print("PASS: exact replacement; header, ramdisk, tail and original file preserved")
    for label, offset, value in (("wrong version", 40, 4), ("wrong header size", 20, 1600),
                                  ("kernel length mismatch", 8, 12288), ("truncated ramdisk", 12, 999999)):
        bad = bytearray(original); struct.pack_into("<I", bad, offset, value)
        boot.write_bytes(bad); result.unlink(missing_ok=True)
        assert run(boot, image, result).returncode != 0
        assert not result.exists() and boot.read_bytes() == bad
        print("PASS: rejected " + label + " before output creation")
    for label, bad in (("bad boot magic", b"BADMAGIC" + original[8:]), ("short header", b"ANDROID!")):
        boot.write_bytes(bad); assert run(boot, image, result).returncode != 0
        assert not result.exists()
        print("PASS: rejected " + label)
    boot.write_bytes(original); image.write_bytes(b"N" * len(kernel))
    assert run(boot, image, result).returncode != 0 and not result.exists()
    print("PASS: rejected non-ARM64 Image")
for device in ("mars", "star", "M2102K1AC", "M2102K1G", "venus", "alioth", "", "mars-extra"):
    r = subprocess.run(["bash", "-c", '. "$1"; is_supported_device "$2"', "test", str(core), device])
    assert (r.returncode == 0) == (device in ("mars", "star", "M2102K1AC", "M2102K1G"))
print("PASS: device whitelist admits only specified identifiers")
# Real saved-device image: exercise the identical preparation logic when supplied.
import sys
if len(sys.argv) == 3:
    with tempfile.TemporaryDirectory(prefix="dynamic-ak3-real-") as tmp:
        output = Path(tmp) / "boot-expected.img"
        original, kernel = map(Path, sys.argv[1:])
        r = run(original, kernel, output)
        assert r.returncode == 0, r.stderr.decode()
        old, new, k = original.read_bytes(), output.read_bytes(), kernel.read_bytes()
        assert new == old[:4096] + k + old[4096+len(k):]
        print("PASS: saved real boot image; output SHA256=" + hashlib.sha256(new).hexdigest())
