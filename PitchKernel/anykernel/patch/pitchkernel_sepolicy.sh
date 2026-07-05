#!/system/bin/sh
# PitchKernel SELinux policy fixes
# Runs from post-fs-data.d via KSU on every boot.

RULES="
allow vendor_hal_citsensorservice_xiaomi_default vendor_diag_device chr_file { read write open ioctl getattr }
allow miuibooster kernel process { getsched setsched }
allow miuibooster platform_app process { getsched setsched }
allow isolated_app turbosched_service service_manager { find }
allow vendor_hal_perf_default system_server dir { search }
allow vendor_hal_perf_default system_server proc { read }
allow vendor_hal_perf_default ksu dir { search }
allow system_server zygote process { setsched }
"

SEPOLICY_DIR="/data/adb/modules/pitchkernel_tuning"
mkdir -p "$SEPOLICY_DIR"

printf '%s\n' "$RULES" > "$SEPOLICY_DIR/sepolicy.rule" 2>/dev/null \
  && log -p i -t PitchKernel "sepolicy: rules written" \
  || log -p w -t PitchKernel "sepolicy: failed to write rule file"

if command -v ksud >/dev/null 2>&1; then
  printf '%s\n' "$RULES" | while IFS= read -r rule; do
    [ -z "$rule" ] && continue
    ksud sepolicy patch "$rule" 2>/dev/null
  done
  log -p i -t PitchKernel "sepolicy: ksud patches attempted"
fi

if command -v magiskpolicy >/dev/null 2>&1; then
  printf '%s\n' "$RULES" | while IFS= read -r rule; do
    [ -z "$rule" ] && continue
    magiskpolicy --live "$rule" 2>/dev/null
  done
  log -p i -t PitchKernel "sepolicy: magiskpolicy patches attempted"
fi
