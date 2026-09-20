#!/system/bin/sh
# PitchKernel zram resize — 4096 MiB (stock fstab default) -> 6144 MiB (6GB)
#
# WHY THIS EXISTS: zram0's size is set by the ROM's fstab (zramsize= mount
# option), not by this kernel tree -- pitch_kernel_sm8250 has no zram DT
# node or Kconfig size setting, only CONFIG_ZRAM (feature on/off).
# Confirmed via full grep of both pitch_kernel_sm8250 and kernel_xiaomi_munch,
# 2026-09-20: no fstab, no zramsize reference, no script anywhere in either
# repo sets a size. Live device confirmed at 4294967296 bytes (4096 MiB)
# via /sys/block/zram0/disksize before this script existed.
#
# MECHANISM: resizing an active zram device is not a plain sysfs write.
# The kernel zram driver refuses to change disksize while the device has
# any holder (mounted, or active as swap) -- see drivers/block/zram/zram_drv.c,
# disksize_store(): returns -EBUSY if init_done()/any holder present.
# Must: swapoff -> reset -> set new disksize -> mkswap -> swapon, in that
# order. Idempotent: safe whether or not zram0 is already active as swap
# by the time post-fs-data.d runs (checked at runtime, not assumed).
#
# RESET SIDE EFFECT: `echo 1 > reset` discards all currently-swapped-out
# pages. This runs in post-fs-data, before most of the system has started
# swapping meaningfully, so the cost is expected to be minor -- but it is
# a real discard, not a no-op, each boot.
#
# ORDERING CAVEAT (not fully verified against this ROM's init): if
# Android's own fstab-driven swapon runs AFTER post-fs-data.d rather than
# before, this script's own swapon call may race a later init swapon.
# Expected to be harmless (swapon on an already-active device just fails
# quietly) but has not been empirically confirmed on this exact ROM/init.
# Verify /proc/swaps shows a single correct-sized zram0 entry after boot.

LOG_TAG="PitchKernel"
ZRAM_DEV="/sys/block/zram0"
NEW_SIZE_BYTES=6442450944   # 6 * 1024 * 1024 * 1024 -- 6144 MiB / 6GB
TARGET_MIB=6144

if [ ! -d "$ZRAM_DEV" ]; then
    log -p w -t "$LOG_TAG" "zram: $ZRAM_DEV not present, skipping resize"
    exit 0
fi

CURRENT_SIZE=$(cat "$ZRAM_DEV/disksize" 2>/dev/null)
log -p i -t "$LOG_TAG" "zram: current disksize=${CURRENT_SIZE:-unknown} bytes, target=${NEW_SIZE_BYTES} bytes (${TARGET_MIB} MiB)"

if [ "$CURRENT_SIZE" = "$NEW_SIZE_BYTES" ]; then
    log -p i -t "$LOG_TAG" "zram: already at target size, nothing to do"
    exit 0
fi

# --- Step 1: swapoff if currently active as swap ---
if grep -q "^/dev/block/zram0" /proc/swaps 2>/dev/null; then
    log -p i -t "$LOG_TAG" "zram: currently active as swap, swapping off before resize"
    swapoff /dev/block/zram0 2>/dev/null
    if grep -q "^/dev/block/zram0" /proc/swaps 2>/dev/null; then
        log -p e -t "$LOG_TAG" "zram: swapoff failed, zram0 still in /proc/swaps -- aborting resize, leaving at ${CURRENT_SIZE:-unknown} bytes"
        exit 1
    fi
    log -p i -t "$LOG_TAG" "zram: swapoff OK"
else
    log -p i -t "$LOG_TAG" "zram: not currently active as swap"
fi

# --- Step 2: preserve current comp_algorithm choice before reset ---
CURRENT_ALGO=$(sed -n 's/.*\[\([a-z0-9_-]*\)\].*/\1/p' "$ZRAM_DEV/comp_algorithm" 2>/dev/null)
log -p i -t "$LOG_TAG" "zram: preserving comp_algorithm=${CURRENT_ALGO:-lz4 (default, could not detect)}"

# --- Step 3: reset the device (required before disksize can change) ---
echo 1 > "$ZRAM_DEV/reset" 2>/dev/null
RESET_RESULT=$?
if [ "$RESET_RESULT" -ne 0 ]; then
    log -p e -t "$LOG_TAG" "zram: reset write failed (exit ${RESET_RESULT}) -- aborting resize, leaving at ${CURRENT_SIZE:-unknown} bytes"
    exit 1
fi

# --- Step 4: re-apply comp_algorithm (reset can clear it on some drivers) ---
if [ -n "$CURRENT_ALGO" ]; then
    echo "$CURRENT_ALGO" > "$ZRAM_DEV/comp_algorithm" 2>/dev/null
fi

# --- Step 5: set new disksize ---
echo "$NEW_SIZE_BYTES" > "$ZRAM_DEV/disksize" 2>/dev/null
READBACK=$(cat "$ZRAM_DEV/disksize" 2>/dev/null)
if [ "$READBACK" != "$NEW_SIZE_BYTES" ]; then
    log -p e -t "$LOG_TAG" "zram: disksize write failed -- wrote ${NEW_SIZE_BYTES}, reads back '${READBACK}'"
    exit 1
fi
log -p i -t "$LOG_TAG" "zram: disksize set OK, readback=${READBACK} bytes"

# --- Step 6: mkswap + swapon ---
if command -v mkswap >/dev/null 2>&1; then
    mkswap /dev/block/zram0 2>/dev/null
    MKSWAP_RESULT=$?
    if [ "$MKSWAP_RESULT" -ne 0 ]; then
        log -p e -t "$LOG_TAG" "zram: mkswap failed (exit ${MKSWAP_RESULT}) -- device resized to ${TARGET_MIB} MiB but NOT re-enabled as swap"
        exit 1
    fi
    swapon /dev/block/zram0 2>/dev/null
    SWAPON_RESULT=$?
    if [ "$SWAPON_RESULT" -ne 0 ]; then
        log -p e -t "$LOG_TAG" "zram: swapon failed (exit ${SWAPON_RESULT}) -- device resized to ${TARGET_MIB} MiB but NOT active as swap"
        exit 1
    fi
    log -p i -t "$LOG_TAG" "zram: mkswap + swapon OK, active at ${TARGET_MIB} MiB"
else
    log -p w -t "$LOG_TAG" "zram: mkswap not found in PATH -- device resized to ${TARGET_MIB} MiB but swapon not attempted. If Android's own init normally handles swapon for zram0, it should still pick this up; verify with /proc/swaps."
fi

log -p i -t "$LOG_TAG" "zram: resize complete, ${CURRENT_SIZE:-unknown} -> ${READBACK} bytes"
