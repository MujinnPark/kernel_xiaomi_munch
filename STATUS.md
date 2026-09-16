# STATUS — as of 2026-07-03 audit

This file exists because the root-provider identity has drifted silently
before (see CHANGELOG). Update it every time you deliberately change build
config. If this file disagrees with a comment somewhere else in the repo,
this file is more likely to be right — comments elsewhere have gone stale
without anyone noticing.

## SUSFS: removed entirely (this pass)

SUSFS support has been removed from `pitch_kernel_sm8250` completely, not
just disabled. This includes:

- `fs/susfs.c`, `include/linux/susfs.h`, `include/linux/susfs_def.h` —
  deleted, along with `fs/Makefile`'s `obj-$(CONFIG_KSU_SUSFS)` build rule.
- Every `#ifdef CONFIG_KSU_SUSFS*` call site across the tree (fs/namei.c,
  fs/namespace.c, fs/proc_namespace.c, fs/stat.c, fs/statfs.c, fs/open.c,
  fs/readdir.c, fs/proc/base.c, fs/proc/task_mmu.c, fs/proc/fd.c,
  fs/proc/cmdline.c, fs/notify/fdinfo.c, fs/exec.c, kernel/sys.c,
  kernel/kallsyms.c, kernel/reboot.c, security/selinux/avc.c, mm/memory.c)
  — stripped; where a live `#else` branch existed, that branch is now the
  unconditional code path.
- Two ReSukiSU features that were (incorrectly) gated on `CONFIG_KSU_SUSFS`
  instead of `CONFIG_KSU` — the init.rc read-hook in `fs/read_write.c`
  (`ksu_is_init_rc_hook_enabled` / `ksu_handle_sys_read`) and the
  volume-button input hook in `drivers/input/input.c`
  (`ksu_is_input_hook_enabled` / `ksu_handle_input_handle_event`) — were
  re-gated on `CONFIG_KSU` so they keep working. These are ReSukiSU
  features, not SUSFS features; they were never meant to disappear.
- `build.sh` / `build-miui.sh`: the `SUSFS_ENABLE` axis, the `nosusfs`
  third positional arg, the SUSFS/KernelSU hook fetch-integrity check, and
  the `KSU_SUSFS*` `scripts/config` calls are all gone. `KSU_MANUAL_HOOK`
  is now unconditionally enabled whenever KSU is enabled (it's the only
  hook mechanism left in this tree).
- `build.yml`: the `susfs-only` matrix variant and the `variants` input
  option for it are gone (`nosusfs-only` renamed `resukisu-only`). The
  "Verify SUSFS symbols did not leak in" gate is renamed and simplified to
  "Verify KSU present and no SUSFS symbols leaked in" — it's now a
  permanent regression guard (every `CONFIG_KSU_SUSFS*` symbol must be
  absent, unconditionally) rather than a variant-aware presence/absence
  check. The one-off "DEBUG - snapshot ReSukiSU/SUSFS generated source
  layout" step is removed (its stated purpose, investigating a SUSFS 2.2.0
  backport, no longer applies).
- `PitchKernel/release/telegram.sh`: `SUSFS_ENABLED` env var and the
  `SUSFS_VER`/`SuSFS` caption line are gone; `ROOT_SOLUTION` no longer
  accepts `RESUKISU_NOSUSFS` (collapsed into plain `RESUKISU`).
- The GitHub Release body's `SUSFS:` line is removed.

ReSukiSU itself (the `KernelSU` submodule, `.gitmodules` → 
`https://github.com/ReSukiSU/ReSukiSU`) is untouched and is the only
root/kernel modification remaining in this tree. There is no separate
KernelSU integration anywhere in this repo to remove — `drivers/kernelsu`
is a symlink into the same ReSukiSU submodule, not a second implementation.

**Open risk, not resolved by static analysis:** ReSukiSU's own fetched
source (`kernel/setup.sh`, pulled at build time from
`ReSukiSU/ReSukiSU`) was not available to inspect during this removal —
only its static call sites in this tree were visible. If ReSukiSU's live
hook code calls a `susfs_*` symbol this tree no longer defines, that will
surface as an `undefined symbol` link failure on the next CI run, not
before. Watch the first post-removal build closely.

## Root provider: ReSukiSU (live, confirmed by reading actual build.yml/build.sh)

- `build.yml`: `env.ROOT_PROVIDER = ReSukiSU`, `env.ROOT_SOLUTION_KEY = RESUKISU`
- `apasitu/build.sh` (both `android16-aptusitu` and `android16-aptusitu-new`
  branches, confirmed identical on this point): `KSU_ENABLE=1` path runs
  `curl -LSs https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh | bash`

**This contradicts prior working assumptions that the project had pivoted to
KernelSU-Next.** Whether that pivot happened and got silently reverted, or
never actually landed in this repo, wasn't determined — but the code that
ships today builds ReSukiSU, not KernelSU-Next. If KernelSU-Next is what you
actually want, it hasn't happened yet. Don't act on "we're on KernelSU-Next"
until this file (or a newer audit) says otherwise.

The six ReSukiSU/KernelSU manual hook patches and SELinux export changes
described in prior project notes as "dead/unused" — status not reverified
this pass. If you're on ReSukiSU as this file states, check whether they're
needed before assuming they're still dead code.

## Kernel source branch: pinned to `android16-aptusitu-new` (fixed this pass)

Previously unpinned (`git clone --no-single-branch`, no `-b`), which pulled
whatever AstideLabs' default HEAD branch was — `android16-aptusitu` at audit
time, not `-new`. The two branches differ by ~1.39M lines across 6,597
files. Now explicitly pinned in `build.yml`'s "Clone apasitu kernel source"
step. The resolved branch + short SHA are now surfaced in both the Telegram
artifact message and the GitHub Release body, so drift shows up automatically
instead of requiring someone to notice.

## baseband_guard: present, unconditional, mechanism corrected

`vc-teahouse/Baseband-guard` is integrated in `apasitu/build.sh` before the
`KSU_ENABLE` check — it's compiled into every build regardless of the `ksu`
input. Its actual behavior (read from source, not assumed): it hooks
`file_permission` / `file_ioctl` / `inode_rename` / `inode_symlink` /
`inode_setattr` and blocks **writes to protected block devices** for
processes whose creds ever passed through an `su`/`magisk`/`ksu` SELinux
domain. It has no code path that sends a signal to a process. It cannot and
does not kill `vendor.atfwd` or anything else — an earlier analysis pass
claimed otherwise without reading the source first; that claim was wrong and
is retracted here.

## `vendor.atfwd` crash loop: cause not yet identified

Confirmed from one dmesg/logcat capture: this daemon dies on signal 31
(SIGSYS) roughly every 5 seconds, for the full ~30-minute capture window,
signal delivered synchronously (process to itself) — the standard signature
of a seccomp-bpf syscall trap, not an external kill. Not linked to
baseband_guard (see above — mechanism doesn't support it). Not confirmed to
be kernel-caused at all. Needs a controlled comparison (same ROM, stock or
known-working kernel, same daemon, does it also SIGSYS) before spending any
engineering time patching kernel code over it.

## `module/` directory: orphaned

`module/module.prop` + `module/post-fs-data.sh` exist but are not referenced
by `build.yml` or anything under `PitchKernel/`. Never packaged, never
shipped. `post-fs-data.sh`'s own comments say it's meant as a fallback if
the AnyKernel-installed script is missing — but since it's never zipped into
anything, no user's device has this file, so the fallback never runs either.
Decide: wire it into packaging, or delete it. Leaving it as-is guarantees
someone eventually assumes it's active when it isn't.
