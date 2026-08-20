//! How long to wait before retrying, given how many attempts have failed.
//!
//! The caller does the sleeping and the retrying. `next` is the decision.

const std = @import("std");

pub const Backoff = struct {
    base_ms: u64,
    cap_ms: u64,
    rand: std.Random,

    /// Milliseconds to wait before attempt number `attempt` (0 is the first retry).
    pub fn next(self: *Backoff, attempt: u6) u64 {
        _ = self;
        _ = attempt;
        @panic("not implemented");
    }
};
