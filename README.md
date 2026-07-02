# PitchKernel — munch (Poco F4 / Redmi K40S)

Custom Android kernel CI pipeline for SM8250, kernel 4.19.x, non-GKI.
This repo is the CI wrapper + AnyKernel3 overlay. The actual kernel source
is cloned fresh on every build from `AstideLabs/android_kernel_xiaomi_sm8250`
— nothing here compiles standalone.

## Repo layout

```
.github/workflows/
  build.yml     — clones kernel source, builds, packages AK3 zip, ships to
                   Telegram + GitHub Releases
  notify.yml    — commit push / build result notifications
PitchKernel/
  anykernel/    — AK3 overlay (anykernel.sh + helper scripts), copied over
                   the freshly-cloned AnyKernel3 fork at build time
  release/      — telegram.sh, sourced by build.yml to ship the artifact
module/         — standalone KSU/Magisk module (module.prop + post-fs-data.sh).
                  ORPHANED: not referenced anywhere in build.yml, never zipped,
                  never shipped. Either wire it into the packaging step or
                  delete it — right now it's dead weight that looks live.
STATUS.md       — ground truth as of the last full audit: what's actually
                   building, what's actually shipping, what's unverified.
                   Read this before trusting any comment elsewhere that
                   claims to know current state — several have gone stale
                   before.
CHANGELOG.md    — bugs found and fixed, chronologically, so "was this already
                   fixed once" has an answer that isn't "check with Syed."
```

## Build

Manual dispatch only (`workflow_dispatch`). Inputs:
- `script`: only `build.sh` (AOSP+MIUI dual zip) is wired into packaging.
  `build-miui.sh` exists upstream but this pipeline doesn't use it.
- `ksu`: enables the current root provider (see STATUS.md for which one
  that actually is right now) + SUSFS.

## Known open issues (not fixed in this pass — need real device/log evidence)

- **`vendor.atfwd` (ATFWD-daemon) crash-loops on signal 31 (SIGSYS) every
  ~5s** in the one dmesg/logcat capture audited so far. Signal delivered
  synchronously to itself — consistent with a seccomp-bpf syscall-filter
  trap, i.e. the vendor binary hitting a syscall the seccomp policy for its
  domain doesn't allow. Not confirmed to be kernel-caused. Needs: a diff of
  the syscall table / seccomp policy against a known-working (stock or
  other custom) kernel on the same device before touching any code over it.
- **baseband_guard is compiled into every build unconditionally**, gated on
  neither `ksu` input nor anything else (`apasitu/build.sh` runs the
  Baseband-guard setup script before the `KSU_ENABLE` branch). If you don't
  want it on non-root builds, that's a real gap to close upstream in
  `build.sh`, not something this repo controls.
