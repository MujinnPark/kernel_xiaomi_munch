### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers

### AnyKernel setup
# global properties
properties() { '
kernel.string=APTKernel by ApartTUSITU @ AstideLabs
do.devicecheck=0
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=alioth
device.name2=aliothin
device.name3=apollo
device.name4=apolloin
device.name5=lmi
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties


### AnyKernel install

# boot shell variables
BLOCK=boot;
IS_SLOT_DEVICE=auto;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

NO_BLOCK_DISPLAY=1

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

## Select the correct image to flash
userflavor="$(file_getprop /system/build.prop "ro.build.flavor")";
case "$userflavor" in
    missi*|qssi*) os="miui"; os_string="MIUI ROM";;
    *) os="aosp"; os_string="AOSP ROM";;
esac;
ui_print "  -> $os_string is detected!";
if [ -f $AKHOME/kernels/$os/Image ] && [ -f $AKHOME/kernels/$os/dtb ] && [ -f $AKHOME/kernels/$os/dtbo.img ]; then
    mv $AKHOME/kernels/$os/Image $AKHOME/Image;
    mv $AKHOME/kernels/$os/dtb $AKHOME/dtb;
    #mv $AKHOME/kernels/$os/dtbo.img $AKHOME/dtbo.img; # uncomment this
else
    ui_print "  -> There is no kernel for $os_string in this zip! Aborting...";
    ui_print "  -> Please check that you have the correct kernel zip!";
    exit 1;
fi;
ui_print "  -> Flashing DTBO is not recommended by default.";
ui_print "  -> If you need to flash them, please uncomment the code in the script.";

## CPU Frequency Profile Selector
# Flash-time only — no live in-Android toggle. To switch profiles, reflash
# after creating/removing the marker file below.
#
# To select Overclock (cpu7 prime core max 3187200kHz — verified single-core
# boost bin on this device's real OPP table):
#   create an empty file at /sdcard/pitchkernel_overclock before flashing.
# Default (no marker file present) is Stable (cpu7 max 2553600kHz).
#
# cpu4 cluster is intentionally left at kernel default in both profiles —
# this was an explicit decision, not an oversight.
if [ -f /sdcard/pitchkernel_overclock ]; then
    cpu_profile="overclock";
    ui_print "  -> CPU Profile: OVERCLOCK (cpu7 max 3187200kHz)";
else
    cpu_profile="stable";
    ui_print "  -> CPU Profile: STABLE (cpu7 max 2553600kHz)";
fi;
ui_print "  -> To change profile later, reflash this zip after creating or";
ui_print "     removing /sdcard/pitchkernel_overclock";

# boot install
split_boot;

## Inject CPU profile script into ramdisk
unpack_ramdisk;
mkdir -p $RAMDISK/system/bin;
# Bake the selected profile directly into the script at flash time rather
# than writing a separate /data marker file — /data is not a mounted,
# writable partition during ramdisk patching in recovery, so writing there
# at this stage would silently fail. sed substitutes the placeholder default
# in the script with the actual selection made above.
sed "s/^PROFILE=\"stable\"\$/PROFILE=\"$cpu_profile\"/" $AKHOME/patch/pitchkernel_cpufreq.sh > $RAMDISK/system/bin/pitchkernel_cpufreq.sh;
set_perm 0 2000 0755 $RAMDISK/system/bin/pitchkernel_cpufreq.sh;
append_file $RAMDISK/init.rc 'pitchkernel_cpufreq' pitchkernel_init.rc;
insert_file $RAMDISK/init.rc 'start pitchkernel_cpufreq' after 'on post-fs-data' pitchkernel_start.rc;
repack_ramdisk;

flash_boot;
#flash_dtbo; # uncomment this
## end boot install
