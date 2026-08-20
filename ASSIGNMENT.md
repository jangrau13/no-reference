# Wait before trying again (example assignment)

A thousand clients hit a service that has just fallen over. When it comes back,
they must not all return at the same instant.

Your problem is `backoff.zig`, and one function in it.

## What to do

1. **`next(attempt)`** — milliseconds to wait before this attempt.
2. The delay must have a ceiling.

## What you are marked on

There is no single right answer here. You are marked on whether you can say
what your choice costs.
