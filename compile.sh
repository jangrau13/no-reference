#!/bin/sh
# Does the submission build?
#
# This is the gate that decides whether the examiner may propose a patch at
# all, so the exit code has to be the compiler's and nothing else's: a check
# stricter than zig refuses patches that are fine, and a looser one lets a patch
# through to fail inside a run, where the examiner cannot tell its own edit from
# the candidate's code.
#
# /work is read-only and zig writes a local and a global cache, so both are
# named explicitly rather than left to default under the source directory.
set -eu

mkdir -p "${TMPDIR:-/build/tmp}"
W=/build/viva-compile
rm -rf "$W"
mkdir -p "$W"

[ -f /work/backoff.zig ] || { echo "the submission has no backoff.zig at its root"; exit 2; }

for f in /work/*.zig; do
  [ -f "$f" ] || continue
  cp "$f" "$W/"
done

cd "$W"
# Zig analyses what is reached, so a root that only imported backoff.zig would
# report a type error inside the decision as a clean build. Calling `next` is
# what puts its body in front of the compiler, and calling it the way the
# scenarios do is what makes this gate mean what it says.
cat > viva_compile.zig <<'ZIG'
const std = @import("std");
const backoff = @import("backoff.zig");

pub fn main() void {
    var prng = std.Random.DefaultPrng.init(1);
    var b = backoff.Backoff{ .base_ms = 100, .cap_ms = 30_000, .rand = prng.random() };
    const d = b.next(0);
    if (d == 0) return;
}
ZIG

zig build-exe viva_compile.zig --cache-dir /build/zig-cache --global-cache-dir /build/zig-global 2>&1
