# 失败的 KPM 实验

这里只保留 PAR 的 KPM 实验配置和源码补丁，供以后研究。相关版本不能稳定工作，
不属于正式方案，也不要直接用于刷机。

## HHEE 方向的当前判断

Kirin 970 的 HHEE/HKIP 位于 EL2。现有 KernelPatch 在重定位后会直接清除
`SCTLR_EL1.WXN`，并创建新的可执行页；这绕过了华为内核给模块和 livepatch 预留的
HHEE 授权流程，符合“进入 KernelPatch/KPM 后立即关机”的现象。当前把它作为首要
假设。真机逐级控制实验已证明，专用 trampoline、`mem_proc()`、恢复
`paging_init()` 首指令、执行原 `paging_init()`、其后的 VERSION/TOKEN HVC，以及
为 KPM 新区域创建 `RW+NX` 页表映射都可正常启动。相同 HVC 放在 `paging_init()`
之前则会在无 Linux 输出时硬锁死。因此已排除“CPU/HHEE 禁止普通内核代码写入”
以及“创建新页表映射本身就会关机”；已确认的第一个直接触发点是过早调用 HVC。
但完成代码复制、改为 `RO+X`、调用 `HHEE_LKM_UPDATE` 并进入搬运后代码的组合路径
仍会硬锁，最终未继续拆分。

华为 4.9 内核中已有三条相关 HVC：

- `HHEE_HVC_TOKEN` (`0xC6001089`)：取得本次启动的授权 token；
- `HHEE_LKM_UPDATE` (`0xC6001082`)：授权一段已经完成写入且只读的模块代码；
- `HHEE_HVC_LIVEPATCH` (`0xC6001088`)：让 HHEE 代写内核或模块代码。

## 第一阶段原型

`patches/kernelpatch-0.12.5-par-hhee-experiment.patch` 必须叠加在
`patches/kernelpatch-0.12.5-par-experiment.patch` 之后。它只验证 KernelPatch 基础镜像
能否经过 HHEE 授权后执行，不启用 hook，也不加载 KPM：

1. 完成内存预留后恢复原指令并执行真正的 `paging_init()`；
2. 在 `paging_init()` 返回后取得 HHEE token，失败时直接退出；
3. 保持 `SCTLR_EL1.WXN`，先以 `RW+NX` 映射和复制 KernelPatch；
4. 把纯代码页改成 stage-1 `RO+X`，再调用 `HHEE_LKM_UPDATE`；
5. HHEE 返回成功后进入 `start_init()`，随后由
   `PAR_HHEE_BASE_PASSTHROUGH` 立即返回，不安装任何 hook。

独立构建时使用：

```sh
make DEBUG= PAR_OPT_LEVEL=-Oz \
  PAR_CFLAGS='-DPAR_HHEE_BRINGUP -DPAR_HHEE_BASE_PASSTHROUGH -DPAR_DEDICATED_MAP_AREA'
```

2026-08-15 已在 KernelPatch `0.12.5` (`a66b2a0`) 上完成 release 模式编译验证。
必须显式覆盖宿主环境中的 `DEBUG` 并用 `-Oz`；否则 `.setup.map` 为 `0x860`，虽小于
链接脚本的 `0xa00` 上限，却会超过内核实际预留的 `kpm_early_map_area=0x800`。
尺寸优化后的 `.setup.map` 为 `0x6c0`，`.kp.text` 与 `.kp.data` 保持分离。

2026-08-15 又修正了 `sukisu-kpm-only.patch` 漏链接 `kpm_map_area.o` 的问题，并从固定
stock 基线重放整套历史 KPM 实验，完成内核编译和 HHEE `kpimg` 离线注入。`kptools`
已确认注入目标是专用 `kpm_early_map_area`，没有回退覆盖 `tcp_init_sock`。候选镜像仅
保存在构建输出目录，没有进入 releases。

2026-08-15 首次真机尝试误把注入后的裸 `Image.gz`（头部 `1f 8b`）当成 kernel
分区镜像刷入。设备 DFX 记录的复位类型为 `FASTBOOT_KERNELIMG_ERR` (`0xa8`)，
fastboot 日志明确报出 `INVALID kernel IMAGE HEADER`；当时没有进入 Linux，更没有
执行 KernelPatch 或 HHEE HVC。因此这次黑屏不能用来验证 HHEE 假设。同一
`Image.gz` 已用 PAR 的 2048 字节页、header v1 参数重新封装为以 `ANDROID!`
开头的 boot image。

