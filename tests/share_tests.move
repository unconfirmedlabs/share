// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0
#[test_only]
module share::share_tests;

use share::share::{Self, Issuance, IssuanceRegistry, Share};
use share::fixtures::{Self};
use std::unit_test::destroy;
use sui::test_scenario;

public struct Wallet has key, store { id: UID, shares: Share }

#[test]
fun production_lifecycle_and_discovery() {
    let mut scenario = test_scenario::begin(@0xA);
    share::init_for_testing(scenario.ctx());
    scenario.next_tx(@0xA);
    let mut registry = scenario.take_shared<IssuanceRegistry>();
    let mut subject = fixtures::subject(scenario.ctx());
    let subject_id = object::id(&subject);
    let expected = share::derive_issuance_id(&registry, subject_id);
    let shares = share::initialize(&mut registry, subject.uid());
    assert!(shares.issuance_id() == expected);
    transfer::public_transfer(Wallet { id: object::new(scenario.ctx()), shares }, @0xA);
    subject.keep(@0xA);
    test_scenario::return_shared(registry);
    scenario.next_tx(@0xA);
    let issuance = scenario.take_shared<Issuance>();
    assert!(object::id(&issuance) == expected);
    assert!(issuance.subject_id() == subject_id);
    assert!(issuance.token_type().is_none());
    let Wallet { id, mut shares } = scenario.take_from_sender<Wallet>();
    id.delete();
    assert!(shares.value() == share::total_supply());
    let gift = shares.split(500);
    transfer::public_transfer(Wallet { id: object::new(scenario.ctx()), shares: gift }, @0xB);
    transfer::public_transfer(Wallet { id: object::new(scenario.ctx()), shares }, @0xA);
    test_scenario::return_shared(issuance);
    scenario.next_tx(@0xB);
    let wallet = scenario.take_from_sender<Wallet>();
    assert!(wallet.shares.issuance_id() == expected);
    assert!(wallet.shares.value() == 500);
    test_scenario::return_to_sender(&scenario, wallet);
    scenario.end();
}

#[test]
fun split_join_and_zero_conserve_supply() {
    let ctx = &mut tx_context::dummy();
    let mut registry = share::registry_for_testing(ctx);
    let mut subject = fixtures::subject(ctx);
    let (issuance, mut shares) = share::initialize_for_testing(&mut registry, subject.uid());
    let mut artist = shares.split(15_000);
    let fans = artist.split(5_000);
    assert!(artist.value() == 10_000);
    assert!(fans.issuance_id() == object::id(&issuance));
    shares.join_vec(vector[artist, fans]);
    shares.join_vec(vector[]);
    assert!(shares.join(share::zero(&issuance)) == share::total_supply());
    shares.split(0).destroy_zero();
    let all = shares.withdraw_all();
    shares.destroy_zero();
    assert!(all.value() == share::total_supply());
    destroy(all); destroy(issuance); destroy(registry); destroy(subject);
}

#[test]
fun subjects_have_independent_issuances() {
    let ctx = &mut tx_context::dummy();
    let mut registry = share::registry_for_testing(ctx);
    let mut a = fixtures::subject(ctx);
    let mut b = fixtures::subject(ctx);
    let (ia, sa) = share::initialize_for_testing(&mut registry, a.uid());
    let (ib, sb) = share::initialize_for_testing(&mut registry, b.uid());
    assert!(sa.issuance_id() != sb.issuance_id());
    assert!(sa.value() == sb.value());
    destroy(ia); destroy(sa); destroy(ib); destroy(sb); destroy(registry); destroy(a); destroy(b);
}

#[test, expected_failure(abort_code = sui::derived_object::EObjectAlreadyExists)]
fun duplicate_issuance_rejected() {
    let ctx = &mut tx_context::dummy();
    let mut registry = share::registry_for_testing(ctx);
    let mut subject = fixtures::subject(ctx);
    let (first, first_shares) = share::initialize_for_testing(&mut registry, subject.uid());
    // Even disposal of the original issuance does not free the registry claim.
    destroy(first); destroy(first_shares);
    let (second, second_shares) = share::initialize_for_testing(&mut registry, subject.uid());
    destroy(second); destroy(second_shares); destroy(registry); destroy(subject);
}

#[test, expected_failure(abort_code = 0, location = share)]
fun oversplit_rejected() {
    let ctx = &mut tx_context::dummy();
    let mut registry = share::registry_for_testing(ctx);
    let mut subject = fixtures::subject(ctx);
    let (issuance, mut shares) = share::initialize_for_testing(&mut registry, subject.uid());
    let invalid = shares.split(share::total_supply() + 1);
    destroy(invalid); destroy(shares); destroy(issuance); destroy(registry); destroy(subject);
}

#[test, expected_failure(abort_code = 2, location = share)]
fun nonzero_destruction_rejected() {
    let ctx = &mut tx_context::dummy();
    let mut registry = share::registry_for_testing(ctx);
    let mut subject = fixtures::subject(ctx);
    let (issuance, shares) = share::initialize_for_testing(&mut registry, subject.uid());
    shares.destroy_zero();
    destroy(issuance); destroy(registry); destroy(subject);
}

#[test, expected_failure(abort_code = 1, location = share)]
fun cross_issuance_join_rejected() {
    let ctx = &mut tx_context::dummy();
    let mut registry = share::registry_for_testing(ctx);
    let mut a = fixtures::subject(ctx);
    let mut b = fixtures::subject(ctx);
    let (ia, mut sa) = share::initialize_for_testing(&mut registry, a.uid());
    let (ib, sb) = share::initialize_for_testing(&mut registry, b.uid());
    sa.join(sb);
    destroy(ia); destroy(ib); destroy(sa); destroy(registry); destroy(a); destroy(b);
}

#[test, expected_failure(abort_code = 1, location = share)]
fun vector_join_checks_every_element_including_zero() {
    let ctx = &mut tx_context::dummy();
    let mut registry = share::registry_for_testing(ctx);
    let mut a = fixtures::subject(ctx);
    let mut b = fixtures::subject(ctx);
    let (ia, mut sa) = share::initialize_for_testing(&mut registry, a.uid());
    let (ib, sb) = share::initialize_for_testing(&mut registry, b.uid());
    let valid = sa.split(100);
    sa.join_vec(vector[valid, share::zero(&ib)]);
    destroy(ia); destroy(ib); destroy(sa); destroy(sb); destroy(registry); destroy(a); destroy(b);
}
