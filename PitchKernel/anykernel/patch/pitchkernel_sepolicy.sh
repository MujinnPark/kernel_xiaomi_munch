#!/system/bin/sh
# PitchKernel SELinux policy fixes

RULES="
allow vendor_hal_citsensorservice_xiaomi_default vendor_diag_device chr_file { read write open ioctl getattr }
allow miuibooster kernel process { getsched setsched }
allow miuibooster platform_app process { getsched setsched }
allow isolated_app turbosched_service service_manager { find }
allow vendor_hal_perf_default system_server dir { search }
allow vendor_hal_perf_default system_server file { read open getattr map }
allow vendor_hal_perf_default ksu file { read open getattr map }
allow vendor_hal_perf_default ksu dir { search }
allow vendor_hal_perf_default hal_audio_default dir { search }
allow vendor_hal_perf_default vendor_hal_perf_default capability { dac_override }
allow system_server zygote process { setsched }
allow system_suspend sysfs file { read open getattr }
allow system_suspend vendor_sysfs_battery_supply file { read open getattr }
allow untrusted_app property_type file { read open getattr map }
allow platform_app property_type file { read open getattr map }
allow priv_app property_type file { read open getattr map }
allow system_app property_type file { read open getattr map }
allow system_app property_type property_service { set }
allow zygote property_type file { read open getattr map }
allow mediaprovider_app property_type file { read open getattr map }
allow permissioncontroller_app property_type file { read open getattr map }
allow traceur_app property_type file { read open getattr map }
allow gmscore_app property_type file { read open getattr map }
allow vendor_init build_prop property_service { set }
allow vendor_init default_prop property_service { set }
allow rild vendor_pd_locater_dbg_prop file { read open getattr map }
allow system_app default_android_service service_manager { find }
allow system_app vendor_xiaomi_hardware_micharge_service service_manager { find }
allow platform_app default_android_service service_manager { find }
allow platform_app mcd_data_file dir { search }
allow platform_app migt_file dir { search }
allow mediaprovider_app default_android_service service_manager { find }
allow mediaprovider_app hyperos_cust_feature_resolve_service service_manager { find }
allow vendor_wlc_app hyperos_cust_feature_resolve_service service_manager { find }
allow rkpdapp hyperos_cust_feature_resolve_service service_manager { find }
allow vendor_qtelephony data_log_stability_file dir { search }
allow untrusted_app sysfs_zram file { read open getattr }
allow untrusted_app data_log_file dir { search }
"

SEPOLICY_DIR="/data/adb/modules/pitchkernel_tuning"
mkdir -p "$SEPOLICY_DIR"

printf '%s\n' "$RULES" > "$SEPOLICY_DIR/sepolicy.rule" 2>/dev/null \
  && log -p i -t PitchKernel "sepolicy: $(printf '%s\n' "$RULES" | grep -c "^allow") rules written" \
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
