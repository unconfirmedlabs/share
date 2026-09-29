# misofm/share

Fixed-supply, subject-scoped ownership for Sui Move. Native ownership requires no
currency, per-subject token package or tokenization dependency.

The root package contains only `share::share`. Optional currency conversion is a
[separate `misofm/tokenization` package](https://github.com/misofm/tokenization), depending on
this package. MusicOS and eventOS can depend on the root package alone.

## Initialize ownership

```move
let shares = share::initialize(&mut registry, subject_uid);
```

A subject (composition, recording, event, etc.) supplies its actual `&mut UID`,
not an arbitrary ID. Its defining module must authorize that access.
Initialization derives an `Issuance` under the canonical shared
`IssuanceRegistry` using the subject ID, shares that issuance, and returns the
entire fixed ownership supply. A permanent derived claim prevents repeat
initialization. The registry has no public constructor, deletion path or mutable
UID accessor; package initialization creates its sole production instance.

`Issuance` records only identity and `subject_id`. `Share` contains an issuance ID
and a `u64` quantity, with **only `store`**: no UID, duplication or implicit
destruction. Applications hold shares inside their own wrappers or royalty
positions. The issuance contains no token type or conversion configuration.

## API

| Function | Result |
|---|---|
| `initialize(&mut IssuanceRegistry, &mut UID)` | Full initial `Share`; creates shared issuance |
| `derive_issuance_id(&IssuanceRegistry, subject_id)` | Predicted `ID`, not proof of existence |
| `subject_id(&Issuance)` | Subject `ID` |
| `issuance_id(&Share)` | Ownership issuance `ID` |
| `value(&Share)` | Units held |
| `max_supply!()` | Fixed maximum units per issuance: `100_000_000_000_000u64` |
| `decimals!()` | Standard token representation precision: `6u8` |
| `zero(&Issuance)` | Zero units for that issuance |
| `split(&mut Share, amount)` | Removes and returns that amount |
| `join(&mut Share, Share)` | Consumes another value; returns new total |
| `join_vec(&mut Share, vector<Share>)` | Consumes all supplied values |
| `withdraw_all(&mut Share)` | Returns everything, leaving zero |
| `destroy_zero(Share)` | Consumes only a zero value |

Supply and decimal parameters are public macro functions so integrations can
reuse the ownership unit conventions without duplicating constants. The native
ownership fraction is `value / max_supply!()`; decimals do not affect that ratio.

Operations follow Sui Balance conventions. Joining checks issuance identity at
runtime, including zero values. Splitting zero or the full balance is supported.
Empty vector joins are no-ops. Checked arithmetic and transaction atomicity
protect failed operations. Splits and joins touch no shared objects.

The registry address is discoverable from `IssuanceRegistryCreatedEvent`; `IssuanceCreatedEvent` records
the subject and issuance identities. There is no holder enumeration requirement.

## Conservation and integration

Native ownership units are created only at subject initialization. There is no
public or package-private reconstruction/mint interface, nonzero burn, issuer
clawback, or tokenization-specific authority in this package. Every native unit,
including units held as backing by adapters, remains part of the fixed supply.

The separate tokenization package holds shares and issues coin receipts against
them. It cannot create native ownership. Other integrations can use the same
public API without being approved by the subject or this package.

Royalty positions hold native shares alongside reward debt and registration
state. Payout funds continue to use `Balance<Currency>`. Existing coin-based
royalty pools require adaptation; see [INTEGRATION.md](INTEGRATION.md).

## Build and test

```sh
sui move build
sui move test
```

Tokenization has its own repository, dependency graph, build and tests:
[misofm/tokenization](https://github.com/misofm/tokenization).

Licensed under Apache-2.0.
