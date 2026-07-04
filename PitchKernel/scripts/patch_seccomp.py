import sys, re

path = sys.argv[1]
func = sys.argv[2]

with open(path) as f:
    c = f.read()

if "PitchKernel: bypass BPF seccomp for gettid" in c:
    print("Already patched")
    sys.exit(0)

pat = r'((?:static\s+)?(?:u32|int)\s+' + re.escape(func) + r'\s*\([^)]+\)\s*\{)'
m = re.search(pat, c, re.MULTILINE)
if not m:
    print("ERROR: function " + func + " not found")
    sys.exit(1)

bypass = (
    "\n\t/* PitchKernel: bypass BPF seccomp for gettid NR 178 ARM64.\n"
    "\t * gettid not in 4.19 vDSO; ATFWD BPF filter blocks it -> SIGSYS.\n"
    "\t * Stock MIUI has CONFIG_SECCOMP=n so filter never enforced there. */\n"
    "\tif (unlikely(syscall_nr == __NR_gettid))\n"
    "\t\treturn 0;\n"
)

c = c[:m.end()] + bypass + c[m.end():]
with open(path, "w") as f:
    f.write(c)
print("Patched " + func + " in " + path)
