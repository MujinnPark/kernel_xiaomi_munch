#!/system/bin/sh
# PitchKernel CPU & I/O Scheduler Tuning Script
# Installed to /data/adb/post-fs-data.d/ by anykernel.sh at flash time.
# KSU runs this on boot in ksu_service context (broader sysfs access than su shell).
# Running manually via "sh /data/adb/..." from Termux may fail nr_requests/read_ahead_kb
# writes with Permission denied due to SELinux — this is expected and not a bug.

# --- I/O Scheduler enforcement ---
# mq-deadline requires CONFIG_SCSI_MQ_DEFAULT=y (blk-mq path for UFS).
# Without it, only single-queue schedulers appear: noop, deadline.
# deadline is acceptable — it is functionally similar to mq-deadline on single-queue.
# After enabling SCSI_MQ_DEFAULT in defconfig, mq-deadline will appear here.
for blkdev in sda sdb sdc sdd sde sdf sdg; do
  SCHED_PATH="/sys/block/${blkdev}/queue/scheduler"
  if [ -f "$SCHED_PATH" ]; then
    if grep -q "mq-deadline" "$SCHED_PATH" 2>/dev/null; then
      echo "mq-deadline" > "$SCHED_PATH" 2>/dev/null
      log -p i -t PitchKernel "iosched: set mq-deadline on /dev/${blkdev}"
    elif grep -q "\bdeadline\b" "$SCHED_PATH" 2>/dev/null; then
      # fallback: single-queue deadline if mq-deadline unavailable
      echo "deadline" > "$SCHED_PATH" 2>/dev/null
      log -p i -t PitchKernel "iosched: set deadline (single-queue fallback) on /dev/${blkdev}"
    else
      AVAIL=$(cat "$SCHED_PATH" 2>/dev/null)
      log -p w -t PitchKernel "iosched: no deadline scheduler on /dev/${blkdev} — available: ${AVAIL}"
    fi
  fi
done

# --- nr_requests — UFS 3.1 deep queue ---
# Note: may fail from Termux su shell (SELinux) but succeeds from KSU boot context.
for blkdev in sda sdd sde sdf; do
  NR_PATH="/sys/block/${blkdev}/queue/nr_requests"
  [ -f "$NR_PATH" ] && echo "256" > "$NR_PATH" 2>/dev/null
done

# --- read_ahead_kb — UFS 3.1 sequential read ---
for blkdev in sda sdd sde sdf; do
  RA_PATH="/sys/block/${blkdev}/queue/read_ahead_kb"
  [ -f "$RA_PATH" ] && echo "512" > "$RA_PATH" 2>/dev/null
done

# --- Schedutil rate_limit_us 500μs ---
for cpu in 0 1 2 3 4 5 6 7; do
  RATE_PATH="/sys/devices/system/cpu/cpu${cpu}/cpufreq/schedutil/rate_limit_us"
  [ -f "$RATE_PATH" ] && echo "500" > "$RATE_PATH" 2>/dev/null
done

# --- hispeed_freq per cluster ---
for cpu in 0 4 7; do
  HISPEED_PATH="/sys/devices/system/cpu/cpu${cpu}/cpufreq/schedutil/hispeed_freq"
  if [ -f "$HISPEED_PATH" ]; then
    case $cpu in
      0) echo "1497600" > "$HISPEED_PATH" 2>/dev/null ;;
      4) echo "1670400" > "$HISPEED_PATH" 2>/dev/null ;;
      7) echo "2419200" > "$HISPEED_PATH" 2>/dev/null ;;
    esac
  fi
done

log -p i -t PitchKernel "tuning applied: deadline enforced, rate_limit_us=500, nr_requests=256, read_ahead_kb=512"
