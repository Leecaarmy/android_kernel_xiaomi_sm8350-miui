# 后续规范操作规则

## 1. 修改范围

- 只允许修改内核源码。
- 严禁对其他任何分区执行修改、写入、擦除、格式化或切换操作。
- 严禁修改或注入 `ramdisk/`、`patch/`、`modules/` 及其对应的启动镜像内容。
- 未经用户明确授权，不得操作 `boot`、`boot_a`、`boot_b`、`vendor_boot`、`dtbo`、`vbmeta`、`vendor_dlkm`、`system_dlkm`、`super`、`userdata` 或其他设备分区。

## 2. 执行约束

- 后续涉及源码、编译、打包或刷机的操作，必须先检查是否会触及上述禁止范围。
- 若工具或刷机包会自动修改 ramdisk、启动配置、模块或其他分区，应停止并说明，不得继续执行。
- 任何超出本规则范围的操作，都必须先取得用户明确授权。

## 3. 内核 `uname` 命名

- 内核 `uname -r` 必须遵守安卓内核版本命名规则，格式固定为：`内核版本-作者署名-g提交前7位`。
- 示例：`5.4.302-Dynamic-g573058b`。
- `内核版本`必须来自内核源码的实际版本信息，`作者署名`使用发布时指定的作者名称，提交短哈希取对应源码提交 ID 的前 7 位，并保留 `g` 前缀。
- 编译、发布和验证时必须检查实际 `uname -r` 是否与该格式一致；不一致时停止发布或刷写流程。

## 4. 源码提交与 Release

- 提交源码时，必须同步上传对应的 GitHub Release。
- 上传至 GitHub Releases 的文件，必须在文件名末尾（扩展名前）附加对应源码提交的日期与时间，精确到分钟，格式为 `YYYYMMDD-HHmm`；时间取对应源码提交时间。
- Release 必须包含 Image 内核镜像和 AK3 内核刷机包。
- AK3 刷机包的设备检查必须限制为小米 11 Pro（`mars` / `M2102K1AC`）和小米 11 Ultra（`star` / `M2102K1G`，以源码及设备树实际标识为准）两款机型；不得无条件放宽到其他机型。
- AK3 刷入准入只验证小米 11 Pro / Ultra 机型（`mars` / `star` / `M2102K1AC` / `M2102K1G`）。允许 Horizon Kernel Flasher 或 recovery 执行；不得增加 Recovery、Bootloader、系统版本、内核长度或其他环境拦截。安装器使用模板已有的 `split_boot/flash_boot` 进行 boot 解包/重打包，只替换 kernel payload；不调用会重建 ramdisk 的 `dump_boot/write_boot`，不注入或修改 ramdisk 文件及启动配置。保留读取/解包/写入失败和分区容量不足时的正常错误处理，这些不属于人为兼容准入限制。
- Release 必须详细记录内核构建信息，包括源码提交、分支、编译时间、工具链、配置、`uname -r`、产物哈希和打包方式。
- Release 必须记录当前版本新增的功能、修复的 bug、已有功能或兼容实现，以及适配的系统版本和机型。
- 发布前必须核对源码提交、Image、AK3 包和 Release 说明之间的版本、提交短哈希和哈希值一致。

## 5. 最小范围修复与回归验证

- 每次兼容修复或 bug 修复必须以已确认的根因为依据，仅修改解决问题所必需的内核源码；禁止混入无关重构、调优或功能变更。
- 修复必须保留已经实现的兼容能力和已有 bug 修复，尤其不得回退已验证的触控、双击唤醒、振动及系统启动兼容行为。
- 修复完成后必须编译验证，并在授权范围内进行实机测试，确认原问题确实解决，同时对相关功能及已有关键修复执行回归测试。
- 测试必须记录基线、源码提交、实际运行版本、验证项目、结果及异常；不能仅凭编译成功或一次正常启动宣布修复完成。
- 若发现新异常或回归，应停止发布和永久刷入，定位并处理；必要时恢复已验证状态，恢复操作仍受用户授权范围约束。
- 必须如实区分已通过、未通过和未测试项目；无法凭有限测试保证不存在任何潜在 bug，不得作未经验证的“绝无新 bug”承诺。

## 6. AK3 固定模板与“仅替换内核”规则

