// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Optional, reversible 1:1 conversion. Treasury access never escapes this module.
/// Native units plus outstanding token base units always equal the fixed supply.
module share::tokenization;

use share::share::{Self, Issuance, Share};
use sui::balance::Balance;
use sui::coin::{Self, TreasuryCap};
use sui::coin_registry::Currency;
use sui::event;
use sui::derived_object;
use std::type_name::with_defining_ids;

public struct TokenizationKey() has copy, drop, store;

const ENotZeroSupply: u64 = 0;
const EMetadataNotLocked: u64 = 1;
const EInvalidDecimals: u64 = 2;
const ERegulatedCurrency: u64 = 3;
const ETreasuryMismatch: u64 = 4;
const EInvalidShareType: u64 = 5;
const DECIMALS: u8 = 6;
const SHARE_TYPE: vector<u8> = b"::share::Share";

public struct Tokenization<phantom T> has key {
    id: UID,
    issuance_id: ID,
    treasury: TreasuryCap<T>,
}

public struct TokenizationCreated<phantom T> has copy, drop {
    tokenization_id: ID,
    issuance_id: ID,
    currency_id: ID,
}

/// The subject authorizes its one canonical token type: <address>::share::Share.
/// This exact non-OTW name excludes legacy currencies with Unknown regulation.
/// Currency creation is external to this package.
/// The treasury stays live for conversion, unlike a fixed-supply Coin currency.
public fun initialize<T>(
    issuance: &mut Issuance,
    subject: &mut UID,
    currency: &Currency<T>,
    treasury: TreasuryCap<T>,
): Tokenization<T> {
    assert!(has_share_type_name<T>(), EInvalidShareType);
    assert!(currency.treasury_cap_id() == option::some(object::id(&treasury)), ETreasuryMismatch);
    assert!(coin::total_supply(&treasury) == 0, ENotZeroSupply);
    assert!(currency.is_metadata_cap_deleted(), EMetadataNotLocked);
    assert!(currency.decimals() == DECIMALS, EInvalidDecimals);
    assert!(!currency.is_regulated(), ERegulatedCurrency);
    let tokenization = Tokenization {
        id: derived_object::claim(share::bind_token<T>(issuance, subject), TokenizationKey()),
        issuance_id: object::id(issuance),
        treasury,
    };
    event::emit(TokenizationCreated<T> {
        tokenization_id: object::id(&tokenization),
        issuance_id: tokenization.issuance_id,
        currency_id: object::id(currency),
    });
    tokenization
}

/// The only production by-value consumer: initialization must end by sharing.
public fun share<T>(self: Tokenization<T>) { transfer::share_object(self) }

public fun derive_tokenization_id(issuance: &Issuance): ID {
    derived_object::derive_address(object::id(issuance), TokenizationKey()).to_id()
}

public fun issuance_id<T>(self: &Tokenization<T>): ID { self.issuance_id }
public fun tokenized_supply<T>(self: &Tokenization<T>): u64 {
    coin::total_supply(&self.treasury)
}

public fun tokenize<T>(self: &mut Tokenization<T>, shares: Share): Balance<T> {
    let amount = share::into_token_units(shares, self.issuance_id);
    self.treasury.mint_balance(amount)
}

public fun detokenize<T>(self: &mut Tokenization<T>, balance: Balance<T>): Share {
    let amount = self.treasury.supply_mut().decrease_supply(balance);
    share::from_token_units(self.issuance_id, amount)
}

/// Preserve the original share currency gate. Legacy constructors require an
/// uppercase OTW name; `share::Share` cannot be one, so Unknown regulation from
/// legacy migration cannot enter this path. Generic instantiations also fail.
fun has_share_type_name<T>(): bool {
    let name = with_defining_ids<T>();
    let bytes = name.as_string().as_bytes();
    let suffix = SHARE_TYPE;
    if (bytes.length() < suffix.length()) return false;
    let offset = bytes.length() - suffix.length();
    let mut i = 0;
    while (i < suffix.length()) {
        if (bytes[offset + i] != suffix[i]) return false;
        i = i + 1;
    };
    true
}

#[test_only]
public fun has_share_type_name_for_testing<T>(): bool { has_share_type_name<T>() }
