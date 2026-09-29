// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Fixed-supply, subject-scoped ownership. No currency is needed until tokenization.
module share::share;

use std::type_name::{Self, TypeName};
use sui::derived_object;
use sui::event;

const SUPPLY: u64 = 100_000_000_000_000;
const ENotEnough: u64 = 0;
const EIssuanceMismatch: u64 = 1;
const ENonZero: u64 = 2;
const ESubjectMismatch: u64 = 3;
const EAlreadyTokenized: u64 = 4;

/// The only production registry is created at package initialization.
public struct IssuanceRegistry has key { id: UID }

/// Permanent ownership identity. Neither deletion nor mutable UID access is exposed.
public struct Issuance has key {
    id: UID,
    subject_id: ID,
    token_type: Option<TypeName>,
}

/// Linear ownership units. Applications provide custody and revenue accounting.
public struct Share has store {
    issuance_id: ID,
    value: u64,
}

public struct IssuanceKey(ID) has copy, drop, store;

public struct RegistryCreated has copy, drop { registry_id: ID }
public struct Issued has copy, drop { issuance_id: ID, subject_id: ID }

fun init(ctx: &mut TxContext) {
    let registry = IssuanceRegistry { id: object::new(ctx) };
    event::emit(RegistryCreated { registry_id: object::id(&registry) });
    transfer::share_object(registry);
}

/// Subject UID access is the authorization boundary. The subject's defining
/// module must gate that access appropriately. Derived claims cannot be reused.
public fun initialize(registry: &mut IssuanceRegistry, subject: &mut UID): Share {
    let (issuance, shares) = create(registry, subject);
    event::emit(Issued {
        issuance_id: object::id(&issuance),
        subject_id: issuance.subject_id,
    });
    transfer::share_object(issuance);
    shares
}

fun create(registry: &mut IssuanceRegistry, subject: &mut UID): (Issuance, Share) {
    let subject_id = subject.to_inner();
    let issuance = Issuance {
        id: derived_object::claim(&mut registry.id, IssuanceKey(subject_id)),
        subject_id,
        token_type: option::none(),
    };
    let shares = Share { issuance_id: object::id(&issuance), value: SUPPLY };
    (issuance, shares)
}

/// Computes an address, not evidence that initialization has occurred.
public fun derive_issuance_id(registry: &IssuanceRegistry, subject_id: ID): ID {
    derived_object::derive_address(registry.id.to_inner(), IssuanceKey(subject_id)).to_id()
}

public fun subject_id(self: &Issuance): ID { self.subject_id }
public fun token_type(self: &Issuance): Option<TypeName> { self.token_type }
public fun issuance_id(self: &Share): ID { self.issuance_id }
public fun value(self: &Share): u64 { self.value }
public fun total_supply(): u64 { SUPPLY }

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

/// Only token::initialize calls this after validating the currency and treasury.
public(package) fun bind_token<T>(self: &mut Issuance, subject: &mut UID): &mut UID {
    assert!(self.subject_id == subject.to_inner(), ESubjectMismatch);
    assert!(self.token_type.is_none(), EAlreadyTokenized);
    self.token_type = option::some(type_name::with_defining_ids<T>());
    &mut self.id
}

/// Trusted conversion boundary: every caller must mint exactly these units.
public(package) fun into_token_units(shares: Share, expected: ID): u64 {
    let Share { issuance_id, value } = shares;
    assert!(issuance_id == expected, EIssuanceMismatch);
    value
}

/// Trusted conversion boundary: every caller must first burn these units.
public(package) fun from_token_units(issuance_id: ID, value: u64): Share {
    Share { issuance_id, value }
}

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
