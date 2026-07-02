# STATUS — as of 2026-07-03 audit

This file exists because the root-provider identity has drifted silently
before (see CHANGELOG). Update it every time you deliberately change build
config. If this file disagrees with a comment somewhere else in the repo,
this file is more likely to be right — comments elsewhere have gone stale
without anyone noticing.

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
