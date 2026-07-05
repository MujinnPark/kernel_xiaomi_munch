#!/system/bin/sh
# PitchKernel SELinux policy fixes

RULES="
allow vendor_hal_citsensorservice_xiaomi_default vendor_diag_device chr_file { read write open ioctl getattr }
allow miuibooster kernel process { getsched setsched }
allow miuibooster platform_app process { getsched setsched }
allow isolated_app turbosched_service service_manager { find }
allow vendor_hal_perf_default system_server dir { search }
allow vendor_hal_perf_default system_server file { read open getattr }
allow vendor_hal_perf_default system_server proc { read }
allow vendor_hal_perf_default ksu file { read open getattr }
allow vendor_hal_perf_default ksu dir { search }
allow system_server zygote process { setsched }
allow system_suspend sysfs file { read open getattr }
allow system_suspend vendor_sysfs_battery_supply file { read open getattr }
allow zygote vendor_display_prop file { read open getattr }
allow platform_app vendor_display_prop file { read open getattr }
allow untrusted_app vendor_display_prop file { read open getattr }
allow untrusted_app proc_version file { read open getattr }
allow vendor_init build_prop property_service { set }
allow vendor_init default_prop property_service { set }
allow gmscore_app system_adbd_prop file { read open getattr }
allow gmscore_app adbd_prop file { read open getattr }
allow rild vendor_pd_locater_dbg_prop file { read open getattr }
allow vendor_poweroffalarm_app default_android_service service_manager { find }
allow vendor_poweroffalarm_app hyperos_cust_feature_resolve_service service_manager { find }
"

SEPOLICY_DIR="/data/adb/modules/pitchkernel_tuning"
mkdir -p "$SEPOLICY_DIR"

printf '%s\n' "$RULES" > "$SEPOLICY_DIR/sepolicy.rule" 2>/dev/null \
  && log -p i -t PitchKernel "sepolicy: $(echo "$RULES" | grep -c "allow") rules written" \
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
