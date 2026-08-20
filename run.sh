#!/bin/sh
# What the examiner may run against the candidate's backoff.
#
# The submission decides a delay and nothing else — the caller does the sleeping
# — so each target is a caller written here, compiled against the candidate's
# own backoff.zig. /work is read-only and zig writes two caches, so both are
# named explicitly rather than left to default under the source directory.
#
# There is no reference implementation for this assignment. These print numbers
# and draw no conclusion: a spread of zero is not a failure to be marked, it is
# the number the candidate has to account for. A non-zero exit means the code
# did not run at all.
#
# Usage: run.sh [--list | <target>]
set -eu

TARGET="${1:---default}"

if [ "$TARGET" = "--list" ]; then
  printf '%s\t%s\n' \
    delays 'Prints the first eight waits for two clients that failed at the same instant, side by side. Start here: it shows the shape of the curve and whether two clients differ at all.' \
    spread 'Runs 1000 clients that all failed at the same instant and reports how far apart their third retry lands.' \
    ceiling 'Walks the attempt counter to 20 and prints every delay, showing whether the stated cap of 30000 ms actually holds.' \
    budget 'Sums what one client waits across ten retries, showing what the policy costs the caller before it gives up.'
  exit 0
fi

[ "$TARGET" = "--default" ] && TARGET=delays

# $TMPDIR is set to /build/tmp by the image; the tmpfs is mounted fresh for each
# session, so the directory itself has to be made here rather than baked in.
mkdir -p "${TMPDIR:-/build/tmp}"

# A directory of this script's own: the assignment's scenarios build in
# /build/run, and a run must not tread on one that is still going.
W=/build/viva-run
rm -rf "$W"
mkdir -p "$W"

[ -f /work/backoff.zig ] || { echo "the submission has no backoff.zig at its root"; exit 2; }

# Every root .zig file, not backoff.zig alone: a candidate who split the policy
# across two files imports the second one beside it.
for f in /work/*.zig; do
  [ -f "$f" ] || continue
  cp "$f" "$W/"
done

cd "$W"

case "$TARGET" in
delays)
  cat > viva_main.zig <<'ZIG'
const std = @import("std");
const backoff = @import("backoff.zig");

// The first eight waits for two clients that failed at the same instant. Two
// identical columns mean the delay is a function of the attempt number alone,
// and every client in the fleet is holding the same clock.
pub fn main() !void {
    var prng = std.Random.DefaultPrng.init(1);
    const out = std.io.getStdOut().writer();

    var one = backoff.Backoff{ .base_ms = 100, .cap_ms = 30_000, .rand = prng.random() };
    var two = backoff.Backoff{ .base_ms = 100, .cap_ms = 30_000, .rand = prng.random() };

    try out.print("attempt   client one   client two\n", .{});
    var identical: usize = 0;
    var a: u6 = 0;
    while (a < 8) : (a += 1) {
        const d1 = one.next(a);
        const d2 = two.next(a);
        if (d1 == d2) identical += 1;
        try out.print("{d:>7}   {d:>7} ms   {d:>7} ms\n", .{ a, d1, d2 });
    }

    if (identical == 8) {
        try out.print("\nthe two clients waited the same amount every time\n", .{});
    } else {
        try out.print("\nthe two clients differed on {d} of 8 attempts\n", .{8 - identical});
    }
}
ZIG
  ;;
spread)
  cat > viva_main.zig <<'ZIG'
const std = @import("std");
const backoff = @import("backoff.zig");

// A thousand clients that all failed at the same instant, retrying together.
// The question is how far apart their third attempt lands.
pub fn main() !void {
    var prng = std.Random.DefaultPrng.init(1);
    const out = std.io.getStdOut().writer();

    var buckets = [_]usize{0} ** 8;
    var i: usize = 0;
    var min: u64 = std.math.maxInt(u64);
    var max: u64 = 0;

    while (i < 1000) : (i += 1) {
        var b = backoff.Backoff{ .base_ms = 100, .cap_ms = 30_000, .rand = prng.random() };
        const d = b.next(2);
        if (d < min) min = d;
        if (d > max) max = d;
        const slot = @min(@as(usize, @intCast(d / 200)), buckets.len - 1);
        buckets[slot] += 1;
    }

    try out.print("1000 clients, third retry\n", .{});
    try out.print("  shortest wait: {d} ms\n", .{min});
    try out.print("  longest wait:  {d} ms\n", .{max});
    var s: usize = 0;
    while (s < buckets.len) : (s += 1) {
        if (buckets[s] > 0) try out.print("  {d:>4}-{d:<4} ms : {d}\n", .{ s * 200, (s + 1) * 200, buckets[s] });
    }
    if (min == max) {
        try out.print("\nALL 1000 RETRY AT THE SAME MILLISECOND\n", .{});
    } else {
        try out.print("\nspread across {d} ms\n", .{max - min});
    }
}
ZIG
  ;;
ceiling)
  cat > viva_main.zig <<'ZIG'
const std = @import("std");
const backoff = @import("backoff.zig");

// What the delay does as attempts climb. A cap applied to the exponent rather
// than the delay overflows; one applied to neither grows without bound.
pub fn main() !void {
    var prng = std.Random.DefaultPrng.init(1);
    const out = std.io.getStdOut().writer();
    var b = backoff.Backoff{ .base_ms = 100, .cap_ms = 30_000, .rand = prng.random() };

    var a: u6 = 0;
    while (a < 20) : (a += 1) {
        const d = b.next(a);
        try out.print("attempt {d:>2}: {d} ms\n", .{ a, d });
        if (d > 30_000) {
            try out.print("EXCEEDED THE STATED CAP of 30000 ms\n", .{});
            return;
        }
    }
    try out.print("never exceeded the cap\n", .{});
}
ZIG
  ;;
budget)
  cat > viva_main.zig <<'ZIG'
const std = @import("std");
const backoff = @import("backoff.zig");

// What one client actually waits before it gives up. A cap is a decision about
// this number: it is what a caller trades for bounding how long a request can
// hang around, and a candidate who capped the exponent instead has chosen a
// different number than the one they meant to.
pub fn main() !void {
    var prng = std.Random.DefaultPrng.init(7);
    const out = std.io.getStdOut().writer();
    var b = backoff.Backoff{ .base_ms = 100, .cap_ms = 30_000, .rand = prng.random() };

    // Saturating, so a runaway delay is reported as a number rather than as an
    // overflow in arithmetic of ours.
    var total: u64 = 0;
    var a: u6 = 0;
    while (a < 10) : (a += 1) {
        const d = b.next(a);
        total +|= d;
        try out.print("retry {d:>2}: waited {d:>8} ms   total {d:>9} ms\n", .{ a, d, total });
    }
    try out.print("\nten retries cost the client {d} seconds\n", .{total / 1000});
}
ZIG
  ;;
*)
  echo "no such target: $TARGET"
  exit 2
  ;;
esac

zig run viva_main.zig --cache-dir /build/zig-cache --global-cache-dir /build/zig-global 2>&1
