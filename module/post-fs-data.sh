#!/system/bin/sh
# PitchKernel CPU Frequency Profile
# Applied via KernelSU/Magisk post-fs-data.d on every boot.
#
# Bug fix (was Bug #10): original script read /data/.pitchkernel_profile
# but nothing ever wrote that file — anykernel.sh had no profile selector,
# so the overclock branch was permanently dead code. Two options here:
#
#   Option A (current): remove the profile logic entirely. The hardware-enforced
#   ceiling is 2841600 kHz as confirmed by DTB analysis and real dmesg. The
#   patch/pitchkernel_cpufreq.sh (installed by anykernel.sh to post-fs-data.d)
#   handles this already. This module is now a no-op safety net that only runs
#   if the anykernel-installed script is missing.
#
#   Option B: add profile selection to anykernel.sh (volume key at flash time)
#   and write /data/.pitchkernel_profile there. See KERNEL_ROADMAP.md.
#
# Bug fix (was Bug #11): this module and patch/pitchkernel_cpufreq.sh both
# install to post-fs-data.d and both write scaling_max_freq. Pick one.
# The anykernel-installed script (patch/) is the canonical path — no separate
# module install needed. This module now acts only as a fallback.

CPU7_PATH="/sys/devices/system/cpu/cpu7/cpufreq/scaling_max_freq"
# Hardware-confirmed ceiling: 2841600 kHz (qcom_cpufreq_hw_read_lut skips 3187200)
TARGET=2841600

# If the anykernel-installed script is already present, this module is redundant.
# Exit cleanly and let the other script handle it.
ANYKERNEL_SCRIPT="/data/adb/post-fs-data.d/pitchkernel_cpufreq.sh"
if [ -f "$ANYKERNEL_SCRIPT" ]; then
    log -p i -t PitchKernel "module: anykernel script present, deferring to it"
    exit 0
fi

# Fallback: anykernel script missing (e.g. fresh module install without reflash).
# Wait for cpufreq sysfs node to appear.
i=0
while [ ! -f "$CPU7_PATH" ] && [ $i -lt 20 ]; do
    sleep 0.5
    i=$((i + 1))
done

if [ ! -f "$CPU7_PATH" ]; then
    log -p w -t PitchKernel "module: cpu7 scaling_max_freq not found after 10s"
    exit 1
fi

ACTUAL=$(cat "$CPU7_PATH" 2>/dev/null)
if [ "$ACTUAL" != "$TARGET" ]; then
    echo "$TARGET" > "$CPU7_PATH" 2>/dev/null
    ACTUAL=$(cat "$CPU7_PATH" 2>/dev/null)
fi

log -p i -t PitchKernel "module fallback: cpu7 scaling_max_freq = ${ACTUAL} kHz"
