import sys, re

path = sys.argv[1]

with open(path) as f:
    c = f.read()

if "PitchKernel: bypass BPF seccomp for gettid" in c:
    print("Already patched")
    sys.exit(0)

# seccomp_run_filters(const struct seccomp_data *sd, struct seccomp_filter **match)
# The function iterates filters and the syscall nr is in sd->nr.
# Safe injection point: just before the first `for` or `list_for_each` loop
# inside seccomp_run_filters — after all declarations, before any logic.
# We find the function start, then find the first `for (` or `list_for_each`
# after it, and inject immediately before that line.

func_match = re.search(r'seccomp_run_filters\s*\(', c)
if not func_match:
    print("ERROR: seccomp_run_filters not found")
    sys.exit(1)

# Find the opening brace of the function
brace_pos = c.find("{", func_match.start())
if brace_pos < 0:
    print("ERROR: opening brace not found")
    sys.exit(1)

body = c[brace_pos:]

# Find first for( or list_for_each after the opening brace
loop_match = re.search(r'\n([ \t]+(?:for\s*\(|list_for_each))', body)
if not loop_match:
    print("ERROR: no loop found in function body")
    # Fallback: inject after all lines matching declaration pattern
    lines = body.split("\n")
    inject_idx = 1  # after opening brace line
    for i, line in enumerate(lines[1:], 1):
        s = line.strip()
        if re.match(r'^(?:u32|int|long|struct|const|bool|unsigned|void)\s', s):
            inject_idx = i + 1
        elif s and not s.startswith("/*") and not s.startswith("*"):
            break
    inject_pos = brace_pos + len("\n".join(lines[:inject_idx]))
    print("Fallback inject after line " + str(inject_idx))
else:
    # Inject on the line just before the loop
    inject_pos = brace_pos + loop_match.start() + 1  # +1 to keep the newline before
    print("Injecting before loop at offset " + str(inject_pos))

bypass = (
    "\t/* PitchKernel: bypass BPF seccomp for gettid NR 178 ARM64.\n"
    "\t * gettid not in ARM64 4.19 vDSO; always hits real syscall.\n"
    "\t * ATFWD vendor BPF filter blocks it -> SIGSYS crash every 5s.\n"
    "\t * Stock MIUI kernel has CONFIG_SECCOMP=n so filter never fires. */\n"
    "\tif (unlikely(sd->nr == __NR_gettid))\n"
    "\t\treturn 0;\n"
)

c = c[:inject_pos] + bypass + c[inject_pos:]
with open(path, "w") as f:
    f.write(c)
print("OK: gettid bypass injected before loop in seccomp_run_filters")

# Verify
with open(path) as f:
    lines = f.readlines()
for i, line in enumerate(lines[195:210], 196):
    print(str(i) + ": " + line.rstrip())
