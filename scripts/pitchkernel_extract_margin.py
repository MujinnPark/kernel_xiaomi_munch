#!/usr/bin/env python3
"""
PitchKernel diagnostic: read the actual compiled value of a small
(<=8 byte) .data symbol out of a compiled .o file, using objdump.

Written 2026-07-18 after a first version of this check assumed the
target symbol sits at offset 0x0 in .data. That's only true on a
trivial isolated test object -- on a real translation unit like
walt.o, dozens of other static variables come first, and the real
symbol offset was 0x174. Reading fixed offset 0x0 there just read
someone else's (legitimately zero) variable and reported a false
(0, 0), not a real finding about the kernel build.

This version reads the symbol table first to get the real offset,
then reads .data generically by address rather than by assumed row
position, so it's correct regardless of where the linker places the
symbol.

Usage: pitchkernel_extract_margin.py <objdump-binary> <obj-file> <symbol-name>
Prints the two little-endian u32 values found there, or a clear
diagnostic message if the symbol/offset can't be resolved.
"""
import subprocess
import struct
import sys


def get_symbol_offset(objdump, obj, symbol):
    out = subprocess.run(
        [objdump, "-t", obj], capture_output=True, text=True
    ).stdout
    for line in out.splitlines():
        if symbol in line and ".data" in line:
            addr_hex = line.split()[0]
            return int(addr_hex, 16)
    return None


def get_data_bytes_at(objdump, obj, offset, length):
    out = subprocess.run(
        [objdump, "-s", "-j", ".data", obj], capture_output=True, text=True
    ).stdout
    data = {}
    for line in out.splitlines():
        parts = line.strip().split()
        if len(parts) < 2:
            continue
        try:
            row_addr = int(parts[0], 16)
        except ValueError:
            continue
        hexpart = "".join(parts[1:5])
        try:
            row_bytes = bytes.fromhex(hexpart)
        except ValueError:
            continue
        for i, b in enumerate(row_bytes):
            data[row_addr + i] = b
    try:
        return bytes(data[offset + i] for i in range(length))
    except KeyError:
        return None


def main():
    if len(sys.argv) != 4:
        print(f"usage: {sys.argv[0]} <objdump> <obj-file> <symbol>")
        sys.exit(2)

    objdump, obj, symbol = sys.argv[1], sys.argv[2], sys.argv[3]

    offset = get_symbol_offset(objdump, obj, symbol)
    if offset is None:
        print(f"SYMBOL {symbol} NOT FOUND in .data section of {obj}")
        print("(may be stripped, or genuinely absent -- check with:")
        print(f"  {objdump} -t {obj} | grep {symbol}")
        sys.exit(1)

    raw = get_data_bytes_at(objdump, obj, offset, 8)
    if raw is None:
        print(f"{symbol} found at offset {hex(offset)}, but that address "
              f"isn't covered by the .data dump -- it may actually be in "
              f".bss (all-zero, uninitialized) instead of .data.")
        sys.exit(1)

    vals = struct.unpack("<II", raw)
    print(f"{symbol} at offset {hex(offset)}: "
          f"[0]={vals[0]} [1]={vals[1]} "
          f"(expect 1078,1056 if patched; 1078,1078 if stock)")


if __name__ == "__main__":
    main()