正确封装的镜像后续进行了两次真机启动：fastboot 成功识别头部并读取
`0x00e07a99` 字节 kernel，证明已排除封装问题。两次 DFX 记录的
boot keypoint 都停在 `STAGE_FASTBOOT_END` (`70`)，未到
`STAGE_KERNEL_EARLY_INITCALL` (`75`)；复位类型先后为 `LPM3_S_LPMCURST` (`0x46`)
和 `AP_S_AWDT` (`0x43`)，后者 subtype 为 `HI_APWDT_BL31LPM3`。新的 `last_kmsg`
没有任何可识别 Linux/KernelPatch 输出，也没有 `AP_S_HHEE_PANIC` (`0x68`)。
这证明现有前 `paging_init()` 方案在 Linux 早期 initcall 前就会硬锁死，最终由
AP/LPM3 看门狗复位；但日志粒度仍不足以判定是 trampoline 还是第一条
`HHEE_HVC_VERSION`/`HHEE_HVC_TOKEN` 触发。

2026-08-15 用同一个已确认的 `kpm_early_map_area` 注入基线完成两个无 HVC
控制实验：

1. `PAR_DIAG_PAGING_PASSTHROUGH` 只恢复 `paging_init()` 首指令、刷新 I-cache 并返回
   原内核路径，真机正常进入 Android 13；
2. `PAR_DIAG_MEMPROC_PASSTHROUGH` 先完整执行 `mem_proc()`，再执行同样的恢复
   路径，真机亦正常进入 Android 13。

两次启动后都从真机 `kernel` 分区回读并命中对应候选镜像的 SHA-256，
`sys.boot_completed=1`。第二个控制已覆盖旧失败探针在首条 HVC 之前的全部路径，
所以旧探针的硬锁直接由前 `paging_init()` 的 `HHEE_HVC_VERSION` 或
`HHEE_HVC_TOKEN` 调用触发。下一步不应在此时序继续试探 HVC，而应改用内核
现有、时序已验证的 HHEE 模块/livepatch 路径。

随后又完成四个真机结果：

1. `HHEE_HVC_VERSION` 移到原 `paging_init()` 返回后，候选 SHA-256
   `b323e5d05878d42d79776eca6a1dfd36f79a8b4cb06d938dbfe296ef29950961`
   正常进入 Android；
2. 同一位置单独调用 `HHEE_HVC_TOKEN`，候选 SHA-256
   `0e9ad51be64ea4cfdce6c3f985c482de2dee7b8d229e1915b787110610e40ee5`
   正常进入 Android；
3. `PAR_DIAG_POSTMAP_PASSTHROUGH` 完成 token 获取和新 KPM 区域的 `RW+NX` PTE
   创建后立即返回，候选 SHA-256
   `5dbd7b094f49a7faf939788243dfee669250935750f1c272cd951358016209dc`
   正常进入 Android；
4. 修正时序后的 `PAR_HHEE_BASE_PASSTHROUGH` 继续执行复制、`RO+X`、
   `HHEE_LKM_UPDATE` 和搬运后 `start`，候选 SHA-256
   `bff7756457a1a0edab2bb89bfc662642c7dbbe36a6dfc54640cd22e4ca40f401`
   仍在 keypoint 70 硬锁。最新 DFX 为 `LPM3_S_LPMCURST` (`0x46`)、subtype 0，
   没有新的 Linux 日志或 HHEE panic；该镜像也会阻断共享 kernel 下的 TWRP，需刷回
   工作内核才能恢复。

因此最终边界是：`RW+NX` 新映射以前的路径安全，失败只可能位于其后的代码复制、
`RO+X` 转换、`HHEE_LKM_UPDATE` 或进入搬运后 `start`。按 2026-08-15 的收尾决定，
不再进行真机拆分，也不把 KPM 纳入正式构建。

## 尚未解决的部分

即使第一阶段能够启动，也不代表 KPM 已经可用。完整实现至少还需要：

- 用 `HHEE_HVC_LIVEPATCH` 代替 KernelPatch 对现有内核代码的直接写入；
- 将 hook trampoline 的代码与可变元数据分到不同页，维持严格 W^X；
- KPM 重定位完成后逐段设为 `RO+X`/`RO+NX`/`RW+NX`，并分别提交 HHEE 授权；
- 为失败路径补充可观测状态，避免再用“是否关机”作为唯一判断依据。

这个方向已经停止真机实验，保持为高风险研究记录，不进入正式构建。
