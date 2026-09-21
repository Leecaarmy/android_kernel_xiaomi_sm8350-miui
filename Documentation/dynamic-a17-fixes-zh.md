# Dynamic Kernel：Android 17 双击唤醒与 Edge 兼容修复

本次发布修复小米 11 Pro 在当前 HyperOS 4 Android 17 上的两个问题：息屏双击不能亮屏，以及 Edge 全新安装后卡在引导 Logo 页。内核作者署名统一为 Dynamic，内核版本保留 5.4.302。

## 新修复

### 息屏双击唤醒

实际触控驱动为 fts_spi。设备树未提供旧逻辑依赖的 panel 属性，导致无法注册显示通知。改用 Xiaomi 主屏幕显示通知，在 POWERDOWN、AOD LP1/LP2 时挂起触控，在 ON 时恢复。只响应主屏幕，保留原有用户手势开关和 IRQ wake 处理。

### Edge / Android 17 capability ABI

系统原生 zygote_next 查询 capability 40 时，旧内核因 CAP_LAST_CAP=39 返回 EINVAL，系统 Rust 代码在 child_process.rs:86:43 panic，阻断 Edge 网页沙箱创建。仅在 capability UAPI 和 SELinux 名称映射两个头文件中补上标准 CAP_CHECKPOINT_RESTORE=40。

这是一项最小 ABI 兼容，原有 CAP_SYS_ADMIN 操作权限检查保持不变，不是完整的检查点恢复特权拆分。没有关闭 SELinux/seccomp，也没有放行未知 capability 编号。

## 已有功能与兼容实现

- 保留原稳定版设备基础、schedutil/WALT 调度和 hrtimer CPU 热插拔初始化修复。
- 保留 Android 17 所需 BPF 兼容实现、Tasks Trace RCU 及 netbpfload 专用版本兼容路径；普通 uname 仍显示真实 5.4.302-Dynamic-g提交前7位。不是整体升级为 5.10。
- 保留 ReSukiSU v4.2.0-rc2 内核驱动（35149）、SUSFS v2.3.0、ReKernel-X v1.5。管理器 APK 是独立组件，不随内核包安装。
- 保留 AW8697 振动接口、RAM 固件延迟加载、波形序列清理及既有增益控制；固件自动用户空间 fallback 保持关闭。
- 保留 ZRAM lz4p、F2FS/EROFS、seccomp/filter、BPF syscall/JIT。已有源码不等于本次逐项完成所有功能测试。

## 实机测试与适配范围

功能修复源码基线为 db11dd64d5cb6813b7e228d80fe65bba6b2e6a7f，本次发布整理仅修改打包、规范和说明文件，内核功能实现与该实测提交相同。

- 实测机型：小米 11 Pro，mars / M2102K1AC。
- 实测系统：用户记录的 HyperOS OS4.0.0.26.XKACNXM.D00 / Android 17；系统属性为 17OS4.0.260902.062800686.QCPECN.S。
- 系统正常启动；用户确认 Edge 已进入且网页能正常打开，双击、普通触控、振动正常。
- 捕获触控 suspend_state 0→1→0 和真实 KEY_WAKEUP 事件；振动服务测试完成。
- capability 40 查询/丢弃通过；41/63 无效编号仍被拒绝；无特权进程操作被拒绝；旧权限位和父进程状态不变。
- Edge 原生 Zygote 与网页沙箱创建成功，Seccomp=2、NoNewPrivs=1、CapBnd=0。
- Wi-Fi、联网、ZRAM、F2FS/EROFS、SELinux Enforcing、Root/Zygisk 状态检查通过。采样 crash buffer 和内核异常检查未发现新增崩溃。
- 小米 11 Ultra（star / M2102K1G）仅列入同系列安装白名单，本次未实机验证。小米 11（venus）及其他机型不允许安装。
- 指纹未测试；摄像、蓝牙音频、通话、游戏负载及长期待机/耗电没有专项回归。不能宣称所有场景绝无潜在 bug。

## AK3 打包与安装限制

发布包含 Image 和 Dynamic AK3 刷机包，另附配置、构建清单、说明和 SHA-256。文件名时间统一取源码提交时间，精确到分钟，Asia/Shanghai。此版本不提供基于特定 ROM 的完整 boot 镜像。

AK3 使用 AnyKernel3 recovery ZIP 布局及原有 BusyBox，采用 Dynamic 的最小安装入口，不运行旧版 AK3 的 ramdisk 解包/重打或 vbmeta 修补流程。第三方许可证和署名保留。

**必须在 recovery 安装，Bootloader 已解锁，当前槽位可确定，boot header 为 v3，且原 boot 的 kernel_size 必须与包内 Image 的字节长度完全一致。任何条件不符，写入前退出。不要绕过该检查。**

包内只含 Image、校验值、最小安装脚本、BusyBox 和许可证/说明；不含 ramdisk/、patch/、modules/、DTB/DTBO 或完整 boot。读取当前 boot 后，在 recovery 内存中构造预期镜像并确认所有非内核字节不变；实际仅从偏移 4096 写入内核长度的字节，之后完整读回比对。保留 ramdisk、cmdline、完整启动头和尾部，包括原 AVB 元数据；原 AVB 摘要不会重新签名，因此必须使用已解锁设备。

只写当前槽位的 boot 内核区域，不挂载或修改其他分区、不切换槽位、不清数据、不自动重启。失败时原始 boot 临时备份保留在报告的 /tmp/dynamic-ak3.* 路径，重启后消失；不能把它视为持久备份。

本轮 AK3 安装逻辑通过本地模拟镜像和实际 boot 备份的离线验证。没有为了测试包而在手机上永久刷写，因此不宣称 recovery 永久安装已经实测。临时内核实测和安装器离线验证是不同证据。

## 构建与复现

在区分大小写的 Linux 文件系统检出发布标签，使用 Clang/LLVM 17 和 AArch64 GNU 工具链：

```sh
JOBS=10 bash scripts/build-dynamic-mars-a17.sh
python3 scripts/dynamic/test_kernel_only.py
bash scripts/package-dynamic-release.sh
```

发布脚本要求干净源码，并校验构建提交、uname 和 Image 哈希。构建作者为 Dynamic，主机字段 mars，版本计数 1；配置使用 vendor/mars_hyperos4_a17_defconfig 和提交版本脚本。具体提交、时间、工具链与产物 SHA-256 由打包脚本附在下面及随包构建清单中。
