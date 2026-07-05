#!/system/bin/sh
# PitchKernel SELinux policy fixes
# Runs from post-fs-data.d via KSU on every boot.
#
# FIX: Allow thermal HAL to access diag interface for sensor reads.
# AVC denial: vendor_hal_citsensorservice_xiaomi_default -> vendor_diag_device chr_file

RULE="allow vendor_hal_citsensorservice_xiaomi_default vendor_diag_device chr_file { read write open ioctl getattr }"
SEPOLICY_RULE_DIR="/data/adb/modules/pitchkernel_tuning"
SEPOLICY_RULE_FILE="$SEPOLICY_RULE_DIR/sepolicy.rule"

# Method 1: KSU module sepolicy.rule (read by KSU on next boot)
if [ -d "/data/adb/modules" ]; then
  mkdir -p "$SEPOLICY_RULE_DIR"
  echo "$RULE" > "$SEPOLICY_RULE_FILE"
  log -p i -t PitchKernel "sepolicy: rule written to $SEPOLICY_RULE_FILE"
fi

# Method 2: ksud sepolicy patch (live, if supported by this KSU version)
if command -v ksud >/dev/null 2>&1; then
  ksud sepolicy patch "$RULE" 2>/dev/null \
    && log -p i -t PitchKernel "sepolicy: ksud live patch applied" \
    || log -p w -t PitchKernel "sepolicy: ksud live patch failed (will apply on next boot via rule file)"
fi

# Method 3: magiskpolicy fallback (if Magisk coexists)
if command -v magiskpolicy >/dev/null 2>&1; then
  magiskpolicy --live "$RULE" 2>/dev/null \
    && log -p i -t PitchKernel "sepolicy: magiskpolicy live patch applied"
fi
