## Install helper scripts to post-fs-data.d.
mkdir -p /data/adb/post-fs-data.d 2>/dev/null;
cp "$AKHOME"/patch/pitchkernel_cpufreq.sh /data/adb/post-fs-data.d/pitchkernel_cpufreq.sh 2>/dev/null;
cp "$AKHOME"/patch/pitchkernel_root_hide.sh /data/adb/post-fs-data.d/pitchkernel_root_hide.sh 2>/dev/null;
chmod 755 /data/adb/post-fs-data.d/pitchkernel_cpufreq.sh 2>/dev/null;
chmod 755 /data/adb/post-fs-data.d/pitchkernel_root_hide.sh 2>/dev/null;
if [ -f /data/adb/post-fs-data.d/pitchkernel_cpufreq.sh ] && [ -f /data/adb/post-fs-data.d/pitchkernel_root_hide.sh ]; then
  ui_print "  helper scripts installed to post-fs-data.d";
else
  ui_print "  WARNING: could not write helper scripts to post-fs-data.d";
  ui_print "  (KSU/Magisk may not be initialized yet on first flash)";
fi;
ui_print " ";
