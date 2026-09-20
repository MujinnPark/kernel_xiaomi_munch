# CHANGELOG

Chronological record of real bugs found and fixed in this pipeline. Kept so
"has this already been fixed" has a checkable answer instead of relying on
memory — this project has an automated contributor with commit access that
has reintroduced previously-fixed bugs at least once (the `build.yml`
boolean comparison bug, 3+ times). Check here before re-fixing something
that might already be marked done, and check here before assuming something
is done that might have regressed.

## 2026-09-20 — ReSukiSU v4.2.0-rc2 update, non-GKI signature/stub fixes, CI pin guard, sepolicy cleanup, zram resize, cpufreq race fix

- **Fixed**: KernelSU submodule (ReSukiSU) updated from pinned commit
  `b2ac2fc8` (v4.1.0-era) to a fork of `v4.2.0-rc2` (`3576e6a5`), fork at
  `MujinnPark/ReSukiSU`, branch `pitch-munch-4.19-fix`.
- **Root cause found**: after the above update, the manager app kept
  reporting the old driver version despite a correct submodule gitlink.
  Traced to `build.sh`'s `RESUKISU_REF` -- a second, independent hardcoded
  commit pin (separate from `.gitmodules`/the submodule gitlink) that
  upstream's own `setup.sh` uses to `git checkout` *inside* the
  already-correctly-populated submodule, silently overwriting it every
  build. `RESUKISU_REF` was never updated when the submodule was. Ground-
  truthed via `strings` on the compiled `Image` binary, not inferred.
  Recurred 2 more times later in this same pass (pin bumped a commit late
  after each follow-up fix commit) before being caught as a pattern.
- **Fixed**: `ksu_handle_faccessat`/`ksu_handle_stat` signature mismatch --
  upstream commit 03b60f26 changed `ksu_handle_faccessat`'s
  `CONFIG_KSU_SUSFS` signature from `(const char __user **)` to
  `(struct filename **)` unconditionally, no version guard. This tree's
  non-GKI 4.19 `fs/open.c` still calls the old signature (confirmed via
  direct grep of `fs/open.c:363,484`), causing a `conflicting types` build
  error. Reverted `ksu_handle_faccessat` to the old signature
  unconditionally (no non-GKI caller for the new one exists);
  `ksu_handle_stat` kept correctly version-guarded. Matches a validated,
  hardware-tested reference fix at
  `github.com/KeiraOMG0/ReSukiSU@fb827bef` (confirmed booting on a
  separate real 4.19.325 non-GKI device). See ReSukiSU/ReSukiSU#387.
- **Fixed, and corrects an earlier bug in this same pass**: an initial fix
  for the above stubbed `is_zygote_next()`/`is_isolated_process()` in
  `setuid_hook.c` on the assumption they were missing from this tree's
  SUSFS 2.3.0 backport. That diagnosis was wrong: `is_isolated_process` was
  already unconditionally defined in `policy/allowlist.h` (already
  included); `is_zygote_next` was already correctly declared/defined by
  upstream itself, gated identically to this build's config -- the actual
  gap was a missing `#include "selinux/selinux.h"` in `setuid_hook.c`.
  The stub caused a `redefinition` build error, and separately would have
  been a live correctness bug if it had shipped: forcing
  `is_zygote_next()` to always return `false` silently disables
  zygote-isolated-service umount handling under `CONFIG_KSU_SUSFS=y`, even
  though the real implementation works correctly. Fixed: stubs removed,
  missing include added.
- **Fixed**: `build-miui.sh`'s call to upstream `setup.sh` passed no
  `$1` argument at all (`build.sh`'s equivalent call correctly passes
  `-s "$RESUKISU_REF"`) -- meaning any MIUI-variant build would check out
  upstream's live, unpinned, unreviewed `main` branch on every run.
  Confirmed via `build.yml` that `build-miui.sh` is not currently wired
  into packaging (`script` input only offers `build.sh`), so this had zero
  live blast radius at time of fix -- closed before it could become one.
- **Fixed**: "SUSFS support has been removed entirely" claims, stale since
  an earlier (2026-07-03-adjacent) removal pass that predates this
  session -- SUSFS 2.3.0 has since been re-added and is confirmed live
  (every `CONFIG_KSU_SUSFS*` symbol present and `=y`, manager app reports
  `SuSFS Version: v2.3.0` on a booted device). Corrected in `build.sh` (3
  locations), `build-miui.sh` (1), `build.yml` (2), `README.md` (1).
  `STATUS.md`'s original "SUSFS: removed entirely" section preserved as
  historical record with an appended dated correction, per this file's own
  "update, don't rewrite" convention.
- **Added**: new CI step `Guard ReSukiSU pin consistency`, placed right
  after the kernel source clone, before any expensive build work. Hard-
  fails in seconds if `build.sh`'s `RESUKISU_REF`, `build-miui.sh`'s
  `RESUKISU_REF`, and the actual checked-out `KernelSU` submodule HEAD
  don't all agree -- the exact class of mismatch that cost 3 separate full
  CI build cycles earlier in this same pass before being caught. Also
  warns (does not fail) if the pin is behind the fork branch's live tip,
  since intentionally pinning behind the tip is legitimate. Verified via a
  real passing CI run, not just YAML validity.
