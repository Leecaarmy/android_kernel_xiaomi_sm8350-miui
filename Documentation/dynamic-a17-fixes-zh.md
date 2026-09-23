# Dynamic Kernel：ReKernel-X v1.6 与 Horizon 安装兼容

本次发布将 ReKernel-X 升级至官方 v1.6，补充 TCP 接收事件的 socket 查询，并允许 Horizon Kernel Flasher 在 Android 中执行 AK3 安装包。保留此前已验证的双击唤醒、触控、振动和 Edge 兼容修复。内核作者署名统一为 Dynamic，内核版本为 5.4.302。

## 本次更新

### ReKernel-X v1.6

上游为 `myflavor/ReKernel-X` 正式版 `1.6`，提交 `afb5e6bc62c6b9702c823009566a58b2e53b7797`，发布于 2026-09-20。集成其 LKM 内核源码，保留当前 Xiaomi 5.4 Binder hook 签名、头文件顺序和必要保护。异步清理前持有 Binder proc 临时引用，清理结束后释放；工作分配失败时保留原事务，避免在不合适的上下文同步清理。

### TCP 网络事件补查

旧实现仅使用 skb 已附带的 socket。早期 demux 未附加接收 socket 时会漏报；loopback 也可能保留发送者 socket。本次复用内核已有 IPv4/IPv6 Netfilter 查询函数定位接收 socket，通过完整 socket 的 sk_uid 获取 UID，并释放查询取得的引用。补充 TCP/IP 头部边界检查，避免将 TIME_WAIT/request socket 当作完整 socket 读取。

保留现有 rekernel_x2/events ABI、监控 UID 过滤和 TCP payload/SYN/FIN/RST 语义；不增加 UDP 唤醒或纯 ACK 唤醒，所有网络路径仍返回 NF_ACCEPT。

**本次不是“微信通知 bug 修复”。** 用户已确认微信此前没有在 NoActive 中启用网络解冻；NoActive 只为 packetUidSet 中的应用注册网络监控，并在网络事件回调中再次检查该配置。内核模拟测试与应用通知配置是不同问题，未修改 NoActive 设置，也不宣称所有应用通知均已验证。

### Horizon 安装入口

取消运行中 zygote/recovery 环境与 Bootloader 状态拦截，机型兼容准入仅限小米 11 Pro / Ultra。Horizon 通过 Android sh 调用 update-binary；当 /tmp 不存在或不可写时，使用 /dev 中独立临时目录，不挂载其他目录。按用户后续规则，AK3 安装器只做机型验证并把 Image 写入当前活动槽位的 boot 内核位置，不再增加 boot 布局、内核长度、Image 格式、校验和或其他状态拦截。

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

此前双击和 Edge 的实测提交为 db11dd64d5cb6813b7e228d80fe65bba6b2e6a7f。本次 ReKernel-X 候选 aa18893684d30718ac1e1732849987892c78810a 已编译并在手机临时启动，uname 为 5.4.302-Dynamic-gaa18893；最终发布整理仅修改安装脚本、测试、规范和文档，内核功能源码与该候选一致。最终重新编译产物与候选的实际运行版本需要区分。

- 本次候选：正常启动、ADB/Root、SELinux Enforcing、ZRAM lz4p 正常；Edge 原生 zygote 与沙箱创建成功，沙箱 Seccomp=2、NoNewPrivs=1、CapBnd=0。
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

## AK3 打包与安装限制

## 调度统计默认开关

保留 `CONFIG_SCHEDSTATS=y`，使 `/proc/schedstat` 和 `/proc/<pid>/schedstat` 在需要诊断时仍可用；运行时统计默认关闭。mars 和 star 的 ARM64 defconfig 内置 `schedstats=disable`，内核仍接受 `kernel.sched_schedstats=1` 或启动参数 `schedstats=enable` 进行临时分析。

该改动只调整调度统计的默认开关，不删除统计实现，也不改变调度策略。官方文档说明这些字段是持续累加的调度计数器，启用会在调度路径保留额外统计开销，详见 [Scheduler Statistics](https://docs.kernel.org/scheduler/sched-stats.html)。本机当前系统的 `/proc/sys/kernel/sched_schedstats` 曾由启动后的系统设置为 `1`；内核启动参数只能设定初始值，若 ROM 后续写入 `1`，仍需从系统启动配置移除该写入才能让运行时始终保持关闭。

发布包含 Image 和 Dynamic AK3 刷机包，另附配置、构建清单、说明和 SHA-256。文件名时间统一取源码提交时间，精确到分钟，Asia/Shanghai。此版本不提供基于特定 ROM 的完整 boot 镜像。

AK3 使用 AnyKernel3 recovery ZIP 布局及原有 BusyBox，采用 Dynamic 的最小安装入口，不运行旧版 AK3 的 ramdisk 解包/重打或 vbmeta 修补流程。第三方许可证和署名保留。

**允许 recovery 或 Horizon Kernel Flasher 执行，不再根据 zygote、Bootloader 状态、boot header、kernel_size、Image 格式或其他布局条件拦截。AK3 只验证上述 Pro / Ultra 机型，然后将包内 Image 写入当前活动槽位的 boot 内核位置。**

包内只含 Image、校验值、最小安装脚本、BusyBox 和许可证/说明；不含 ramdisk/、patch/、modules/、DTB/DTBO 或完整 boot。安装器不主动修改这些组件，但也不再以 boot 布局或长度条件拒绝用户指定的 Image。取消 Bootloader 状态检查只表示安装器不拦截该状态，不表示设备会绕过自身的启动验证。

只写当前槽位的 boot 内核区域，不挂载或修改其他分区、不切换槽位、不清数据、不自动重启。当前入口不创建 boot 备份，也不提供失败回滚；刷入前应由用户自行确保已有可用的恢复镜像。

本轮 AK3 安装逻辑通过本地模拟镜像和实际 boot 备份的离线验证。没有为了测试包而在手机上永久刷写，因此不宣称 recovery 永久安装已经实测。临时内核实测和安装器离线验证是不同证据。

Horizon 安装准入通过离线测试：模拟 zygote 存在、锁定状态属性，四个允许标识均可继续到槽位校验，其他机型仍拒绝。Horizon 的实际分区写入和刷后重启未实机验证，不能将入口兼容或本地镜像测试等同于已完成刷机验证。

另外在 mars 的 Android sh 中按 Horizon 参数 `update-binary 3 1 ZIP` 执行真实解包入口与包内 BusyBox，用无 Image、无分区操作的测试脚本替换安装主体：/tmp 路径通过；仅模拟 /tmp 不可用的测试副本也成功回退到 /dev。日志直接使用传入的文件描述符，避免重新打开 /proc/self/fd 在某些 Android 输出通道失败。测试临时目录已清理，boot_a 哈希仍与测试前一致。

## 构建与复现

在区分大小写的 Linux 文件系统检出发布标签，使用 Clang/LLVM 17 和 AArch64 GNU 工具链：

```sh
JOBS=10 bash scripts/build-dynamic-mars-a17.sh
python3 scripts/dynamic/test_kernel_only.py
bash scripts/package-dynamic-release.sh
```

发布脚本要求干净源码，并校验构建提交、uname 和 Image 哈希。构建作者为 Dynamic，主机字段 mars，版本计数 1；配置使用 vendor/mars_hyperos4_a17_defconfig 和提交版本脚本。具体提交、时间、工具链与产物 SHA-256 由打包脚本附在下面及随包构建清单中。
