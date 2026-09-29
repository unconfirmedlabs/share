# Migration to native ownership

This is a breaking, fresh-publication generation of `misofm/share`. Historical
`Published.toml` entries and the old audit are not validation or deployment
records for the new API. Dependent packages remain pinned to their existing
revisions until deliberately migrated.

## royalty-pool

Payout currencies remain ordinary coins/balances. Only the ownership side changes:

| Current | New direction |
|---|---|
| `Stake<ShareType>` holds `Balance<ShareType>` | `Stake` holds native `share::share::Share` |
| `RoyaltyPool<ShareType, Currency>` | `RoyaltyPool<Currency>` with an immutable `issuance_id` |
| Currency shape validation through `share::is_share` | Bind to a genuine `&Issuance` |
| Share type separates which positions a pool accepts | Explicitly compare the stake and pool issuance IDs |
| Derived pool namespace includes share type | Define new derivation including issuance identity and payout currency |
| Coin balance returned on unstaking | Native `Share` returned on unstaking |

Preserve accumulator math, reward debt, carry accounting, registration semantics
and the existing ownership/route controls. Removing a type parameter must not
remove the corresponding identity check. Distinct subjects now use the same
Move type for their shares.

Keep shares inside a position while it is registered. To split/recombine
ownership, either unregister and settle the existing position first or implement
explicit debt-preserving position operations. Exposing mutable native shares
inside a registered position would let callers change its economic weight
without updating the pool's accounting.

Do not allow the same economic units to be registered in native form and
represented by a token simultaneously. A token adapter must settle/unregister
native positions before consuming their shares, or define a separate explicit
revenue-accounting layer. Token receipt ownership alone does not account for
historical earnings.

## musicos and eventOS

Composition, Recording and Event can initialize native shares during subject
creation with access to their own UID. Return the remaining ownership after any
required allocations. Subject objects need no per-subject share type parameter.

Before removing those generics, replace every type-identity authorization
assumption with explicit subject/issuance ID checks. In particular, a raw admin
capability must carry and validate its subject ID; merely using the same cap
struct is no longer sufficient.

The composition's share of a recording can still be allocated at construction.
However, native `Share` is not `Balance<T>` and cannot use the framework funds
accumulator. Use an appropriate owned wrapper/receiving path or a protected
container on the composition for those recording shares. No raw mutable UID
access should be granted just to route ownership. Existing routed-stake actions
must also be adapted to hold and verify the new native positions.

## Existing coin holders

The old fixed-supply currency treasury was consumed. Those coins cannot simply
be burned through a newly invented treasury. Any migration must irrevocably
lock legacy ownership and account for its corresponding native allocation, or
use another audited mechanism that prevents two independently claimable supplies.

Accrued rewards must be settled or preserved independently. Starting a new
issuance at full supply without retiring the old claim paths is not a safe
migration. No deployed migration is implemented here.
