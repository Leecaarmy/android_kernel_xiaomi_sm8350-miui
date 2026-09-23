#!/usr/bin/env python3
"""Package the committed Dynamic kernel without ROM-specific boot images."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import zipfile
from zoneinfo import ZoneInfo

src = Path(__file__).resolve().parents[2]
def git(*args):
    return subprocess.check_output(["git", "-C", str(src), *args], text=True).strip()
def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()
if git("status", "--porcelain", "--untracked-files=normal"):
    raise SystemExit("Commit release sources before packaging")
commit = git("rev-parse", "HEAD")
epoch = int(git("show", "-s", "--format=%ct", "HEAD"))
when = datetime.datetime.fromtimestamp(epoch, ZoneInfo("Asia/Shanghai"))
stamp = when.strftime("%Y%m%d-%H%M")
release = "5.4.302-Dynamic-g" + commit[:7]
out = Path(os.environ.get("OUT", str(src.parent / "out-dynamic-mars-a17")))
dest = Path(os.environ.get("RELEASE_DIR", str(src.parent / ("release-" + commit[:7]))))
dest.mkdir(parents=True, exist_ok=True)
assert (out / "include/config/kernel.release").read_text().strip() == release
build_manifest = (out / "dynamic-build-manifest.txt").read_text()
assert "source_commit=" + commit in build_manifest
assert sha(out / "arch/arm64/boot/Image") in build_manifest
image_data = (out / "arch/arm64/boot/Image").read_bytes()
assert ("Linux version " + release + " ").encode() in image_data
base = release + "-" + stamp
image = dest / ("Image-" + base)
config = dest / ("config-" + base)
ak3 = dest / ("Dynamic-AK3-" + base + ".zip")
shutil.copyfile(out / "arch/arm64/boot/Image", image)
shutil.copyfile(out / ".config", config)
entries = {
    "Image": (image_data, 0o644),
    "kernel.sha256": ((sha(image) + "  Image\n").encode(), 0o644),
}
for rel in ("anykernel.sh", "META-INF/com/google/android/update-binary",
            "tools/kernel-only.sh", "tools/busybox", "LICENSE", "README.md"):
    mode = 0o755 if rel.endswith(".sh") or rel.endswith("update-binary") or rel.endswith("busybox") else 0o644
    entries[rel] = ((src / "scripts/ak3" / rel).read_bytes(), mode)
with zipfile.ZipFile(ak3, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for name, (data, mode) in sorted(entries.items()):
        info = zipfile.ZipInfo(name, when.timetuple()[:6])
        info.create_system = 3
        info.external_attr = (0o100000 | mode) << 16
        info.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(info, data)
with zipfile.ZipFile(ak3) as z:
    assert z.testzip() is None
    assert set(z.namelist()) == set(entries)
    assert z.read("Image") == image_data
    assert not any(n.startswith(("ramdisk/", "patch/", "modules/")) for n in z.namelist())
    assert "tools/ak3-core.sh" not in z.namelist()
manifest = {
    "author": "Dynamic", "source_commit": commit,
    "branch": git("branch", "--show-current"), "kernel_release": release,
    "source_commit_time": when.isoformat(), "artifact_timestamp": stamp,
    "artifact_timezone": "Asia/Shanghai", "build_timestamp": git("show", "-s", "--format=%cD", "HEAD"),
    "build_user": "Dynamic", "build_host": "mars",
    "compiler": subprocess.check_output(["clang-17", "--version"], text=True).splitlines()[0],
    "linker": subprocess.check_output(["ld.lld-17", "--version"], text=True).strip(),
    "config": "vendor/mars_hyperos4_a17_defconfig + scripts/set-dynamic-version.sh",
    "kernel_payload_bytes": len(image_data),
    "installer": "Dynamic kernel-only AK3 layout; model admission only (mars/star); recovery or Horizon; no zygote/bootloader/layout/image/checksum admission gates; write packaged Image to active boot kernel offset",
    "allowed_devices": ["mars", "star", "M2102K1AC", "M2102K1G"],
    "files": {p.name: sha(p) for p in (image, config, ak3)},
}
manifest_file = dest / ("dynamic-build-manifest-" + stamp + ".json")
manifest_file.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
notes = (src / "Documentation/dynamic-a17-fixes-zh.md").read_text()
notes += "\n## 本次构建与校验\n\n"
notes += "- 源码提交：`" + commit + "`\n- 分支：`" + manifest["branch"] + "`\n"
notes += "- uname：`" + release + "`\n- 源码提交/构建时间戳：`" + when.isoformat() + "`\n"
notes += "- 工具链：" + manifest["compiler"] + "；" + manifest["linker"] + "\n"
notes += "- 配置：`" + manifest["config"] + "`\n- 内核载荷长度：" + str(len(image_data)) + " 字节\n"
notes += "- 构建署名：`Dynamic@mars`；版本计数：1。文件名时间取源码提交时间，时区 Asia/Shanghai。\n\n"
notes += "| 文件 | SHA-256 |\n| --- | --- |\n"
for p in (image, ak3, config, manifest_file):
    notes += "| `" + p.name + "` | `" + sha(p) + "` |\n"
notes_file = dest / ("ReleaseNotes-" + base + ".md")
notes_file.write_text(notes)
sums = dest / ("SHA256SUMS-" + stamp + ".txt")
sums.write_text("".join(sha(p) + "  " + p.name + "\n" for p in (image, ak3, config, manifest_file, notes_file)))
print(json.dumps({"release_dir": str(dest), "tag": "dynamic-kernel-g" + commit[:7],
                  "source_commit": commit, "kernel_release": release,
                  "stamp": stamp, "files": [p.name for p in (image, ak3, config, manifest_file, notes_file, sums)]}, indent=2))
