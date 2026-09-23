# Dynamic Kernel：恢复标准 AK3 模板，仅验证机型

本次修正 AK3 打包器误用自定义安装器的问题，恢复用户指定的 HoshinoNeko AnyKernel3 模板。替换根目录 Image 和显示名称，启用小米 11 Pro / Ultra 的机型白名单，并使用模板已有的 kernel-only 接口以保留原 ramdisk。相对于 f5c6eb4，本次不修改内核功能源码或配置。

## 本次修正

- 删除固定 4096 字节偏移写入 Image 的错误安装器。该实现不能处理新旧内核长度变化，可能损坏 boot 结构或 ramdisk。g383a38e 和 gf5c6eb4 的 AK3 已撤回，不应使用。
- 恢复模板的 update-binary、ak3-core.sh、工具和标准 split_boot/flash_boot 流程（跳过 ramdisk 文件解包与 cpio 重建）。只允许 mars / star / M2102K1AC / M2102K1G；不加入 Recovery、Bootloader、Android 版本、安全补丁日期、新旧内核等长等准入条件。
- 允许 Recovery / Horizon 调用。模板仍会在无法读取目标、解包失败、重打包失败、产物大于分区或实际写入失败时报错；这些是执行失败处理，不能当成兼容黑名单删除。
- 标准 AK3 会读取并重封装目标 boot。ramdisk cpio 文件内容、元数据和启动参数保留；压缩表示、boot 大小字段和对齐位置可能随重打包变化，不能宣称非内核字节全部原封不动。
- 包内没有 ramdisk/、patch/、modules/、DTB、DTBO、vendor_boot 或其他分区载荷。Phantom 安装分支保留模板代码，但没有 patch/magisk.zip，因此不安装 Phantom 模块。phantom-package.json 是模板原始历史元数据，本次构建信息以外部 manifest 为准。
- 明确 slot_select=active，只选择当前槽位；patch_vbmeta_flag=0，不改嵌入的 AVB 标志。脚本不切换活动槽位、不自动重启。

## 本次验证与限制

发布前执行模板逐条比对、机型准入模拟、shell 语法、ZIP 完整性、Image/uname/提交/哈希一致性检查。离线镜像测试使用原 .26 boot 和不同大小 Image，通过原模板的 split_boot/flash_boot 处理临时文件；具体结果另附验证报告；不将历史设备测试当作本次新产物的实机测试。

本次没有刷写、重启或操作手机分区。Recovery/Horizon 的最终刷入与刷后启动未实机复测；小米 11 Ultra 仍无本次实机结果。

## 已有 ReKernel-X 功能

保留 ReKernel-X v1.6，来源 myflavor/ReKernel-X 提交 afb5e6bc62c6b9702c823009566a58b2e53b7797；保留当前 Xiaomi 5.4 Binder hook 签名和 Binder proc 临时引用保护。TCP 接收路径通过 IPv4/IPv6 Netfilter 查询定位接收 socket 并获取 sk_uid，保持 UID 过滤、TCP payload/SYN/FIN/RST 语义及 NF_ACCEPT。

微信未通知此前已确认与 NoActive 未配置网络解冻有关，不能宣称本次修复了微信通知。此次不修改应用配置。

## 保留的修复

### 息屏双击唤醒

实际触控驱动为 fts_spi。设备树未提供旧逻辑依赖的 panel 属性，导致无法注册显示通知。改用 Xiaomi 主屏幕显示通知，在 POWERDOWN、AOD LP1/LP2 时挂起触控，在 ON 时恢复。只响应主屏幕，保留原有用户手势开关和 IRQ wake 处理。

### Edge / Android 17 capability ABI

系统原生 zygote_next 查询 capability 40 时，旧内核因 CAP_LAST_CAP=39 返回 EINVAL，系统 Rust 代码在 child_process.rs:86:43 panic，阻断 Edge 网页沙箱创建。仅在 capability UAPI 和 SELinux 名称映射两个头文件中补上标准 CAP_CHECKPOINT_RESTORE=40。

这是一项最小 ABI 兼容，原有 CAP_SYS_ADMIN 操作权限检查保持不变，不是完整的检查点恢复特权拆分。没有关闭 SELinux/seccomp，也没有放行未知 capability 编号。

## 已有功能与兼容实现

- 保留原稳定版设备基础、schedutil/WALT 调度和 hrtimer CPU 热插拔初始化修复。
- 保留 Android 17 所需 BPF 兼容实现、Tasks Trace RCU 及 netbpfload 专用版本兼容路径；普通 uname 仍显示真实 5.4.302-Dynamic-g提交前7位。不是整体升级为 5.10。
- 保留 ReSukiSU v4.2.0-rc2 内核驱动（35149）、SUSFS v2.3.0；ReKernel-X 更新为 v1.6。管理器 APK 是独立组件，不随内核包安装。
- 保留 AW8697 振动接口、RAM 固件延迟加载、波形序列清理及既有增益控制；固件自动用户空间 fallback 保持关闭。
- 保留 ZRAM lz4p、F2FS/EROFS、seccomp/filter、BPF syscall/JIT。已有源码不等于本次逐项完成所有功能测试。

