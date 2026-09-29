# Integrating native ownership

## Royalty pools

A native royalty position holds `share::share::Share` alongside its registrations
and reward debt. Payout funds continue to use `Balance<Currency>`.

- Read supply and decimals from the issuance; never assume a global denomination.
- Audit reward arithmetic for the full `u64` supply range, including supplies
  larger than any fixed reward precision constant.
- Bind each pool to a genuine `Issuance` and retain its ID.
- Check a position's issuance ID before accepting its shares.
- Include issuance identity and payout currency in the pool's derivation.
- Return native shares when a position is fully unregistered.
- Preserve accumulator math, reward debt, carry accounting and custody controls.

Keep shares inside a position while it is registered. Before splitting or
recombining ownership, settle and unregister the position, or implement explicit
operations that preserve reward accounting. Exposing mutable shares in a
registered position could change its weight without updating the pool.

Tokenization takes custody of native shares as backing. Settle and unregister
their positions before depositing them, or provide a separate revenue-accounting
mechanism. Holding receipt
coins alone does not track accrued earnings.

## Subject protocols

Compositions, recordings and events can initialize shares during creation using
their own UID and explicit supply/decimal parameters, then return or allocate the ownership units. They need no
per-subject share type parameter.

Administrative capabilities must bind to and validate the relevant subject ID.
Shares for different subjects have the same Move type, so authorization and pool
membership checks must explicitly compare identities.

Native shares cannot use the framework's `Balance<T>` funds accumulator. To give
a composition ownership in a recording, use an appropriate owned wrapper and
receiving path, or a protected container on the composition. Do not expose raw
mutable UID access merely to route ownership. Routed positions must verify the
issuance and preserve their intended payout destination.
