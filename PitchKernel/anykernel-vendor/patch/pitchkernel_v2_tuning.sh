#!/system/bin/sh
# PitchKernel v2 — scheduler/GPU tuning addition
# Target: munch (POCO F4 / Redmi K40S), SM8250/Snapdragon 870, Adreno 650
#
# This is an ADDITION to the existing, confirmed-working post-fs-data.sh
# (mq-deadline, rate_limit_us, hispeed_freq). It does not touch or duplicate
# any path that script already writes. Install alongside it, do not merge
# blindly — run both and confirm no conflicting writes before shipping.
#
# Every path below was confirmed by grepping the actual kernel source
# (android_kernel_xiaomi_sm8250-android16-aptusitu) and the munch DTB
# include chain (munch-sm8250-overlay.dtbo-base -> kona.dtb, kona-v2.dtb).
# Paths/values NOT confirmed in source were dropped rather than guessed:
#
#   DROPPED: sched_core_ctl_enable  -> real name is "enable", per-cluster,
#            at /sys/devices/system/cpu/cpuN/core_ctl/enable, and it
#            already defaults to 1 at kernel init (core_ctl.c). Writing 1
#            is a no-op unless something else disabled it — included below
#            as a defensive re-assert, not a "new" tweak.
#   DROPPED: sched_util_est sysctl  -> does not exist. UTIL_EST is a
#            SCHED_FEAT (kernel/sched/features.h), on by default, only
#            togglable via debugfs sched_features. Not a /proc/sys node.
#   CORRECTED: GPU min freq 315000000 -> not a real OPP step for this GPU
#            table (kona-v2-gpu.dtsi). Real steps near your target: 305MHz
#            or 400MHz. Using 400MHz (safer floor, still allows scaling
#            down for battery when idle). Also corrected units: KGSL sysfs
#            takes MHz, not Hz.
#   CORRECTED: GPU governor path -> written via /sys/class/kgsl/kgsl-3d0/
#            (confirmed driver attrs), not a bare "msm-adreno-tz" sysfs
#            write. The devfreq governor node under /sys/class/devfreq/
#            exists in principle but its exact node id is assigned at
#            probe time and isn't resolvable from static source — this
#            script does NOT touch it, to avoid writing a guessed path.

LOG_TAG="PitchKernelV2"
log_rw() {
    # $1 = path, $2 = value written
    path="$1"
    val="$2"
    if [ ! -f "$path" ]; then
        log -p w -t "$LOG_TAG" "SKIP (no such path): $path"
        return 1
    fi
    echo "$val" > "$path" 2>/dev/null
    actual=$(cat "$path" 2>/dev/null)
    # readback comparison is substring-based since some nodes echo back
    # formatted/derived values (e.g. percentages, padded ints)
    case "$actual" in
        *"$val"*)
            log -p i -t "$LOG_TAG" "OK: $path = $val (readback: $actual)"
            return 0
            ;;
        *)
            log -p e -t "$LOG_TAG" "FAIL: $path wrote $val but reads back '$actual'"
            return 1
            ;;
    esac
}

log -p i -t "$LOG_TAG" "=== starting v2 tuning pass ==="

### [SCHEDULER] sysctls — confirmed in kernel/sysctl.c ###

log_rw "/proc/sys/kernel/sched_boost" "1"
log_rw "/proc/sys/kernel/sched_schedstats" "0"
log_rw "/proc/sys/kernel/sched_latency_ns" "6000000"
log_rw "/proc/sys/kernel/sched_min_granularity_ns" "2000000"
log_rw "/proc/sys/kernel/sched_wakeup_granularity_ns" "3000000"
log_rw "/proc/sys/kernel/sched_upmigrate" "85"
log_rw "/proc/sys/kernel/sched_downmigrate" "65"
log_rw "/proc/sys/kernel/sched_group_upmigrate" "90"
log_rw "/proc/sys/kernel/sched_group_downmigrate" "70"

### [CPU] core_ctl — defensive re-assert only, defaults to 1 already ###

for cpu in 0 4 7; do
    CORE_CTL_PATH="/sys/devices/system/cpu/cpu${cpu}/core_ctl/enable"
    if [ -f "$CORE_CTL_PATH" ]; then
        log_rw "$CORE_CTL_PATH" "1"
    else
        log -p i -t "$LOG_TAG" "no core_ctl kobject on cpu${cpu} (expected — not every cpu hosts a cluster kobject)"
    fi
done

### [CPU] governor — confirm schedutil is set (should already be default) ###

for cpu in 0 1 2 3 4 5 6 7; do
    GOV_PATH="/sys/devices/system/cpu/cpu${cpu}/cpufreq/scaling_governor"
    if [ -f "$GOV_PATH" ]; then
        log_rw "$GOV_PATH" "schedutil"
    fi
done

### [GPU] KGSL clock clamp — units are MHz. Corrected from your 315000000 Hz
### request: 315MHz is not a real OPP step. Using 400MHz floor (real step).
### Max left untouched = stock (670MHz ceiling, unwritten = OPP table max).

KGSL_MIN="/sys/class/kgsl/kgsl-3d0/min_clock_mhz"
if [ -f "$KGSL_MIN" ]; then
    log_rw "$KGSL_MIN" "400"
else
    log -p w -t "$LOG_TAG" "SKIP: $KGSL_MIN not present on this device/build"
fi

# max_clock_mhz intentionally NOT written — "stock max" per your own spec
# means leave it alone. Writing it would only be needed if something else
# had already lowered it.

log -p i -t "$LOG_TAG" "=== v2 tuning pass complete, check logcat -s $LOG_TAG for results ==="
