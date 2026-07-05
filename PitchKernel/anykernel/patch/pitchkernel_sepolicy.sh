#!/system/bin/sh
# PitchKernel SELinux policy fixes
# Runs from post-fs-data.d via KSU/Magisk on every boot.
#
# FIX: Allow thermal HAL to access diag interface for sensor reads.
# Without this, ThermalHalWrapper logs 40+ "Sensor Temperature read failure"
# errors per session and the framework thermal governor is blind to SoC temps.
# Root cause: vendor_hal_citsensorservice_xiaomi_default lacks chr_file
# access to vendor_diag_device — denied by SELinux on custom kernels.

supolicy --live \
  "allow vendor_hal_citsensorservice_xiaomi_default vendor_diag_device chr_file { read write open ioctl getattr }"

log -p i -t PitchKernel "sepolicy: thermal HAL diag access granted"
