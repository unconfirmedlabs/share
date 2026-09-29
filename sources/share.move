// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Fixed-supply, subject-scoped ownership. No currency is needed until tokenization.
module share::share;

// === Imports ===

use sui::derived_object;
use sui::event;

// === Errors ===

const ENotEnough: u64 = 0;
const EIssuanceMismatch: u64 = 1;
const ENonZero: u64 = 2;

// === Structs ===

/// The only production registry is created at package initialization.
public struct IssuanceRegistry has key { id: UID }

/// Permanent ownership identity. Neither deletion nor mutable UID access is exposed.
public struct Issuance has key {
    id: UID,
    subject_id: ID,
}

/// Linear ownership units. Applications provide custody and revenue accounting.
public struct Share has store {
    issuance_id: ID,
    value: u64,
}

/// Derivation key scoped to the subject ID.
public struct IssuanceKey(ID) has copy, drop, store;

// === Events ===

public struct IssuanceRegistryCreatedEvent has copy, drop { registry_id: ID }
public struct IssuanceCreatedEvent has copy, drop { issuance_id: ID, subject_id: ID }

// === Public Functions ===

fun init(ctx: &mut TxContext) {
    let registry = IssuanceRegistry { id: object::new(ctx) };
    event::emit(IssuanceRegistryCreatedEvent { registry_id: object::id(&registry) });
    transfer::share_object(registry);
}

/// Subject UID access is the authorization boundary. The subject's defining
/// module must gate that access appropriately. Derived claims cannot be reused.
public fun initialize(registry: &mut IssuanceRegistry, subject: &mut UID): Share {
    let (issuance, shares) = create(registry, subject);
    event::emit(IssuanceCreatedEvent {
        issuance_id: object::id(&issuance),
        subject_id: issuance.subject_id,
    });
    transfer::share_object(issuance);
    shares
}

public fun zero(issuance: &Issuance): Share {
    Share { issuance_id: object::id(issuance), value: 0 }
}

/// Like Balance::join: consumes one value and returns the new total.
public fun join(self: &mut Share, share: Share): u64 {
    let Share { issuance_id, value } = share;
    assert!(self.issuance_id == issuance_id, EIssuanceMismatch);
    self.value = self.value + value;
    self.value
}

public fun join_vec(self: &mut Share, shares: vector<Share>) {
    shares.do!(|share| { self.join(share); });
}

public fun split(self: &mut Share, amount: u64): Share {
    assert!(self.value >= amount, ENotEnough);
    self.value = self.value - amount;
    Share { issuance_id: self.issuance_id, value: amount }
}

public fun withdraw_all(self: &mut Share): Share {
    let amount = self.value;
    self.split(amount)
}

public fun destroy_zero(self: Share) {
    let Share { issuance_id: _, value } = self;
    assert!(value == 0, ENonZero);
}

// === View Functions ===

/// Computes an address, not evidence that initialization has occurred.
public fun derive_issuance_id(registry: &IssuanceRegistry, subject_id: ID): ID {
    derived_object::derive_address(registry.id.to_inner(), IssuanceKey(subject_id)).to_id()
}

public fun subject_id(self: &Issuance): ID { self.subject_id }
public fun issuance_id(self: &Share): ID { self.issuance_id }
public fun value(self: &Share): u64 { self.value }
/// Fixed ownership units per issuance. Also the maximum possible token backing.
public macro fun max_supply(): u64 { 100_000_000_000_000 }

/// Standard decimal precision when representing ownership units as tokens.
public macro fun decimals(): u8 { 6 }

// === Private Functions ===

#[allow(unused_mut_parameter)]
fun create(registry: &mut IssuanceRegistry, subject: &mut UID): (Issuance, Share) {
    let subject_id = subject.to_inner();
    let issuance = Issuance {
        id: derived_object::claim(&mut registry.id, IssuanceKey(subject_id)),
        subject_id,
    };
    let shares = Share { issuance_id: object::id(&issuance), value: max_supply!() };
    (issuance, shares)
}

// === Test Functions ===

#[test_only]
public fun registry_for_testing(ctx: &mut TxContext): IssuanceRegistry {
    IssuanceRegistry { id: object::new(ctx) }
}

#[test_only]
public fun initialize_for_testing(
    registry: &mut IssuanceRegistry,
    subject: &mut UID,
): (Issuance, Share) { create(registry, subject) }

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) { init(ctx) }

/// Builds a bounded share fixture for tests that focus on downstream custody
/// and accounting. Production shares come only from `initialize`.
#[test_only]
public fun create_for_testing(issuance: &Issuance, value: u64): Share {
    assert!(value <= max_supply!(), ENotEnough);
    Share { issuance_id: object::id(issuance), value }
}

/// Builds a bounded fixture when the tested package stores only the issuance
/// ID. This bypasses authentic issuance and supply conservation; tests using
/// it do not prove either property. Use real issuance/split for integration.
#[test_only]
public fun create_for_testing_from_id(issuance_id: ID, value: u64): Share {
    assert!(value <= max_supply!(), ENotEnough);
    Share { issuance_id, value }
}