- **Fixed**: fork (`MujinnPark/ReSukiSU`) had zero git tags at all --
  forking doesn't automatically carry tags, and this was never noticed.
  `kernel/Kbuild`'s `KSU_TAG_NAME` computation
  (`git describe --abbrev=0 --tags || echo "v4.1.0"`) was silently
  falling through to its hardcoded `v4.1.0` fallback on every build,
  which is why the manager app kept showing `v4.1.0-<hash>` instead of
  `v4.2.0-rc2-<hash>` even after the correct commit was building. Fixed by
  tagging the fork's `v4.2.0-rc2` at the same commit upstream has it.
  Verified: `git describe --abbrev=0 --tags` now resolves correctly, and
  the live device's `dmesg` confirms `full_version: v4.2.0-rc2-<hash>`.
- **Removed**: `pitchkernel_sepolicy.sh` (a `post-fs-data.d` script,
  packaged via `PitchKernel/anykernel-vendor/patch/`). Audited via live
  device `dmesg` after an unrelated fix: 96x `sepol: cmd #N failed` lines
  at every boot, all 61 of the script's `allow` rules referencing Xiaomi
  vendor/HyperOS SELinux types (`vendor_hal_citsensorservice_xiaomi_default`,
  `hal_misight_default`, `mcd`, `misight`,
  `hyperos_cust_feature_resolve_service`, etc.) absent from this kernel's
  compiled policydb -- a 0% effective-rule rate. The script also installed
  itself incorrectly: manually `mkdir`'d a fake
  `/data/adb/modules/pitchkernel_tuning/` module directory with no
  `module.prop` (never visible in the KSU manager's module list),
  rewritten world-writable on every single boot for zero functional
  effect, and ran the same 61 rules through three redundant mechanisms
  (`sepolicy.rule` auto-load, `ksud sepolicy patch`, `magiskpolicy
  --live`) that all failed identically. No record found of anyone
  verifying this ruleset against PitchKernel's actual policy base before
  it was added; origin/intent could not be confirmed. Removed rather than
  repaired. Verified post-removal on a live rebuild: 0 `sepol: cmd failed`
  lines, confirming this was the sole source.
- **Added**: `pitchkernel_zram_resize.sh` -- resizes zram0 from the stock
  ROM fstab's 4096 MiB to 6144 MiB (6GB) at boot. zram size is set by the
  ROM's fstab, not by this kernel tree (confirmed via full grep of both
  repos: no fstab, no `zramsize` reference, no size-setting script
  anywhere). Handles the real constraint that `disksize` can't be changed
  while zram0 has any holder: `swapoff` -> `reset` -> set `disksize` ->
  `mkswap` -> `swapon`, each step verified via readback, idempotent,
  preserves the current `comp_algorithm` across reset. Verified live:
  `disksize` reads `6442450944`, `/proc/swaps` shows a single correctly-
  sized `zram0` entry, no duplicate/race entries observed.
- **Fixed**: `pitchkernel_cpufreq.sh`'s `nr_requests` and `hispeed_freq`
  writes were silently failing at `post-fs-data.d` time on live hardware
  -- the I/O scheduler (`deadline`) write in the same script worked fine,
  but `nr_requests` stayed at stock `128` and all three `hispeed_freq`
  clusters stayed at stock values, despite the script's own readback
  check for `nr_requests` correctly detecting and logging the failure (it
  was just never acted on). Root-caused via live PSI/loadavg
  investigation of a separate "lags during multitasking/video calls"
  report: CPU PSI showed real stall pressure (`some avg10=20.10`) while
  cpu7 sat at 1305600 kHz instead of its intended 2419200 kHz hispeed
  target. Ruled out SELinux (zero relevant `avc: denied` lines). Confirmed
  via manual `su -c "echo ... > path"` immediately post-boot that the
  identical writes succeed instantly and stick -- a boot-timing race, not
  a permissions or path problem; these specific sysfs nodes are not yet
  writable at the point `post-fs-data.d` scripts run, even though the I/O
  scheduler selector on the same block device already is. Fixed with a
  bounded retry+verify wrapper (5 attempts, 1s apart) applied uniformly
  to every write in the script, including `rate_limit_us`, which
  previously had zero verification at all and was likely suffering the
  same race with no visibility. Verified live post-fix: `nr_requests`,
  all three `hispeed_freq` clusters, correct on a fresh boot.
- **Investigated, not a bug**: `rate_limit_us` at
  `/sys/devices/system/cpu/cpu7/cpufreq/schedutil/rate_limit_us` does not
  exist on this device/kernel at all (`cat` returns "No such file or
  directory" consistently). The script's own `[ -f "$RATE_PATH" ]` guard
  correctly and silently skips it -- not a regression, not new behavior
  from this pass's changes, just genuinely absent on this SoC/kernel
  version's `schedutil` implementation.
- **Investigated, not a kernel bug**: root cause of the multitasking/
  video-call lag report above is CPU oversubscription (`loadavg` at
  time of report: `8.32` runnable/uninterruptible on an 8-core device,
  i.e. at or above total core count), not a governor misconfiguration --
  the `hispeed_freq` fix should help (cores ramp faster when load spikes)
  but cannot fully resolve "more concurrent runnable work than cores can
  serve," which is a workload problem, not a tuning problem. Memory ruled
  out separately: `MemAvailable` and memory PSI were both healthy at the
  same moment.

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
