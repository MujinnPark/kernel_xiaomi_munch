#!/system/bin/sh
# PitchKernel v3 — scheduler/GPU tuning addition
# Target: munch (POCO F4 / Redmi K40S), SM8250/Snapdragon 870, Adreno 650
# Kernel confirmed: 4.19.325-pitchkernel+ (own build, 2026-07-08)
#
# CHANGE LOG FROM v2:
#   - v2's "SKIP: no such path" failures on every sched_* sysctl were NOT
#     a bad path map. Root cause: the script was invoked from the wrong
#     working directory ("No such file or directory" on the sh call
#     itself), so it never actually ran; the logcat we read was leftover
#     output from an earlier attempt. Live device recon (kernel_recon.txt,
#     run 2026-07-09) confirms every /proc/sys/kernel/sched_* path below
#     genuinely exists on this exact running kernel. Restored them.
#   - GPU: min_clock_mhz / max_clock_mhz confirmed to exist at
#     /sys/class/kgsl/kgsl-3d0/ on this device (recon line 522-525).
#     Also confirmed a real devfreq node exists for the GPU:
#     /sys/class/devfreq/3d00000.qcom,kgsl-3d0/governor — added below,
#     was previously left out because I couldn't resolve it statically.
#   - core_ctl: recon shows cpu0/core_ctl/enable = 0 and
#     cpu7/core_ctl/enable = 1 on the live, running device. I do not have
#     evidence this is a bug rather than intentional cluster design (cpu0
#     as the always-on anchor core some vendor kernels refuse to let you
#     hotplug). Forcing cpu0 to 1 again without understanding why it's 0
#     is guessing dressed up as a fix. DROPPED the cpu0 write. cpu4/cpu7
#     re-assert kept since those already read back correctly in v2's log.
#   - sched_util_est and sched_core_ctl_enable remain dropped (still not
#     real, per original source scan — nothing in this recon contradicts
#     that).
#   - GPU min freq: still 400MHz. Recon didn't give us the live OPP table
#     values (freq_table_mhz), so this number is UNCONFIRMED against the
#     live table, only against the DTS in the original zip. If you want
#     it nailed down: `cat /sys/class/kgsl/kgsl-3d0/freq_table_mhz` and
#     send it back before relying on this in production.

echo "v3 script started: $(date) pwd=$(pwd) args=$@" >> /data/local/tmp/pitchkernel_v3_proof.txt 2>&1
LOG_TAG="PitchKernelV3"
log_rw() {
    path="$1"
    val="$2"
    if [ ! -e "$path" ]; then
        log -p w -t "$LOG_TAG" "SKIP (no such path): $path"
        return 1
    fi
    echo "$val" > "$path" 2>/dev/null
    actual=$(cat "$path" 2>/dev/null)
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

log -p i -t "$LOG_TAG" "=== starting v3 tuning pass ==="
log -p i -t "$LOG_TAG" "pwd: $(pwd)"

### [SCHEDULER] sysctls — confirmed present via live recon 2026-07-09 ###

log_rw "/proc/sys/kernel/sched_boost" "1"
log_rw "/proc/sys/kernel/sched_schedstats" "0"
log_rw "/proc/sys/kernel/sched_latency_ns" "6000000"
log_rw "/proc/sys/kernel/sched_min_granularity_ns" "1500000"
log_rw "/proc/sys/kernel/sched_wakeup_granularity_ns" "1000000"
log_rw "/proc/sys/kernel/sched_upmigrate" "85"
log_rw "/proc/sys/kernel/sched_downmigrate" "65"
log_rw "/proc/sys/kernel/sched_group_upmigrate" "90"
log_rw "/proc/sys/kernel/sched_group_downmigrate" "70"
# NOTE: v3 run confirmed sched_upmigrate/downmigrate are two-value fields
# (readback showed "85 95" / "65  85" after writing only "85"/"65" — the
# second number is a pre-existing value the single-value write left
# untouched, not something we set). If the second field matters for the
# tuning goal, write both explicitly, e.g.:
#   log_rw "/proc/sys/kernel/sched_upmigrate" "85 95"
# Left as single-value writes here since the target second value isn't
# specified/confirmed. Check sched_group_upmigrate/downmigrate too —
# they read back single in the v3 log but may be pairs on other builds.

### [CPU] core_ctl — cpu0 write dropped, see change log above ###

for cpu in 4 7; do
    CORE_CTL_PATH="/sys/devices/system/cpu/cpu${cpu}/core_ctl/enable"
    if [ -f "$CORE_CTL_PATH" ]; then
        log_rw "$CORE_CTL_PATH" "1"
    else
        log -p i -t "$LOG_TAG" "no core_ctl kobject on cpu${cpu}"
    fi
done
log -p i -t "$LOG_TAG" "cpu0/core_ctl/enable intentionally NOT written — recon shows it's 0 on this live kernel and cause is unconfirmed. Not forcing it."

### [CPU] governor ###

for cpu in 0 1 2 3 4 5 6 7; do
    GOV_PATH="/sys/devices/system/cpu/cpu${cpu}/cpufreq/scaling_governor"
    if [ -f "$GOV_PATH" ]; then
        log_rw "$GOV_PATH" "schedutil"
    fi
done

### [GPU] KGSL clock clamp — confirmed present via recon ###

log_rw "/sys/class/kgsl/kgsl-3d0/min_clock_mhz" "400"
# max_clock_mhz intentionally NOT written — leaving at stock ceiling per spec.

### [GPU] devfreq governor — confirmed node exists via recon ###

GPU_DEVFREQ_GOV="/sys/class/devfreq/3d00000.qcom,kgsl-3d0/governor"
if [ -f "$GPU_DEVFREQ_GOV" ]; then
    current_gov=$(cat "$GPU_DEVFREQ_GOV" 2>/dev/null)
    log -p i -t "$LOG_TAG" "current GPU devfreq governor: $current_gov"
    log_rw "$GPU_DEVFREQ_GOV" "msm-adreno-tz"
else
    log -p w -t "$LOG_TAG" "SKIP: $GPU_DEVFREQ_GOV not present"
fi

log -p i -t "$LOG_TAG" "=== v3 tuning pass complete, check logcat -s $LOG_TAG for results ==="
