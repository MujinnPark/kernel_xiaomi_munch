import sys, re

path = sys.argv[1]
func = sys.argv[2]

with open(path) as f:
    c = f.read()

if "PitchKernel: bypass BPF seccomp for gettid" in c:
    print("Already patched")
    sys.exit(0)

# Find the function signature to extract the actual syscall parameter name
pat = r'((?:static\s+)?(?:u32|int)\s+' + re.escape(func) + r'\s*\(([^)]+)\)\s*\{)'
m = re.search(pat, c, re.MULTILINE)
if not m:
    print("ERROR: function " + func + " not found")
    sys.exit(1)

# Extract parameter list and find the syscall number param name
params = m.group(2)
print("Function params: " + params)

# Common param names for syscall number in seccomp functions
syscall_param = None
for candidate in ["syscall_nr", "this_syscall", "nr", "syscall", "call_nr"]:
    if candidate in params:
        syscall_param = candidate
        break

if not syscall_param:
    # Fall back: take the first int/u32 param name
    pm = re.search(r'(?:int|u32|long)\s+(\w+)', params)
    if pm:
        syscall_param = pm.group(1)

if not syscall_param:
    print("ERROR: cannot identify syscall param in: " + params)
    sys.exit(1)

print("Syscall param name: " + syscall_param)

# Find the end of ALL local variable declarations inside the function
# Inject AFTER the last declaration block, not at the opening brace
# Strategy: find the function body start, then find the first non-declaration line
func_start = m.end()
body = c[func_start:]

# Find all leading declarations (lines starting with whitespace + type keyword)
decl_pattern = r'^([ \t]+(?:struct|union|enum|int|u32|u64|long|unsigned|const|void|bool|atomic|spinlock|LIST_HEAD)[^;\n]+;[ \t]*\n)+'
decl_match = re.match(decl_pattern, body, re.MULTILINE)

if decl_match:
    inject_offset = func_start + decl_match.end()
    print("Injecting after declarations block")
else:
    inject_offset = func_start
    print("Injecting at function start (no declarations found)")

bypass = (
    "\n\t/* PitchKernel: bypass BPF seccomp for gettid NR 178 ARM64.\n"
    "\t * gettid not in 4.19 vDSO; ATFWD BPF filter blocks it -> SIGSYS.\n"
    "\t * Stock MIUI has CONFIG_SECCOMP=n so filter never enforced there. */\n"
    "\tif (unlikely(" + syscall_param + " == __NR_gettid))\n"
    "\t\treturn 0;\n"
)

c = c[:inject_offset] + bypass + c[inject_offset:]
with open(path, "w") as f:
    f.write(c)
print("Patched " + func + " in " + path)
