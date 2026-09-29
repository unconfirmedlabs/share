# unconfirmedlabs/share

Fixed-supply, subject-scoped ownership for Sui Move. Native ownership requires no
currency, per-subject token package or tokenization dependency.

The root package contains only `share::share`. Optional currency conversion is a
[separate `unconfirmedlabs/tokenization` package](https://github.com/unconfirmedlabs/tokenization), depending on
this package. MusicOS and eventOS can depend on the root package alone.

## Initialize ownership

```move
// 100 million shares displayed with 6 decimal places.
let shares = share::initialize(&mut registry, subject_uid, 100_000_000_000_000, 6);
```

A subject (composition, recording, event, etc.) supplies its actual `&mut UID`,
not an arbitrary ID. Its defining module must authorize that access.
Initialization derives an `Issuance` under the canonical shared
`IssuanceRegistry` using the subject ID, shares that issuance, and returns the
entire fixed ownership supply. A permanent derived claim prevents repeat
initialization. The registry has no public constructor, deletion path or mutable
UID accessor; package initialization creates its sole production instance.

`Issuance` records `subject_id`, immutable `supply`, and immutable `decimals`. `Share` contains an issuance ID
and a `u64` quantity, with **only `store`**: no UID, duplication or implicit
destruction. Applications hold shares inside their own wrappers or royalty
positions. The issuance contains no token type or conversion configuration.

## API

| Function | Result |
|---|---|
| `initialize(&mut IssuanceRegistry, &mut UID, supply: u64, decimals: u8)` | Full initial `Share`; creates shared issuance |
| `derive_issuance_id(&IssuanceRegistry, subject_id)` | Predicted `ID`, not proof of existence |
| `subject_id(&Issuance)` | Subject `ID` |
| `issuance_id(&Share)` | Ownership issuance `ID` |
| `value(&Share)` | Units held |
| `supply(&Issuance)` | Fixed total base units for this issuance |
| `decimals(&Issuance)` | Display precision for this issuance |
| `zero(&Issuance)` | Zero units for that issuance |
| `split(&mut Share, amount)` | Removes and returns that amount |
| `join(&mut Share, Share)` | Consumes another value; returns new total |
| `join_vec(&mut Share, vector<Share>)` | Consumes all supplied values |
| `withdraw_all(&mut Share)` | Returns everything, leaving zero |
| `destroy_zero(Share)` | Consumes only a zero value |

Supply is a positive `u64`: `1` through `18_446_744_073_709_551_615`, inclusive.
Decimals accept the full `u8` range (`0` through `255`), matching Sui currency
creation. These are display metadata; initialization never computes a power of
ten or multiplies supply by a decimal scale. Supply is already in base units.
The native ownership fraction is `value / issuance.supply()`; decimals do not
affect that ratio. There is no package-wide supply or decimal default.

The former `max_supply!()` and `decimals!()` macros are replaced by per-issuance
getters. Callers must now supply both parameters to initialization.

Operations follow Sui Balance conventions. Joining checks issuance identity at
runtime, including zero values. Splitting zero or the full balance is supported.
Empty vector joins are no-ops. Checked arithmetic and transaction atomicity
protect failed operations. Splits and joins touch no shared objects.

The registry address is discoverable from `IssuanceRegistryCreatedEvent`; `IssuanceCreatedEvent` records
the subject and issuance identities plus supply (`u64`) and decimals (`u8`).
Event decoders must account for these two additional fields. There is no holder enumeration requirement.

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
[unconfirmedlabs/tokenization](https://github.com/unconfirmedlabs/tokenization).

Licensed under Apache-2.0.