## 实机测试与适配范围

此前双击和 Edge 的实测提交为 db11dd64d5cb6813b7e228d80fe65bba6b2e6a7f。此前 ReKernel-X 候选 aa18893684d30718ac1e1732849987892c78810a 已编译并在手机临时启动，uname 为 5.4.302-Dynamic-gaa18893；最终发布整理仅修改安装脚本、测试、规范和文档，内核功能源码与该候选一致。最终重新编译产物与候选的实际运行版本需要区分。

- 此前 ReKernel-X 候选：正常启动、ADB/Root、SELinux Enforcing、ZRAM lz4p 正常；Edge 原生 zygote 与沙箱创建成功，沙箱 Seccomp=2、NoNewPrivs=1、CapBnd=0。
- 使用独立 UID 19999 的固定 16 字节 TCP 载荷对照：旧内核 IPv4/IPv6 均收到数据但网络事件为 0；候选各收到 3 个事件，其中包含 bytes=16。未监控 UID 的 IPv4/IPv6 均没有网络事件。
- Binder Netlink 事件可接收；测试监控 UID 已删除，手机 /dev 临时探针已清理。boot_a 在临时启动前后哈希相同，未永久刷写。
- 本次没有完成 Binder 异步清理并发压力测试、所有网络路径及真实应用通知端到端验证。双击、触控、振动的源码未改，下面的用户人工确认和详细 capability 测试属于先前实测基线，并非本次全部重测。

- 实测机型：小米 11 Pro，mars / M2102K1AC。
- 实测系统：用户记录的 HyperOS OS4.0.0.26.XKACNXM.D00 / Android 17；系统属性为 17OS4.0.260902.062800686.QCPECN.S。
- 系统正常启动；用户确认 Edge 已进入且网页能正常打开，双击、普通触控、振动正常。
- 捕获触控 suspend_state 0→1→0 和真实 KEY_WAKEUP 事件；振动服务测试完成。
- capability 40 查询/丢弃通过；41/63 无效编号仍被拒绝；无特权进程操作被拒绝；旧权限位和父进程状态不变。
- Edge 原生 Zygote 与网页沙箱创建成功，Seccomp=2、NoNewPrivs=1、CapBnd=0。
- Wi-Fi、联网、ZRAM、F2FS/EROFS、SELinux Enforcing、Root/Zygisk 状态检查通过。采样 crash buffer 和内核异常检查未发现新增崩溃。
- 小米 11 Ultra（star / M2102K1G）仅列入同系列安装白名单，本次未实机验证。小米 11（venus）及其他机型不允许安装。
- 指纹未测试；摄像、蓝牙音频、通话、游戏负载及长期待机/耗电没有专项回归。不能宣称所有场景绝无潜在 bug。


## 调度统计与兼容范围

保留 CONFIG_SCHEDSTATS=y 及此前配置中的 schedstats=disable。启动参数只影响初始统计状态；ROM 后续仍可能写入 kernel.sched_schedstats=1。本次没有证明当前 ROM 能始终保持运行时统计关闭，也没有测得功耗或性能收益。

适配基线为小米 11 Pro（mars）HyperOS OS4.0.0.26.XKACNXM.D00 / Android 17。小米 11 Ultra（star）列入机型白名单但未实机验证；允许安装并不等于承诺适配所有 Android/ROM 版本。

## 构建与复现

在区分大小写的 Linux 文件系统检出对应发布提交，使用 Clang/LLVM 17 和 AArch64 GNU 工具链：

```sh
JOBS=10 bash scripts/build-dynamic-mars-a17.sh
AK3_TEMPLATE=/path/to/HoshinoNeko_Star_Stable2_Any3Kernel.zip python3 scripts/dynamic/test_kernel_only.py
python3 scripts/dynamic/test_ak3_offline.py --source "$PWD" --qemu /path/to/qemu-arm --boot /path/to/original-boot.img --image "$OUT/arch/arm64/boot/Image" --report /path/to/verification.json
AK3_TEMPLATE=/path/to/HoshinoNeko_Star_Stable2_Any3Kernel.zip AK3_VALIDATION_REPORT=/path/to/verification.json bash scripts/package-dynamic-release.sh
```

模板 SHA-256 固定为 590627e556f15e49f243ab692bc07246242901aed21eacfb3cf8938b151263db。发布包含 Image、AK3、配置、构建清单、说明及 SHA-256。文件名时间取源码提交时间（Asia/Shanghai，精确到分钟）；构建作者 Dynamic，主机 mars。具体版本和哈希见下方构建信息。
