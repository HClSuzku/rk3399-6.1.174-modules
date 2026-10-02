# rk3399-6.1.174-modules

为 RK3399（tpm312）盒子重建内核模块树的构建工程。

## 背景

设备在 2026-09-22 换成 6.1.174 内核后，只刷了 Image，没有配套的 `/lib/modules/6.1.174/` 模块树，
导致依赖模块的功能全部失效：Docker / CasaOS 起不来（overlay、veth、bridge、iptables 相关模块缺失），
IPv6 拿不到地址（ipv6 模块缺失），easytier 面板也不可用。

本仓库用于**可复现地**重建这套模块。

## 复现的两个固定点

| 项目 | 值 |
|---|---|
| 源码 | `ophub/linux-6.1.y-rockchip` |
| commit | `be74fe08d7c6f60b5fd10e92917cd1eb2fa04210` |
| 配置 | `device-config.txt`（设备 `/proc/config.gz` 原样导出） |
| 编译器 | `aarch64-linux-gnu-gcc (Ubuntu 11.4.0-1ubuntu1~22.04.3) 11.4.0`，与设备 Image 的构建工具链一致 |
| runner | `ubuntu-22.04`（x64，公开仓库免费 4 核 16G），交叉编译 |

## 闸门

`scripts/check_config.sh` 在编译前强制校验，任何一条不过就停，不出产物：

1. `make kernelrelease` 必须等于 `6.1.174`（`LOCALVERSION` 为空、`LOCALVERSION_AUTO` 未开）
2. `olddefconfig` 后的 `.config` 与设备配置逐项比对，只允许 `CC_VERSION_TEXT / GCC_VERSION / AS_VERSION / LD_VERSION` 这类版本字符串不同，其余任何差异都 FAIL
3. 关键项逐条确认：`MODULE_SIG` 未启用（未签名模块可加载）、`MODVERSIONS` 未启用（不看符号 CRC）、`MODULE_COMPRESS_NONE`、`LTO_NONE`、`PREEMPT_VOLUNTARY`（vermagic 不带 `preempt`）、`SMP`、`MODULE_UNLOAD`
4. 产物抽查 `modinfo -F vermagic` 必须为 `6.1.174 SMP mod_unload aarch64`

## 产物

- `modules-6.1.174` artifact：`modules-6.1.174.tar.gz`，解开即 `lib/modules/6.1.174/` 整棵树（含 `modules.dep` 等）
- `build-reports` artifact：闸门报告、生成的 `.config`、构建日志

## 用法

Actions 页面手动触发 `build-modules-6.1.174`（workflow_dispatch）。产物只做模块，不产出 Image，
设备端不会因为这次构建改变内核本身。
