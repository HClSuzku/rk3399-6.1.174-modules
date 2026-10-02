#!/usr/bin/env bash
# 闸门：设备实配 vs 构建生成的 .config
# 只允许“工具链版本字符串”一类差异，其余任何差异一律 FAIL（防止默默编出不合闸门的模块）
set -uo pipefail

DEV="${1:?用法: check_config.sh <设备配置> <生成的 .config> <kernelrelease文件>}"
GEN="${2:?缺少生成的 .config}"
KR_FILE="${3:?缺少 kernelrelease 文件}"

fail=0

echo "===== 1. kernelrelease 校验 ====="
KR="$(cat "$KR_FILE" | tr -d '[:space:]')"
echo "构建产出的 kernelrelease = [$KR]（设备 uname -r = 6.1.174）"
if [ "$KR" = "6.1.174" ]; then echo "PASS"; else echo "FAIL: kernelrelease 不等于 6.1.174"; fail=1; fi

echo
echo "===== 2. 配置差异分类 ====="
# 允许差异：仅编译器/汇编器/链接器版本字符串（跟构建机有关，与模块 ABI 无关）
ALLOW_RE='^CONFIG_(CC_VERSION_TEXT|GCC_VERSION|AS_VERSION|LD_VERSION)='
DEV_C="$(mktemp)"; GEN_C="$(mktemp)"
grep -E '^(CONFIG_[A-Za-z0-9_]+=|# CONFIG_[A-Za-z0-9_]+ is not set)' "$DEV" | sort > "$DEV_C"
grep -E '^(CONFIG_[A-Za-z0-9_]+=|# CONFIG_[A-Za-z0-9_]+ is not set)' "$GEN" | sort > "$GEN_C"
echo "设备配置项数: $(wc -l < "$DEV_C") / 生成配置项数: $(wc -l < "$GEN_C")"

diff_out="$(diff "$DEV_C" "$GEN_C" || true)"
if [ -z "$diff_out" ]; then
  echo "PASS: 配置零差异"
else
  allowed="$(printf '%s\n' "$diff_out" | grep -E "^[<>] $ALLOW_RE" || true)"
  rest="$(printf '%s\n' "$diff_out" | grep -vE "^[<>] $ALLOW_RE" | grep -vE '^[0-9,]+[acd][0-9,]+$' || true)"
  echo "--- 允许的工具链版本差异 ---"
  [ -n "$allowed" ] && printf '%s\n' "$allowed" || echo "(无)"
  echo "--- 其余差异（必须为空）---"
  if [ -n "$(printf '%s' "$rest" | sed '/^[[:space:]]*$/d')" ]; then
    printf '%s\n' "$rest"
    echo "FAIL: 存在非版本号差异，必须人工判定后再继续"
    fail=1
  else
    echo "(无)"
    echo "PASS: 差异仅限工具链版本字符串"
  fi
fi

echo
echo "===== 3. 关键闸门项逐条确认（必须与设备一致）====="
check_line() {
  if grep -qxF "$1" "$GEN"; then echo "PASS  $1"; else echo "FAIL  缺少: $1"; fail=1; fi
}
check_line '# CONFIG_MODULE_SIG is not set'
check_line '# CONFIG_MODVERSIONS is not set'
check_line 'CONFIG_MODULE_UNLOAD=y'
check_line 'CONFIG_MODULE_COMPRESS_NONE=y'
check_line 'CONFIG_LTO_NONE=y'
check_line 'CONFIG_PREEMPT_VOLUNTARY=y'
check_line '# CONFIG_PREEMPT is not set'
check_line '# CONFIG_PREEMPT_NONE is not set'
check_line 'CONFIG_SMP=y'
check_line 'CONFIG_LOCALVERSION=""'
check_line '# CONFIG_LOCALVERSION_AUTO is not set'
echo "--- 目标功能（本次要修的东西）---"
check_line 'CONFIG_IPV6=m'
check_line 'CONFIG_OVERLAY_FS=m'
check_line 'CONFIG_TUN=m'

echo
echo "===== 4. 模块 ABI 风险项（只读报告，不判定）====="
grep -E '^CONFIG_(ARM64_MTE|ARM64_BTI|ARM64_PTR_AUTH|ARM64_PTR_AUTH_KERNEL|STACKPROTECTOR|STACKPROTECTOR_STRONG|CFI_CLANG|RANDSTRUCT|MODULE_SIG_FORCE|DEBUG_INFO|DEBUG_INFO_DWARF5|DEBUG_INFO_COMPRESSED|RANDOMIZE_BASE|RELR|ARM64_USE_LSE_ATOMICS)=' "$GEN" || true

echo
if [ "$fail" -eq 0 ]; then echo "===== 闸门全部通过 ====="; else echo "===== 闸门未通过，停止 ====="; fi
exit "$fail"
