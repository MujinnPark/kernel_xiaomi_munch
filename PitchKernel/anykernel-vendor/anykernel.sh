# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers
# PitchKernel by Mujinn

## AnyKernel setup
properties() { '
kernel.string=PitchKernel by Mujinn
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=munch
device.name2=munchin
device.name3=
device.name4=
device.name5=
supported.versions=
'; } # end properties

block=/dev/block/bootdevice/by-name/boot;
is_slot_device=1;
ramdisk_compression=auto;

## AnyKernel methods
. tools/ak3-core.sh;

# GUARD: ak3-core.sh was historically truncated at 563/966 lines in a prior
# externally-cloned AnyKernel3 source, which left write_boot(), reset_ak(), and
# SLOT undefined — causing a cryptic "Unable to determine partition. Aborting..."
# failure at flash time. This check produces a clear error message instead of a
# silent abort if the vendored copy ever regresses to a truncated state again.
if ! type write_boot > /dev/null 2>&1; then
  ui_print " ";
  ui_print "  FATAL: write_boot is not defined.";
  ui_print "  ak3-core.sh is truncated (missing write_boot, reset_ak, SLOT).";
  ui_print "  Rebuild the zip — see kernel_xiaomi_munch/PitchKernel/anykernel-vendor/tools/ak3-core.sh";
  exit 1;
fi;

ui_print " ";
ui_print "  PitchKernel by Mujinn";
ui_print " ";

## ROM selection: split-zip model (2026-09-22). Each PitchKernel zip now
## ships exactly one ROM's kernel set at kernels/$os/ (from build.sh's own
## per-ROM output — PitchKernel_AOSP_*.zip or PitchKernel_MIUI_*.zip — no
## longer the old combined kernels/aosp/+kernels/miui/ dual zip). $os is a
## fixed build-time constant substituted into this vendored copy by
## kernel_xiaomi_munch's CI packaging step, not detected at flash time —
## the previous runtime detection (zip-filename match, and before that a
## broken getevent volume-key prompt that never worked reliably under
## TWRP's update-binary shell environment) is removed as dead code now
## that ambiguity no longer exists: one zip, one ROM, known at build time.
os="__PITCHKERNEL_OS__";
ui_print "  Target ROM: $os";
ui_print " ";

## BUG FIX: Move kernel Image and dtb from kernels/$os/ to $AKHOME/ root.
## ak3-core.sh write_boot() searches for Image at $AKHOME/ root.
## Without this mv, write_boot falls through to split_img/kernel (the OLD kernel
## from the current boot partition) and reflashes the old kernel — not PitchKernel.
if [ -f "$AKHOME/kernels/$os/Image" ]; then
  mv "$AKHOME/kernels/$os/Image" "$AKHOME/Image";
  mv "$AKHOME/kernels/$os/dtb"   "$AKHOME/dtb"   2>/dev/null;
  ui_print "  kernel: $os Image loaded";
else
  ui_print "  ERROR: No kernel Image found for $os in this zip!";
  exit 1;
fi;
ui_print " ";

## CPU note: SM8250 prime core (cpu7) has OPP states up to 3187200 kHz.
ui_print "  CPU: prime core OPP table includes up to 3187200 kHz";
ui_print " ";

## Install helper scripts to post-fs-data.d.
mkdir -p /data/adb/post-fs-data.d 2>/dev/null;
## zram resize runs first: least swapped-out data to discard via its
## reset step the earlier in boot it runs (see script's own comments).
cp "$AKHOME"/patch/pitchkernel_zram_resize.sh /data/adb/post-fs-data.d/pitchkernel_zram_resize.sh 2>/dev/null;
chmod 755 /data/adb/post-fs-data.d/pitchkernel_zram_resize.sh 2>/dev/null;
cp "$AKHOME"/patch/pitchkernel_cpufreq.sh /data/adb/post-fs-data.d/pitchkernel_cpufreq.sh 2>/dev/null;
cp "$AKHOME"/patch/pitchkernel_banking_prep.sh /data/adb/post-fs-data.d/pitchkernel_banking_prep.sh 2>/dev/null;
chmod 755 /data/adb/post-fs-data.d/pitchkernel_cpufreq.sh 2>/dev/null;
chmod 755 /data/adb/post-fs-data.d/pitchkernel_banking_prep.sh 2>/dev/null;
## pitchkernel_sepolicy.sh removed 2026-09-20: audited via a live device's
## dmesg (96x "sepol: cmd #N failed" at boot) and found every one of its 61
## allow rules referenced Xiaomi vendor/HyperOS SELinux types
## (vendor_hal_citsensorservice_xiaomi_default, hyperos_cust_feature_resolve_service,
## mcd, misight, etc.) that do not exist in this kernel's compiled policydb --
## a 0% effective-rule rate, not a partial/fixable gap. Script also
## constructed a malformed fake module directory
## (/data/adb/modules/pitchkernel_tuning/, missing module.prop, so never
## visible in the KSU manager's module list) rather than installing via a
## real module, and re-wrote it on every boot. No indication anyone
## verified this ruleset against PitchKernel's actual policy base before
## it was added. Removed rather than repaired: origin/intent unconfirmed,
## zero rules were doing anything, and no functional regression from
## removing something that was already fully inert.
## PitchKernel v3 scheduler/GPU tuning. Named 90-* so it runs after
## pitchkernel_cpufreq.sh (governor default) in most post-fs-data.d
## implementations that sort scripts lexically before exec -- this script
## re-asserts schedutil defensively so ordering isn't load-bearing either
## way, but do not remove the numeric prefix without checking KSU's actual
## post-fs-data.d exec order first (not guaranteed alphabetical on all
## KernelSU/Magisk versions - verify before relying on it).
cp "$AKHOME/patch/pitchkernel_v3_tuning.sh" /data/adb/post-fs-data.d/90-pitchkernel_v3_tuning.sh 2>/dev/null;
chmod 755 /data/adb/post-fs-data.d/90-pitchkernel_v3_tuning.sh 2>/dev/null;
if [ -f /data/adb/post-fs-data.d/pitchkernel_cpufreq.sh ] && [ -f /data/adb/post-fs-data.d/pitchkernel_banking_prep.sh ]; then
  ui_print "  helper scripts installed to post-fs-data.d";
else
  ui_print "  WARNING: could not write helper scripts to post-fs-data.d";
  ui_print "  (KSU/Magisk may not be initialized yet on first flash)";
fi;
if [ ! -f /data/adb/post-fs-data.d/90-pitchkernel_v3_tuning.sh ]; then
  ui_print "  WARNING: could not write v3 tuning script to post-fs-data.d";
fi;
ui_print " ";

## Boot flash
ui_print "  -> installing BOOT";
dump_boot;
write_boot;

## vendor_boot — reset_ak, dump_boot, write_boot
ui_print "  -> installing VENDOR_BOOT";
block=/dev/block/bootdevice/by-name/vendor_boot;
is_slot_device=1;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;

reset_ak;
dump_boot;
write_boot;

ui_print " ";
ui_print "  PitchKernel installed successfully!";
## end install

