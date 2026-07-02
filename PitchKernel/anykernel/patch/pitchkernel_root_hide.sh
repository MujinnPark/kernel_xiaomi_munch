#!/system/bin/sh
# PitchKernel root-hiding helper for banking apps
# Installed by AnyKernel3 to post-fs-data.d so it runs after boot.
#
# ============================================================================
# UNVERIFIED — READ BEFORE RE-ENABLING
# ============================================================================
# The previous version of this script called:
#   /system/bin/ksu_susfs hide -p "$pkg"
# That command was never confirmed against real SUSFS documentation or
# `ksu_susfs --help` output. It was guessed. The known real susfs4ksu
# userspace tool is called `ksu_susfs`, but its actual subcommands
# (add_sus_path, add_sus_mount, add_sus_kstat, set_uname, etc.) do not
# obviously include a "hide -p <package>" verb. Because the `-x` check
# below almost certainly always failed (the binary likely isn't at that
# path, or doesn't take those args even if it is), this script has been
# running as a silent no-op — which is exactly why nobody caught it.
#
# Two real options, do one of them before trusting this again:
#   1. Check ReSukiSU's manager app for a native per-app hide-list /
#      profile feature. If it has one (most SukiSU-family managers do),
#      use that instead of scripting an unverified CLI — it's what
#      the susfs kernel side actually expects to be driven by.
#   2. If you need it done at boot without the manager, find the real
#      ksu_susfs CLI syntax from the susfs4ksu source
#      (build_ksu_susfs_tool.sh output, or the project's own docs) and
#      replace the command below with the confirmed one.
#
# Until one of those is done, this script force-stops the listed apps
# on boot (harmless, resets their root-detection cache) but does NOT
# attempt any susfs hide call — a script that silently does nothing
# useful is worse than one that's honestly disabled, because it hides
# the fact that hiding isn't actually happening.
# ============================================================================

sleep "${PITCHKERNEL_HIDE_DELAY:-10}"

hide_apps="
com.touchngo.android
com.maybank.maybankmobile.my
com.cimbmalaysia.mobile.android
com.google.android.apps.nbu.files
"

# NOTE: intentionally NOT calling `pm clear` here. Clearing app data on every
# boot wipes saved logins/sessions for banking apps every reboot — that's a
# destructive side effect no user asked for. force-stop is enough to make the
# app re-evaluate root state on next launch without nuking its data.
for pkg in $hide_apps; do
  am force-stop "$pkg" 2>/dev/null || true
done

log -p w -t PitchKernel "root_hide: force-stop applied to banking apps; susfs hide call is DISABLED pending verified ksu_susfs syntax — see script header"

exit 0
