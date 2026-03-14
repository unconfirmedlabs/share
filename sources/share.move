// Copyright (c) Subsonic Labs, LLC
// SPDX-License-Identifier: Apache-2.0

/// A standalone module for creating fixed-supply share tokens on Sui.
/// Share tokens represent ownership stakes in any entity and can be used
/// for pro-rata reward distribution.
///
/// ### Usage:
///
/// 1. Create a package with a `share` module containing a `Share` type
/// 2. Create a currency with `sui::coin_registry::new_currency`, using
///    `share::share::icon_url(blob_id)` as the icon URL
/// 3. Delete the metadata cap via `finalize_and_delete_metadata_cap`
/// 4. Call `share::share::initialize` with the currency, treasury cap, and icon blob ID
/// 5. Distribute the returned balance to shareholders
module share::share;

use codec::base64url;
use std::string::String;
use std::type_name::with_defining_ids;
use sui::balance::Balance;
use sui::bcs;
use sui::coin::TreasuryCap;
use sui::coin_registry::Currency;

// === Constants ===

/// Fixed supply of 10,000,000.000000 tokens (6 decimal places).
const SUPPLY: u64 = 10_000_000_000_000;
/// Required number of decimal places.
const DECIMALS: u8 = 6;
/// Required currency symbol.
const SYMBOL: vector<u8> = b"SHARE";

/// Suffix that all valid share type names must end with.
const SHARE_TYPE: vector<u8> = b"::share::Share";

// === Errors ===

/// Currency already has non-zero supply.
const ENotZeroSupply: u64 = 0;
/// Currency's MetadataCap has not been deleted.
const EMetadataCapNotDeleted: u64 = 1;
/// Share type is invalid (must end with `::share::Share`).
const EInvalidShareType: u64 = 2;
/// Currency does not have 6 decimals.
const EInvalidDecimals: u64 = 3;
/// Currency symbol is not "SHARE".
const EInvalidSymbol: u64 = 4;
/// Currency's icon URL does not match the expected walrus:// URL.
const EInvalidIconUrl: u64 = 5;

// === Public Functions ===

/// Initializes a fixed-supply share token with 10,000,000.000000 supply.
/// Validates the currency configuration, mints the fixed supply,
/// and makes the supply immutable. Returns the full token balance.
///
/// The type parameter must be a `Share` type defined in a `share` module
/// (i.e. `<address>::share::Share`).
public fun initialize<Share>(
    currency: &mut Currency<Share>,
    mut treasury_cap: TreasuryCap<Share>,
    icon_blob_id: u256,
): Balance<Share> {
    // Assert the share type is valid.
    assert_valid_share_type<Share>();
    // Assert the currency's MetadataCap has been deleted,
    // which prevents currency metadata from being modified after initialization.
    assert!(currency.is_metadata_cap_deleted(), EMetadataCapNotDeleted);
    // Assert the currency has the correct number of decimals.
    assert!(currency.decimals() == DECIMALS, EInvalidDecimals);
    // Assert the currency has the correct symbol.
    assert!(currency.symbol() == SYMBOL.to_string(), EInvalidSymbol);
    // Assert the currency's icon URL matches the provided blob ID.
    assert!(currency.icon_url() == construct_icon_url(icon_blob_id), EInvalidIconUrl);
    // Assert the currency has no existing supply.
    assert!(treasury_cap.supply().value() == 0, ENotZeroSupply);

    // Mint the share balance.
    let balance = treasury_cap.mint_balance(SUPPLY);

    // Make the supply fixed.
    currency.make_supply_fixed(treasury_cap);

    balance
}

// === Private Functions ===

/// Constructs a `walrus://<base64url>` icon URL from a Walrus blob ID.
fun construct_icon_url(blob_id: u256): String {
    let mut url: String = b"walrus://".to_string();
    url.append(base64url::encode(bcs::to_bytes(&blob_id)));
    url
}

//=== Assert Functions ===

/// Asserts that the share type name ends with the expected suffix.
fun assert_valid_share_type<Share>() {
    let t = with_defining_ids<Share>();
    let bytes = bcs::to_bytes(&t);
    let share_type = SHARE_TYPE;

    let bytes_len = bytes.length();
    let suffix_len = share_type.length();

    // Ensure bytes_len is at least suffix_len to avoid underflow.
    assert!(bytes_len >= suffix_len, EInvalidShareType);

    suffix_len.do!(|i| {
        assert!(bytes[bytes_len - suffix_len + i] == share_type[i], EInvalidShareType);
    });
}
