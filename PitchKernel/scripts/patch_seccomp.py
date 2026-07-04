import sys, re

path = sys.argv[1]
func = sys.argv[2]

with open(path) as f:
    c = f.read()

if "PitchKernel: bypass BPF seccomp for gettid" in c:
    print("Already patched")
    sys.exit(0)

# seccomp_run_filters(const struct seccomp_data *sd, struct seccomp_filter **match)
# The syscall number is at sd->nr, not a direct parameter.
# Find the function and inject after opening brace, before first statement.

pat = r'((?:static\s+)?(?:u32|int)\s+' + re.escape(func) + r'\s*\([^)]+\)\s*\{)'
m = re.search(pat, c, re.MULTILINE)
if not m:
    print("ERROR: function " + func + " not found")
    sys.exit(1)

func_start = m.end()
print("Function found at char offset: " + str(func_start))

# Find the data pointer param name (the struct seccomp_data * argument)
full_sig = m.group(0)
print("Full signature: " + full_sig[:120])

sd_match = re.search(r'struct seccomp_data\s*\*\s*(\w+)', full_sig)
if sd_match:
    sd_param = sd_match.group(1)
else:
    sd_param = "sd"
print("seccomp_data param: " + sd_param)

# Inject after ALL leading declarations to avoid C89 mixing error.
# Scan from func_start and find the end of the declaration block.
body = c[func_start:]
lines = body.split("\n")
inject_line = 0
for i, line in enumerate(lines):
    stripped = line.strip()
    if stripped == "":
        continue
    # A declaration line starts with a type keyword or is a struct/pointer decl
    is_decl = bool(re.match(
        r'^\s*(u32|u64|int|long|unsigned|struct|const|void|bool|atomic|LIST_HEAD|'
        r'spinlock|DEFINE|__u32|__u64)[\s*]',
        line
    ))
    if not is_decl and stripped and not stripped.startswith("/*") and not stripped.startswith("*") and not stripped.startswith("//"):
        inject_line = i
        break

inject_offset = func_start + len("\n".join(lines[:inject_line]))
print("Injecting after " + str(inject_line) + " declaration lines")

bypass = (
    "\n\t/* PitchKernel: bypass BPF seccomp for gettid NR 178 ARM64.\n"
    "\t * gettid not in 4.19 vDSO (added 5.6+); always hits real syscall.\n"
    "\t * ATFWD BPF filter blocks it -> SIGSYS crash every 5s.\n"
    "\t * Stock MIUI has CONFIG_SECCOMP=n so filter never fires there. */\n"
    "\tif (unlikely(" + sd_param + "->nr == __NR_gettid))\n"
    "\t\treturn 0;\n"
)

c = c[:inject_offset] + bypass + c[inject_offset:]
with open(path, "w") as f:
    f.write(c)
print("Patched " + func + " using " + sd_param + "->nr")
