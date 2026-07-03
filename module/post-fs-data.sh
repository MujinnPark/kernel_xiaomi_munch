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

# If the anykernel-installed script is already present, this module is redundant.
# Exit cleanly and let the other script handle it.
ANYKERNEL_SCRIPT="/data/adb/post-fs-data.d/pitchkernel_cpufreq.sh"
if [ -f "$ANYKERNEL_SCRIPT" ]; then
    log -p i -t PitchKernel "module: anykernel script present, deferring to it"
    exit 0
fi

# Fallback: anykernel script missing (e.g. fresh module install without reflash).
# Apply the same tuning that pitchkernel_cpufreq.sh would have applied.
# We do NOT write scaling_max_freq — the hardware OPP table ceiling is 3187200 kHz
# for SM8250 prime core. With uclamp disabled, schedutil won't boost there for
# normal tasks. FKM showing 3187 MHz is cpuinfo_max_freq (hardware capability),
# not the actual operating frequency.

# Wait up to 10s for cpufreq sysfs to appear before applying tuning.
i=0
while [ ! -d "/sys/devices/system/cpu/cpu0/cpufreq/schedutil" ] && [ $i -lt 20 ]; do
    sleep 0.5
    i=$((i + 1))
done

if [ ! -d "/sys/devices/system/cpu/cpu0/cpufreq/schedutil" ]; then
    log -p w -t PitchKernel "module fallback: schedutil sysfs not found after 10s, skipping"
    exit 1
fi

# I/O scheduler — enforce mq-deadline (init.rc resets it to cfq at boot)
for blkdev in sda sdb sdc sdd sde sdf; do
    SCHED_PATH="/sys/block/${blkdev}/queue/scheduler"
    if [ -f "$SCHED_PATH" ]; then
        if grep -q "mq-deadline" "$SCHED_PATH" 2>/dev/null; then
            echo "mq-deadline" > "$SCHED_PATH" 2>/dev/null
            log -p i -t PitchKernel "module fallback: set mq-deadline on /dev/${blkdev}"
        fi
    fi
done

# Schedutil rate_limit_us — faster CPU freq response for gaming
for cpu in 0 1 2 3 4 5 6 7; do
    RATE_PATH="/sys/devices/system/cpu/cpu${cpu}/cpufreq/schedutil/rate_limit_us"
    if [ -f "$RATE_PATH" ]; then
        echo "500" > "$RATE_PATH" 2>/dev/null
    fi
done

# hispeed_freq per cluster — minimum freq to jump to on load burst
for cpu in 0 4 7; do
    HISPEED_PATH="/sys/devices/system/cpu/cpu${cpu}/cpufreq/schedutil/hispeed_freq"
    if [ -f "$HISPEED_PATH" ]; then
        case $cpu in
            0) echo "1497600" > "$HISPEED_PATH" 2>/dev/null ;;  # silver mid
            4) echo "1670400" > "$HISPEED_PATH" 2>/dev/null ;;  # gold mid
            7) echo "2419200" > "$HISPEED_PATH" 2>/dev/null ;;  # prime
        esac
    fi
done

log -p i -t PitchKernel "module fallback: tuning applied (mq-deadline, rate_limit_us=200, hispeed per cluster)"


