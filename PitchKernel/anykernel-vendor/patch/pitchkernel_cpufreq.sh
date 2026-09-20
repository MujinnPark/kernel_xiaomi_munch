#!/system/bin/sh
# PitchKernel CPU & I/O Scheduler Tuning Script

# RETRY HARDENING (2026-09-20): live-device investigation confirmed
# nr_requests and hispeed_freq writes below were silently failing at
# post-fs-data.d time on this exact device (deadline iosched: worked;
# nr_requests: stayed at stock 128, script's own readback logged the
# failure; hispeed_freq: stayed at stock per-cluster values on all three
# clusters). Ruled out SELinux (zero avc denials for these paths in
# dmesg at the time). Confirmed: manually re-writing the exact same
# paths/values immediately after boot succeeds instantly and sticks.
# This is a boot-timing race -- these specific sysfs nodes (blk-mq queue
# depth, schedutil's per-policy attributes) are not yet fully attached/
# writable at the point post-fs-data.d scripts run, even though the I/O
# scheduler selector on the same block device already is.
#
# write_verify() below retries each write a bounded number of times with
# a short sleep between attempts, so a write that would have succeeded a
# few hundred ms later doesn't get silently lost. rate_limit_us previously
# had no verification at all (fire-and-forget) -- given it shares the same
# schedutil directory and boot window as hispeed_freq, it was very likely
# suffering the identical race with zero visibility; now covered by the
# same retry+verify path as everything else, for consistency.

LOG_TAG="PitchKernel"
MAX_ATTEMPTS=5
RETRY_DELAY_S=1

# write_verify PATH VALUE LABEL
# Writes VALUE to PATH, reads it back, retries up to MAX_ATTEMPTS times on
# mismatch. Logs OK/FAIL via log -p i/w -t "$LOG_TAG", including how many
# attempts it took. LABEL is a short human-readable name for the log line.
write_verify() {
    path="$1"
    val="$2"
    label="$3"
    attempt=1
    while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do
        echo "$val" > "$path" 2>/dev/null
        actual=$(cat "$path" 2>/dev/null)
        case "$actual" in
            *"$val"*)
                if [ "$attempt" -eq 1 ]; then
                    log -p i -t "$LOG_TAG" "${label}: OK on attempt 1 (${path} = ${val})"
                else
                    log -p i -t "$LOG_TAG" "${label}: OK on attempt ${attempt}/${MAX_ATTEMPTS} (${path} = ${val}) -- boot-timing race, previously silent"
                fi
                return 0
                ;;
        esac
        attempt=$((attempt + 1))
        [ "$attempt" -le "$MAX_ATTEMPTS" ] && sleep "$RETRY_DELAY_S"
    done
    log -p w -t "$LOG_TAG" "${label}: FAILED after ${MAX_ATTEMPTS} attempts (${path}, wanted ${val}, got '${actual}')"
    return 1
}

# --- I/O Scheduler enforcement ---
for blkdev in sda sdb sdc sdd sde sdf sdg; do
  SCHED_PATH="/sys/block/${blkdev}/queue/scheduler"
  if [ -f "$SCHED_PATH" ]; then
    if grep -q "mq-deadline" "$SCHED_PATH" 2>/dev/null; then
      write_verify "$SCHED_PATH" "mq-deadline" "iosched(${blkdev})"
    elif grep -q "deadline" "$SCHED_PATH" 2>/dev/null; then
      write_verify "$SCHED_PATH" "deadline" "iosched(${blkdev})"
    else
      AVAIL=$(cat "$SCHED_PATH" 2>/dev/null)
      log -p w -t "$LOG_TAG" "iosched: no deadline on /dev/${blkdev} available: ${AVAIL}"
    fi
  fi
done

# --- nr_requests ---
for blkdev in sda sdd sde sdf; do
  NR_PATH="/sys/block/${blkdev}/queue/nr_requests"
  [ -f "$NR_PATH" ] && write_verify "$NR_PATH" "256" "nr_requests(${blkdev})"
done

# --- read_ahead_kb ---
for blkdev in sda sdd sde sdf; do
  RA_PATH="/sys/block/${blkdev}/queue/read_ahead_kb"
  [ -f "$RA_PATH" ] && write_verify "$RA_PATH" "512" "read_ahead_kb(${blkdev})"
done

# --- Schedutil rate_limit_us 500us ---
for cpu in 0 1 2 3 4 5 6 7; do
  RATE_PATH="/sys/devices/system/cpu/cpu${cpu}/cpufreq/schedutil/rate_limit_us"
  [ -f "$RATE_PATH" ] && write_verify "$RATE_PATH" "500" "rate_limit_us(cpu${cpu})"
done

# --- hispeed_freq per cluster ---
for cpu in 0 4 7; do
  HISPEED_PATH="/sys/devices/system/cpu/cpu${cpu}/cpufreq/schedutil/hispeed_freq"
  if [ -f "$HISPEED_PATH" ]; then
    case $cpu in
      0) target=1497600 ;;
      4) target=1670400 ;;
      7) target=2419200 ;;
    esac
    write_verify "$HISPEED_PATH" "$target" "hispeed_freq(cpu${cpu})"
  fi
done

log -p i -t "$LOG_TAG" "boot tuning complete: deadline iosched, rate_limit_us=500 (retry-hardened, see script comments)"
