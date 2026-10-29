// Copyright (c) Unconfirmed Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module share::share_invariant_tests;

use share::{fixture::{Self, Fixture}, share};
use std::unit_test::{assert_eq, destroy};
use sui::{
    balance::Balance,
    coin::{Self, TreasuryCap},
    coin_registry::{Self, CoinRegistry, Currency}
};

const SUPPLY: u64 = 100_000_000_000_000;

fun mint(currency: &mut Currency<Fixture>, treasury_cap: TreasuryCap<Fixture>): Balance<Fixture> {
    share::mint(
        currency,
        treasury_cap,
        b"fixture",
        b"Fixture",
        6,
        b"FIX".to_string(),
        b"Fixture".to_string(),
        b"".to_string(),
        b"".to_string(),
        SUPPLY,
    )
}

fun locked(
    registry: &mut CoinRegistry,
    ctx: &mut TxContext,
): (Currency<Fixture>, TreasuryCap<Fixture>) {
    fixture::locked(
        registry,
        6,
        b"FIX".to_string(),
        b"Fixture".to_string(),
        b"".to_string(),
        b"".to_string(),
        ctx,
    )
}

#[test]
fun minted_currency_is_fixed_unregulated_and_frozen() {
    let ctx = &mut tx_context::dummy();
    let mut registry = fixture::registry(ctx);
    let (mut currency, treasury_cap) = locked(&mut registry, ctx);
    let shares = mint(&mut currency, treasury_cap);
    assert_eq!(shares.value(), SUPPLY);
    assert!(currency.is_supply_fixed());
    assert!(!currency.is_supply_burn_only());
    assert_eq!(currency.total_supply(), option::some(SUPPLY));
    assert!(currency.is_metadata_cap_deleted());
    assert!(!currency.is_regulated());
    assert_eq!(currency.deny_cap_id(), option::none());
    destroy(shares);
    destroy(currency);
    destroy(registry);
}

#[test, expected_failure(abort_code = coin_registry::ESupplyNotBurnOnly)]
fun fixed_supply_cannot_be_burned() {
    let ctx = &mut tx_context::dummy();
    let mut registry = fixture::registry(ctx);
    let (mut currency, treasury_cap) = locked(&mut registry, ctx);
    let shares = mint(&mut currency, treasury_cap);
    coin_registry::burn_balance(&mut currency, shares);
    abort
}

#[test, expected_failure(abort_code = coin_registry::EInvariantViolation)]
fun fixed_supply_cannot_be_fixed_again() {
    let ctx = &mut tx_context::dummy();
    let mut registry = fixture::registry(ctx);
    let (mut currency, treasury_cap) = locked(&mut registry, ctx);
    let shares = mint(&mut currency, treasury_cap);
    let mut forged_cap = coin::create_treasury_cap_for_testing<Fixture>(ctx);
    destroy(forged_cap.mint_balance(1));
    currency.make_supply_fixed(forged_cap);
    destroy(shares);
    abort
}

#[test, expected_failure(abort_code = share::ESupplyAlreadySet)]
fun minting_a_fixed_currency_again_aborts() {
    let ctx = &mut tx_context::dummy();
    let mut registry = fixture::registry(ctx);
    let (mut currency, treasury_cap) = locked(&mut registry, ctx);
    destroy(mint(&mut currency, treasury_cap));
    let forged_cap = coin::create_treasury_cap_for_testing<Fixture>(ctx);
    destroy(mint(&mut currency, forged_cap));
    abort
}

#[test, expected_failure(abort_code = share::ETreasuryMismatch)]
fun forged_treasury_cap_is_rejected() {
    let ctx = &mut tx_context::dummy();
    let mut registry = fixture::registry(ctx);
    let (mut currency, treasury_cap) = locked(&mut registry, ctx);
    let forged_cap = coin::create_treasury_cap_for_testing<Fixture>(ctx);
    destroy(treasury_cap);
    destroy(mint(&mut currency, forged_cap));
    abort
}

#[test, expected_failure(abort_code = share::ETreasuryMismatch)]
fun treasury_mismatch_is_checked_before_minted_supply() {
    let ctx = &mut tx_context::dummy();
    let mut registry = fixture::registry(ctx);
    let (mut currency, treasury_cap) = locked(&mut registry, ctx);
    let mut forged_cap = coin::create_treasury_cap_for_testing<Fixture>(ctx);
    destroy(forged_cap.mint_balance(5));
    destroy(treasury_cap);
    destroy(mint(&mut currency, forged_cap));
    abort
}

#[test, expected_failure(abort_code = share::EInvalidType)]
fun type_is_checked_before_metadata() {
    let ctx = &mut tx_context::dummy();
    let mut registry = fixture::registry(ctx);
    let (mut currency, treasury_cap, metadata_cap) = fixture::unlocked(&mut registry, ctx);
    destroy(metadata_cap);
    destroy(
        share::mint(
            &mut currency,
            treasury_cap,
            b"other",
            b"Fixture",
            6,
            b"FIX".to_string(),
            b"Fixture".to_string(),
            b"".to_string(),
            b"".to_string(),
            SUPPLY,
        ),
    );
    abort
}

#[test, expected_failure(abort_code = share::ENotZeroSupply)]
fun outstanding_premint_held_elsewhere_is_rejected() {
    let ctx = &mut tx_context::dummy();
    let mut registry = fixture::registry(ctx);
    let (mut currency, mut treasury_cap) = locked(&mut registry, ctx);
    transfer::public_transfer(treasury_cap.mint(1, ctx), @0xBAD);
    destroy(mint(&mut currency, treasury_cap));
    abort
}
