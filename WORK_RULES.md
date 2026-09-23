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

## 6. HoshinoNeko AK3 模板派生打包

- AK3 发布文件名固定为 `Dynamic-AK3-<内核版本>-Dynamic-g<内核源码提交前7位>-<YYYYMMDD-HHmm>.zip`，例如 `Dynamic-AK3-5.4.302-Dynamic-g14b97c7-20260921-2230.zip`；不得添加模板名称、`HoshinoNeko`、`template` 等额外字段。模板来源写入发布说明和构建清单。
- 本节是用户于 2026-09-22 确认的后续默认打包规则；目标兼容范围为小米 11 Pro / Ultra，安装器只保留机型准入检查，不增加 Recovery、Bootloader 或其他环境限制。实际操作手机分区仍须用户授权。
- 固定模板 SHA-256：`590627e556f15e49f243ab692bc07246242901aed21eacfb3cf8938b151263db`；未经用户要求不得更换模板版本。
- 用户指定使用 `HoshinoNeko_Star_Stable2_Any3Kernel.zip` 时，以该 ZIP 为唯一模板，保留其目录结构、脚本、工具、许可证、文件权限和其他条目。
- 模板派生包替换 ZIP 根目录的 `Image`，将 `anykernel.sh` 中的内核显示名称替换为 `Dynamic Kernel For SM8350`，并增加两款机型的准入列表（`mars` / `star` / `M2102K1AC` / `M2102K1G`）。为满足仅替换内核，`anykernel.sh` 使用 `split_boot/flash_boot` 保留 ramdisk cpio；设置 `patch_vbmeta_flag=0` 和 `slot_select=active`，避免修改 AVB 标志或在 OTA 环境自动选择其他槽位。
- 不得借模板派生过程顺带修改 `ramdisk/`、`patch/`、`modules/`、`tools/`、`update-binary`、`phantom-package.json` 或其他条目；构建元数据必须通过 Release 附件单独提供。
- 打包后必须检查 ZIP 完整性、`anykernel.sh` shell 语法、Image 存在且哈希正确，并逐条比较模板与成品：除 `Image` 和 `anykernel.sh` 外，其余条目内容必须完全一致；旧名称残留为零，新名称出现一次。
- 派生包文件名仍须按对应源码提交时间追加 `YYYYMMDD-HHmm`。Release 说明必须明确这是 HoshinoNeko AnyKernel3 模板派生包，并单独说明该模板运行时的 boot 解包/重打包行为；不得将静态“只替换两个 ZIP 条目”误写成运行时“只写入内核字节”。
