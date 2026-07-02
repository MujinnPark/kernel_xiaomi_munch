# CHANGELOG

Chronological record of real bugs found and fixed in this pipeline. Kept so
"has this already been fixed" has a checkable answer instead of relying on
memory — this project has an automated contributor with commit access that
has reintroduced previously-fixed bugs at least once (the `build.yml`
boolean comparison bug, 3+ times). Check here before re-fixing something
that might already be marked done, and check here before assuming something
is done that might have regressed.

## 2026-07-03 — CI branch pin + Telegram/release visibility

- **Fixed**: `build.yml` cloned `AstideLabs/android_kernel_xiaomi_sm8250`
  with `--no-single-branch` and no `-b` flag, silently pulling whatever the
  default HEAD branch was (`android16-aptusitu`) instead of the intended
  `android16-aptusitu-new`. The two branches differ by ~1.39M lines / 6,597
  files. No build error resulted either way — both branches build
  successfully — so this could have been silently wrong for an unknown
  number of releases. Now pinned explicitly with `--single-branch -b`.
- **Fixed**: Telegram artifact message and GitHub Release body both
  hardcoded `KERNEL_BRANCH: "default (apasitu)"`, which conveyed no real
  information and could never have surfaced the branch-mismatch bug above.
  Now populated from the actual resolved branch + short SHA of the clone
  that produced that specific build.
- **Retracted claim**: an earlier analysis pass asserted `baseband_guard`
  was killing `vendor.atfwd` via signal delivery. Read the actual
  `vc-teahouse/Baseband-guard` source — it only gates block-device writes
  via LSM hooks and has no signal-sending code path. That claim was wrong
  and unverified when made; see STATUS.md for the corrected mechanism and
  the still-open question of what's actually killing that daemon (signal 31
  self-delivered — looks like a seccomp trap, not confirmed).
- **Documented, not fixed**: root provider is confirmed live as ReSukiSU
  (`build.yml` + `apasitu/build.sh` on both branches agree), which
  contradicts a prior working assumption of a KernelSU-Next pivot. Not
  resolved — flagged in STATUS.md so it doesn't get asserted as fact again
  without re-checking the actual shipping config.
- **Documented, not fixed**: `module/` directory (`module.prop` +
  `post-fs-data.sh`) is not referenced anywhere in `build.yml` or
  `PitchKernel/` — dead code that's never packaged or shipped.

## Prior fixes (carried forward from project history)

- `build.yml` boolean comparison: `inputs.ksu == 'true'` type mismatch —
  reintroduced at least 3× by automated contributor. Current state (this
  pass): all six usages in `build.yml` use the correct quoted-string
  comparison pattern. Re-verify after any commit from the automated
  contributor.
- Wrong AnyKernel3 fork URL in `build.sh` — fixed via sed step in
  `build.yml` ("Point AnyKernel3 to PitchKernel fork").
- BBR TCP congestion control targeting wrong defconfig file — fixed.
- `build.sh` MIUI section deleting `anykernel/kernels/aosp/` after AOSP
  build — worked around via the AOSP/MIUI zip extraction step in
  `build.yml`'s "Package zip" step, which pulls each OS's Image/dtb/dtbo
  from its own source zip rather than relying on both surviving in one
  build directory.
- Missing "notify build started" step — present in current `build.yml`.
- `$home` vs `$AKHOME` variable mismatch in `anykernel.sh` — fixed, uses
  `$AKHOME` consistently, with an explicit comment explaining why the `mv`
  from `kernels/$os/` to `$AKHOME/` root is required.
- `tools/ak3-core.sh` truncated at line 535/966 (bad GitHub upload on the
  MujinnPark/AnyKernel3 fork) — two independent guards now exist: a
  `wc -l` + `bash -n` check in `build.yml` ("Verify ak3-core.sh is
  complete"), and a runtime `type write_boot` check in `anykernel.sh` that
  fails the flash with a clear message instead of the old cryptic
  "Unable to determine partition" error.
- Ramdisk injection causing bootloop on boot header v3 — fixed by matching
  Perf+ kernel's approach: `dump_boot; write_boot;` with no ramdisk
  modification, applied identically to both `boot` and `vendor_boot` in
  `anykernel.sh`.
- `pitchkernel_root_hide.sh` was calling an unverified `ksu_susfs hide -p`
  command that was never confirmed against real susfs4ksu CLI syntax —
  script was a silent no-op. Now explicitly disabled with a header
  explaining why, force-stops the target apps only (harmless), and logs
  that the susfs hide call is pending verified syntax.
- Dual-zip Stable/Overclock architecture collapsed back to a single zip
  after dmesg confirmed the SM8250 prime-core frequency split was
  meaningless on this kernel (hardware ceiling enforced by
  `qcom_cpufreq_hw_read_lut`, not software-adjustable).
