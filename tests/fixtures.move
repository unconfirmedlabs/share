// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0
#[test_only]
module share::fixtures;

use sui::coin::{TreasuryCap, DenyCapV2};
use sui::coin_registry::{Self, Currency, MetadataCap};
use std::unit_test::destroy;

public struct Receipt has key { id: UID }
public struct OtherReceipt has key { id: UID }
public struct Subject has key { id: UID }

public fun subject(ctx: &mut TxContext): Subject { Subject { id: object::new(ctx) } }
public fun uid(self: &mut Subject): &mut UID { &mut self.id }
public fun keep(self: Subject, owner: address) { transfer::transfer(self, owner) }

public fun currency(
    decimals: u8,
    ctx: &mut TxContext,
): (Currency<Receipt>, TreasuryCap<Receipt>, MetadataCap<Receipt>) {
    let mut registry = coin_registry::create_coin_data_registry_for_testing(ctx);
    let (builder, treasury) = coin_registry::new_currency<Receipt>(
        &mut registry, decimals, b"OWN".to_string(), b"Ownership".to_string(),
        b"".to_string(), b"".to_string(), ctx,
    );
    let (currency, metadata) = coin_registry::finalize_unwrap_for_testing(builder, ctx);
    destroy(registry);
    (currency, treasury, metadata)
}

public fun other_currency(
    ctx: &mut TxContext,
): (Currency<OtherReceipt>, TreasuryCap<OtherReceipt>) {
    let mut registry = coin_registry::create_coin_data_registry_for_testing(ctx);
    let (builder, treasury) = coin_registry::new_currency<OtherReceipt>(
        &mut registry, 6, b"ALT".to_string(), b"Other".to_string(),
        b"".to_string(), b"".to_string(), ctx,
    );
    let (mut currency, metadata) = coin_registry::finalize_unwrap_for_testing(builder, ctx);
    currency.delete_metadata_cap(metadata);
    destroy(registry);
    (currency, treasury)
}

public fun regulated(
    ctx: &mut TxContext,
): (Currency<Receipt>, TreasuryCap<Receipt>, DenyCapV2<Receipt>) {
    let mut registry = coin_registry::create_coin_data_registry_for_testing(ctx);
    let (mut builder, treasury) = coin_registry::new_currency<Receipt>(
        &mut registry, 6, b"REG".to_string(), b"Regulated".to_string(),
        b"".to_string(), b"".to_string(), ctx,
    );
    let deny = coin_registry::make_regulated(&mut builder, false, ctx);
    let (mut currency, metadata) = coin_registry::finalize_unwrap_for_testing(builder, ctx);
    currency.delete_metadata_cap(metadata);
    destroy(registry);
    (currency, treasury, deny)
}
