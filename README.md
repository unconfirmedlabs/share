# share

A [Sui Move](https://docs.sui.io/concepts/sui-move-concepts) package for fixed-supply currency issuance, designed for representing equity-like ownership stakes.

`share::share::initialize` mints exactly **10,000,000.000000** tokens (6 decimals) and makes the supply immutable. It enforces a set of structural invariants at initialization to guarantee the resulting token is well-formed and tamper-proof:

- The type parameter must be `<address>::share::Share`
- The currency's `MetadataCap` must already be deleted (metadata is frozen)
- Decimals must equal 6
- Existing supply must be zero

## Usage

1. Create a package with a `share` module containing a `Share` one-time witness type.
2. Create a currency with `sui::coin_registry::new_currency`.
3. Set any desired metadata (name, symbol, icon, description), then call `finalize_and_delete_metadata_cap` to freeze it.
4. Call `share::share::initialize` with the currency and treasury cap.
5. Distribute the returned `Balance<Share>` to shareholders.

### Icon URL Helper

A convenience function is provided for constructing [Walrus](https://docs.walrus.site/)-hosted icon URLs:

```move
let icon_url = share::share::construct_icon_url(blob_id);
// => "walrus://<base64url-encoded blob ID>"
```

## Dependencies

| Dependency | Source |
|---|---|
| [codec](https://github.com/sui-potatoes/app/tree/main/packages/codec) | `sui-potatoes/app` (base64url encoding) |
| Sui Framework | Sui standard libraries |

## Build

```sh
sui move build
```

## Test

```sh
sui move test
```

## License

[Apache 2.0](LICENSE)