- 本节是 AK3 打包的强制规则。后续所有版本必须使用用户已确认的 `HoshinoNeko_Star_Stable2_Any3Kernel.zip`，模板 SHA-256 固定为 `590627e556f15e49f243ab692bc07246242901aed21eacfb3cf8938b151263db`。未经用户明确指定并重新确认，不得更换模板、模板版本或安装器实现。
- AK3 的功能范围只有两项：验证机型是否为小米 11 Pro / Ultra，以及把包内 Image 替换到目标 boot 的 kernel payload。机型白名单固定为 `mars`、`M2102K1AC`、`star`、`M2102K1G`。除机型外不得增加任何准入拦截。
- 明确禁止检查或拦截：Recovery / Horizon / Android 系统环境、zygote、Bootloader 锁定状态、Verified Boot 状态、系统版本、安全补丁日期、当前内核版本、旧内核大小、Image 大小、Image 格式、文件哈希、Root / KernelSU / Magisk / APatch 状态，以及任何未由用户要求的属性。读取、解包、重打包、分区容量不足和实际写入失败属于执行错误处理，不得伪装成兼容性黑名单。
- 允许 Horizon Kernel Flasher、Recovery 及其他能够正确调用 AnyKernel3 `update-binary` 的环境执行。安装器不因执行环境而拒绝受支持机型；不自动重启、不清数据、不修改活动槽位选择。
- 必须使用模板已有的 `split_boot` + `flash_boot` kernel-only 流程：读取现有 boot，保留原 kernel 以外的 header 参数、ramdisk cpio、启动配置、DTB/DTBO 和其他组件，再写入新的 kernel 并重封装 boot。不得调用会解包、重建或注入 ramdisk 的 `dump_boot` + `write_boot`。
- 必须设置 `patch_vbmeta_flag=0`，禁止通过 AK3 自动修改 AVB / vbmeta 标志；必须设置 `slot_select=active`，目标为当前活动槽位，不得在 OTA/postinstall 环境自动改写为 inactive 槽位。
- 禁止固定偏移或未经解析的原始写入实现，包括但不限于 `dd if=Image ... seek=1`、`cat Image > block`、把 Image 直接覆盖 block 的前若干字节，以及任何不读取 boot header、不按 kernel offset 重封装的自定义 writer。禁止恢复或新增 `tools/kernel-only.sh` 一类绕过模板 core 的精简安装器。
- AK3 派生包只允许修改：ZIP 根目录 `Image`；`anykernel.sh` 的显示名称 `Dynamic Kernel For SM8350`；上述四个机型白名单；为 kernel-only 行为明确需要的 `split_boot` / `flash_boot`、`patch_vbmeta_flag=0` 和 `slot_select=active` 设置。`tools/`、`update-binary`、`phantom-package.json`、许可证、权限、目录结构及其他条目必须逐字节保持模板一致。
- 包内不得新增或携带 `ramdisk/`、`patch/`、`modules/`、DTB、DTBO、vendor_boot、vendor_dlkm、system_dlkm、vbmeta、完整 boot 或任何其他分区载荷。模板中原有的 Phantom 代码和元数据不得被扩展；没有用户明确要求时不得添加 Phantom / Magisk / KernelSU 模块。
- AK3 文件名固定为 `Dynamic-AK3-<内核版本>-Dynamic-g<内核源码提交前7位>-<YYYYMMDD-HHmm>.zip`，不得加入 `HoshinoNeko`、`template` 或其他字段。时间取源码提交时间（Asia/Shanghai，精确到分钟）。

## 7. AK3 发布前强制阻断检查

- 打包前必须确认源码工作树、源码提交、Image、AK3 和说明使用同一个提交短哈希；`uname -r` 必须与该提交一致；模板 SHA-256 必须匹配固定值。
- 必须对模板和成品逐条比较 ZIP 条目、条目顺序、权限、时间戳、压缩属性和所有非授权条目内容。除本节明确列出的 `Image` 与 `anykernel.sh` 改动外，出现任何差异都必须停止发布。
- 必须执行 `anykernel.sh`、`update-binary` 和 `tools/ak3-core.sh` 的 shell 语法检查；必须扫描并拒绝固定偏移写入、直接 block 覆盖、Recovery / Bootloader / 系统版本拦截及 ramdisk 重建路径。
- 必须使用原始目标 boot 的离线副本和至少三种不同 kernel 长度（当前 Image、跨页增大、缩小）执行安装器测试。验证结果必须证明：kernel payload 被替换；ramdisk cpio 字节流、文件内容、权限、属主、时间、启动参数和未授权组件保持一致；原始输入文件未被修改；失败场景不会产生部分输出。
- 必须记录离线验证使用的 boot 哈希、Image 哈希、模板哈希、AK3 core / anykernel 哈希、ramdisk 条目数量、测试载荷长度及结果，并将验证报告随 Release 上传。没有该报告时不得发布或推荐刷入。
- Release 必须包含 Image、AK3、配置、构建清单、Release 说明、SHA-256 清单和 AK3 验证报告。远端上传后必须逐个核对文件名、大小、SHA-256、Release 标签提交和 Release 说明；任一不一致都必须撤回草稿，不得标记 Latest。
- 任何验证失败、脚本改动超出白名单、模板条目出现差异、或发现安装器可能修改 ramdisk / 启动配置时，立即停止发布并说明原因；不得用“已编译成功”替代安装器验证。
- 旧版包一旦发现使用固定偏移 writer、缺少 boot 解析或未经验证，必须标记为撤回/作废并明确告知用户，后续不得继续推荐或刷入。
