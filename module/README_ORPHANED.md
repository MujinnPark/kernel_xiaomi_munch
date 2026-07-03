# module/ — ORPHANED, NOT SHIPPED

This directory (`module.prop` + `post-fs-data.sh`) is **never packaged or shipped**
by `build.yml`. No user device has these files. The fallback logic in
`post-fs-data.sh` never runs.

## Decision required

Pick one:

**Option A — Delete it:**
```sh
git rm -r module/
git commit -m "chore: remove orphaned module/ — never packaged, never shipped"
```

**Option B — Wire it into packaging:**
Add a Magisk/KSU module zip step to `build.yml`'s "Package zip" step and a
second `upload-artifact` entry. Then it becomes a real fallback that actually ships.

Leaving it as-is means whoever touches this repo next will assume it's active.
That assumption will be wrong. Don't leave it as-is.
