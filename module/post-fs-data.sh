#!/system/bin/sh
# PitchKernel CPU Frequency Profile
# Applied via KernelSU/Magisk post-fs-data.d on every boot.
# Profile written to /data/.pitchkernel_profile by anykernel.sh at flash time.
#
# Verified frequencies from DTB binary analysis of Lime kernel:
#   Stable:    Prime cpu7 = 2841600 kHz (confirmed in Lime stable DTB)
#   Overclock: Prime cpu7 = 3187200 kHz (hardware ceiling, confirmed on-device)

PROFILE=$(cat /data/.pitchkernel_profile 2>/dev/null || echo "stable")

CPU7_PATH="/sys/devices/system/cpu/cpu7/cpufreq/scaling_max_freq"

# Wait for cpufreq sysfs node
i=0
while [ ! -f "$CPU7_PATH" ] && [ $i -lt 20 ]; do
    sleep 0.5
    i=$((i + 1))
done

[ -f "$CPU7_PATH" ] || { log -p w -t PitchKernel "cpu7 path not found"; exit 1; }

case "$PROFILE" in
    overclock) TARGET=3187200 ;;
    # BUG #9 FIX: was 2553600, corrected to 2841600 from DTB analysis
    stable|*)  TARGET=2841600 ;;
esac

echo "$TARGET" > "$CPU7_PATH" 2>/dev/null
ACTUAL=$(cat "$CPU7_PATH" 2>/dev/null)

if [ "$ACTUAL" = "$TARGET" ]; then
    log -p i -t PitchKernel "Profile '$PROFILE' applied: cpu7=$TARGET kHz"
else
    log -p e -t PitchKernel "Profile '$PROFILE' FAILED: wanted $TARGET, got $ACTUAL"
fi
