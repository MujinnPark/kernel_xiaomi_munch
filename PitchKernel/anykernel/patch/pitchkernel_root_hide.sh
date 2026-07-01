#!/system/bin/sh
# PitchKernel root-hiding helper for banking apps
# Installed by AnyKernel3 to post-fs-data.d so it runs after boot.

sleep "${PITCHKERNEL_HIDE_DELAY:-10}"

hide_apps="
com.touchngo.android
com.maybank.maybankmobile.my
com.cimbmalaysia.mobile.android
com.google.android.apps.nbu.files
"

if [ -x /system/bin/ksu_susfs ]; then
  for pkg in $hide_apps; do
    /system/bin/ksu_susfs hide -p "$pkg" 2>/dev/null || true
    am force-stop "$pkg" 2>/dev/null || true
    pm clear "$pkg" 2>/dev/null || true
  done
fi

# Best effort: keep the helper harmless if the device does not expose KSU/SUSFS.
exit 0
