# misofm/share

Fixed-supply ownership values for Sui Move, with optional coin conversion.

## Native ownership: `share::share`

A subject (composition, recording, event, etc.) initializes exactly one ownership
supply under the package's canonical shared `IssuanceRegistry`:

```move
let shares = share::initialize(&mut registry, subject_uid);
```

The subject supplies its actual `&mut UID`, not an arbitrary ID. Its defining
module must authorize that access. Initialization derives an `Issuance` under the
registry using the subject ID, shares that issuance, and returns all
**100,000,000,000,000 ownership units**. A derived claim permanently prevents
repeat initialization. The registry has no production constructor other than
package `init`, no deletion path, and no exposed mutable UID.

`Issuance` identifies the subject and its optional canonical token type. `Share`
contains an issuance ID and a `u64` quantity, with **only `store`**: no object UID,
no duplication and no implicit destruction. Applications store shares in their
own objects or royalty positions. A share's ownership fraction is its units
divided by `share::total_supply()`.

| Function | Result |
|---|---|
| `initialize(&mut IssuanceRegistry, &mut UID)` | Full initial `Share`; creates shared issuance |
| `derive_issuance_id(&IssuanceRegistry, subject_id)` | Predicted `ID`, not proof of existence |
| `subject_id(&Issuance)` | Subject `ID` |
| `token_type(&Issuance)` | `Option<TypeName>` |
| `issuance_id(&Share)` | Ownership issuance `ID` |
| `value(&Share)` | Units held |
| `total_supply()` | Fixed units per issuance |
| `zero(&Issuance)` | Zero units for that issuance |
| `split(&mut Share, amount)` | Removes and returns that amount |
| `join(&mut Share, Share)` | Consumes another value; returns new total |
| `join_vec(&mut Share, vector<Share>)` | Consumes all supplied values |
| `withdraw_all(&mut Share)` | Returns everything, leaving zero |
| `destroy_zero(Share)` | Consumes only a zero value |

Operations follow Sui Balance conventions. Joining checks issuance identity at
runtime (even for zeros), rather than relying on a per-subject type parameter.
Splitting zero or the full balance is supported. Empty vector joins are no-ops.
Checked arithmetic and transaction atomicity protect failed operations. Ordinary
split/join operations touch neither shared registry nor shared issuance.

The registry address is discoverable from `RegistryCreated`. `Issued` records the
subject and issuance identities. No issuance enumeration or holder registry is
needed for the primitive.

## Optional coins: `share::tokenization`

Create a currency externally, then authorize its one-time binding using the
subject UID and issuance:

```move
let conversion = tokenization::initialize(
    &mut issuance,
    subject_uid,
    &currency,
    treasury_cap,
);
tokenization::share(conversion);
```

`initialize` returns an unshared `Tokenization<T>`; `share` is its only production
by-value consumer, so initialization must complete by sharing it in the same
transaction. Its address derives from the issuance and can be computed with
`tokenization::derive_tokenization_id(&issuance)`.

The currency must have zero outstanding supply, its canonical treasury cap,
6 decimals, deleted metadata capability and no regulation/deny capability.
There is **no required name for the type T**. There is one canonical token type
per issuance. Binding is permanent even after all tokens convert back to native
shares. The treasury cannot be extracted or used for arbitrary minting.

```move
let balance = conversion.tokenize(shares);
let shares = conversion.detokenize(balance);
```

`tokenize` consumes native shares and mints equal coin base units;
`detokenize` burns the balance and reconstructs equal native units. Both are
holder-accessible and require only the shared conversion object. A wrong issuance
is rejected. `tokenization::issuance_id` and `tokenization::tokenized_supply` expose its binding
and outstanding token quantity. Use Sui's existing `coin::from_balance` and
`coin::into_balance` when object coins are needed.

For each issuance:

```text
native share units + outstanding token base units = 100,000,000,000,000
```

The currency's supply itself is deliberately not fixed: its private treasury
must mint and burn as representations change. Fixed *combined* ownership supply
is enforced by this package. The only package-private native consumption and
reconstruction helpers are called from these paired conversion operations.
Every module in the package is part of that trusted boundary. Publish this
package immutably to prevent upgrades from changing that guarantee.

## Royalty pool integration

Native shares represent ownership, not accrued earnings. A royalty position can
hold a `Share` plus its pool registrations and reward debt. Payment funds still
use `Balance<Currency>` (SUI, stablecoins, etc.).

The existing `misofm/royalty-pool` is **not compatible yet**: it holds
`Balance<ShareType>`, validates share currencies and uses the share type as an
identity boundary. See [INTEGRATION.md](INTEGRATION.md) for the integration requirements.

## Validation

```sh
sui move build
sui move test --coverage
```

Tests cover canonical issuance discovery, the production shared-object lifecycle,
duplicate initialization, native conservation, cross-issuance rejection, currency
validation, single token binding, repeated conversion conservation, and transfer
of coin receipts to another holder who redeems without subject authority.

Licensed under Apache-2.0.
