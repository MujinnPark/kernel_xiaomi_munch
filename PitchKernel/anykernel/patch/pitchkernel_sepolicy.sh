#!/system/bin/sh
# PitchKernel SELinux policy fixes
# Each rule is evidence-backed from dmesg AVC denial analysis.

RULES="
allow vendor_hal_citsensorservice_xiaomi_default vendor_diag_device chr_file { read write open ioctl getattr }
allow miuibooster kernel process { getsched setsched }
allow miuibooster platform_app process { getsched setsched }
allow isolated_app turbosched_service service_manager { find }
allow vendor_hal_perf_default system_server dir { search }
allow vendor_hal_perf_default system_server file { read open getattr map }
allow vendor_hal_perf_default system_server proc { read }
allow vendor_hal_perf_default ksu file { read open getattr map }
allow vendor_hal_perf_default ksu dir { search }
allow vendor_hal_perf_default vendor_hal_perf_default capability { dac_override }
allow system_server zygote process { setsched }
allow system_suspend sysfs file { read open getattr }
allow system_suspend vendor_sysfs_battery_supply file { read open getattr }
allow zygote vendor_display_prop file { read open getattr map }
allow platform_app vendor_display_prop file { read open getattr map }
allow untrusted_app vendor_display_prop file { read open getattr map }
allow permissioncontroller_app vendor_display_prop file { read open getattr map }
allow vendor_init build_prop property_service { set }
allow vendor_init default_prop property_service { set }
allow gmscore_app system_adbd_prop file { read open getattr map }
allow gmscore_app adbd_prop file { read open getattr map }
allow rild vendor_pd_locater_dbg_prop file { read open getattr map }
allow vendor_poweroffalarm_app default_android_service service_manager { find }
allow vendor_poweroffalarm_app hyperos_cust_feature_resolve_service service_manager { find }
allow vendor_systemhelper_app default_android_service service_manager { find }
allow vendor_systemhelper_app hyperos_cust_feature_resolve_service service_manager { find }
allow vendor_embmssl_app hyperos_cust_feature_resolve_service service_manager { find }
allow bpfloader vendor_default_prop file { read open getattr map }
allow system_app keyguard_config_prop file { read open getattr map }
allow system_app last_boot_reason_prop file { read open getattr map }
allow system_server vendor_wfd_sys_debug_prop file { read open getattr map }
allow system_server vendor_wfd_sys_prop file { read open getattr map }
allow system_server wifi_hal_prop file { read open getattr map }
allow system_server default_android_service service_manager { find }
allow surfaceflinger default_android_service service_manager { find }
allow surfaceflinger mcd_data_file dir { search }
allow untrusted_app proc_net file { read open getattr }
allow untrusted_app proc_net_tcp_udp file { read open getattr }
allow untrusted_app selinuxfs file { read open getattr }
allow untrusted_app build_attestation_prop file { read open getattr map }
allow untrusted_app serialno_prop file { read open getattr map }
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
