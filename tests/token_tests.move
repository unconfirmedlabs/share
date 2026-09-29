// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0
#[test_only]
module share::token_tests;

use share::share::{Self, Issuance, IssuanceRegistry, Share};
use share::token::{Self, Tokenization};
use share::fixtures::{Self, Receipt, Subject};
use sui::coin;
use sui::test_scenario;
use std::type_name;
use std::unit_test::destroy;

public struct Wallet has key, store { id: UID, shares: Share }

#[test]
fun partial_conversion_coin_transfer_and_redemption() {
    let mut scenario = test_scenario::begin(@0x0);
    share::init_for_testing(scenario.ctx());
    scenario.next_tx(@0x0);
    let mut registry = scenario.take_shared<IssuanceRegistry>();
    let mut subject = fixtures::subject(scenario.ctx());
    let shares = share::initialize(&mut registry, subject.uid());
    transfer::public_transfer(Wallet { id: object::new(scenario.ctx()), shares }, @0x0);
    subject.keep(@0x0);
    test_scenario::return_shared(registry);
    scenario.next_tx(@0x0);
    let mut issuance = scenario.take_shared<Issuance>();
    let issuance_id = object::id(&issuance);
    let mut subject = scenario.take_from_sender<Subject>();
    let (mut currency, treasury, metadata) = fixtures::currency(6, scenario.ctx());
    currency.delete_metadata_cap(metadata);
    let mut conversion = token::initialize(&mut issuance, subject.uid(), &currency, treasury);
    assert!(object::id(&conversion) == token::derive_tokenization_id(&issuance));
    assert!(conversion.issuance_id() == issuance_id);
    assert!(issuance.token_type() == option::some(type_name::with_defining_ids<Receipt>()));
    let Wallet { id, mut shares } = scenario.take_from_sender<Wallet>();
    id.delete();
    let balance = conversion.tokenize(shares.split(1_500));
    assert!(shares.value() + conversion.tokenized_supply() == share::total_supply());
    let mut receipt = coin::from_balance(balance, scenario.ctx());
    let gift = receipt.split(500, scenario.ctx());
    transfer::public_transfer(gift, @0xB);
    transfer::public_transfer(receipt, @0x0);
    transfer::public_transfer(Wallet { id: object::new(scenario.ctx()), shares }, @0x0);
    token::share(conversion);
    test_scenario::return_shared(issuance);
    test_scenario::return_to_sender(&scenario, subject);
    destroy(currency);
    scenario.next_tx(@0xB);
    let mut conversion = scenario.take_shared<Tokenization<Receipt>>();
    let receipt = scenario.take_from_sender<coin::Coin<Receipt>>();
    let redeemed = conversion.detokenize(receipt.into_balance());
    assert!(redeemed.value() == 500);
    assert!(redeemed.issuance_id() == issuance_id);
    assert!(conversion.tokenized_supply() == 1_000);
    // B can redeem without subject authority; send native ownership back to A.
    transfer::public_transfer(Wallet { id: object::new(scenario.ctx()), shares: redeemed }, @0x0);
    test_scenario::return_shared(conversion);
    scenario.next_tx(@0x0);
    let mut conversion = scenario.take_shared<Tokenization<Receipt>>();
    let receipt = scenario.take_from_sender<coin::Coin<Receipt>>();
    let redeemed = conversion.detokenize(receipt.into_balance());
    let Wallet { id: id1, shares: s1 } = scenario.take_from_sender<Wallet>();
    let Wallet { id: id2, shares: s2 } = scenario.take_from_sender<Wallet>();
    id1.delete(); id2.delete();
    let mut all = redeemed;
    all.join_vec(vector[s1, s2]);
    assert!(all.value() == share::total_supply());
    assert!(conversion.tokenized_supply() == 0);
    transfer::public_transfer(Wallet { id: object::new(scenario.ctx()), shares: all }, @0x0);
    test_scenario::return_shared(conversion);
    scenario.end();
}

#[test]
fun repeated_partial_and_full_roundtrips_conserve_supply() {
    let ctx = &mut tx_context::dummy();
    let mut registry = share::registry_for_testing(ctx);
    let mut subject = fixtures::subject(ctx);
    let (mut issuance, mut shares) = share::initialize_for_testing(&mut registry, subject.uid());
    let (mut currency, treasury, metadata) = fixtures::currency(6, ctx);
    currency.delete_metadata_cap(metadata);
    let mut conversion = token::initialize(&mut issuance, subject.uid(), &currency, treasury);
    let mut coins = sui::balance::zero<Receipt>();
    let mut i = 0;
    while (i < 100) {
        coins.join(conversion.tokenize(shares.split(i * 37)));
        assert!(shares.value() + conversion.tokenized_supply() == share::total_supply());
        shares.join(conversion.detokenize(coins.split(i * 13)));
        assert!(shares.value() + conversion.tokenized_supply() == share::total_supply());
        i = i + 1;
    };
    shares.join(conversion.detokenize(coins));
    assert!(shares.value() == share::total_supply());
    let all = conversion.tokenize(shares.withdraw_all());
    shares.destroy_zero();
    assert!(all.value() == share::total_supply());
    let all = conversion.detokenize(all);
    assert!(all.value() == share::total_supply());
    assert!(conversion.tokenized_supply() == 0);
    let zero = conversion.tokenize(share::zero(&issuance));
    conversion.detokenize(zero).destroy_zero();
    destroy(all); destroy(conversion); destroy(currency);
    destroy(issuance); destroy(registry); destroy(subject);
}

#[test, expected_failure(abort_code = 0, location = token)]
fun nonzero_currency_rejected() {
    let ctx = &mut tx_context::dummy();
    let mut registry = share::registry_for_testing(ctx);
    let mut subject = fixtures::subject(ctx);
    let (mut issuance, shares) = share::initialize_for_testing(&mut registry, subject.uid());
    let (mut currency, mut treasury, metadata) = fixtures::currency(6, ctx);
    currency.delete_metadata_cap(metadata);
    let preexisting = treasury.mint_balance(1);
    let conversion = token::initialize(&mut issuance, subject.uid(), &currency, treasury);
    destroy(conversion); destroy(currency); destroy(issuance);
    destroy(shares); destroy(registry); destroy(subject); destroy(preexisting);
}

#[test, expected_failure(abort_code = 1, location = token)]
fun mutable_metadata_rejected() {
    let ctx = &mut tx_context::dummy();
    let mut registry = share::registry_for_testing(ctx);
    let mut subject = fixtures::subject(ctx);
    let (mut issuance, shares) = share::initialize_for_testing(&mut registry, subject.uid());
    let (currency, treasury, metadata) = fixtures::currency(6, ctx);
    let conversion = token::initialize(&mut issuance, subject.uid(), &currency, treasury);
    destroy(conversion); destroy(currency); destroy(issuance);
    destroy(shares); destroy(registry); destroy(subject); destroy(metadata);
}

#[test, expected_failure(abort_code = 2, location = token)]
fun wrong_decimals_rejected() {
    let ctx = &mut tx_context::dummy();
    let mut registry = share::registry_for_testing(ctx);
    let mut subject = fixtures::subject(ctx);
    let (mut issuance, shares) = share::initialize_for_testing(&mut registry, subject.uid());
    let (mut currency, treasury, metadata) = fixtures::currency(9, ctx);
    currency.delete_metadata_cap(metadata);
    let conversion = token::initialize(&mut issuance, subject.uid(), &currency, treasury);
    destroy(conversion); destroy(currency); destroy(issuance);
    destroy(shares); destroy(registry); destroy(subject); 
}

#[test, expected_failure(abort_code = 3, location = token)]
fun regulated_currency_rejected() {
    let ctx = &mut tx_context::dummy();
    let mut registry = share::registry_for_testing(ctx);
    let mut subject = fixtures::subject(ctx);
    let (mut issuance, shares) = share::initialize_for_testing(&mut registry, subject.uid());
    let (currency, treasury, deny) = fixtures::regulated(ctx);
    let conversion = token::initialize(&mut issuance, subject.uid(), &currency, treasury);
    destroy(conversion); destroy(currency); destroy(issuance);
    destroy(shares); destroy(registry); destroy(subject); destroy(deny);
}

#[test, expected_failure(abort_code = 4, location = token)]
fun noncanonical_treasury_rejected() {
    let ctx = &mut tx_context::dummy();
    let mut registry = share::registry_for_testing(ctx);
    let mut subject = fixtures::subject(ctx);
    let (mut issuance, shares) = share::initialize_for_testing(&mut registry, subject.uid());
    let (mut currency, treasury, metadata) = fixtures::currency(6, ctx);
    currency.delete_metadata_cap(metadata);
    let fake = coin::create_treasury_cap_for_testing<Receipt>(ctx);
    let conversion = token::initialize(&mut issuance, subject.uid(), &currency, fake);
    destroy(conversion); destroy(currency); destroy(issuance);
    destroy(shares); destroy(registry); destroy(subject); destroy(treasury);
}

#[test, expected_failure(abort_code = 3, location = share)]
fun foreign_subject_rejected() {
    let ctx = &mut tx_context::dummy();
    let mut registry = share::registry_for_testing(ctx);
    let mut subject = fixtures::subject(ctx);
    let (mut issuance, shares) = share::initialize_for_testing(&mut registry, subject.uid());
    let (mut currency, treasury, metadata) = fixtures::currency(6, ctx);
    currency.delete_metadata_cap(metadata);
    let mut foreign = fixtures::subject(ctx);
    let conversion = token::initialize(&mut issuance, foreign.uid(), &currency, treasury);
    destroy(conversion); destroy(currency); destroy(issuance);
    destroy(shares); destroy(registry); destroy(subject); destroy(foreign);
}

#[test, expected_failure(abort_code = 4, location = share)]
fun second_token_type_rejected() {
    let ctx = &mut tx_context::dummy();
    let mut registry = share::registry_for_testing(ctx);
    let mut subject = fixtures::subject(ctx);
    let (mut issuance, shares) = share::initialize_for_testing(&mut registry, subject.uid());
    let (mut currency, treasury, metadata) = fixtures::currency(6, ctx);
    currency.delete_metadata_cap(metadata);
    let first = token::initialize(&mut issuance, subject.uid(), &currency, treasury);
    let (other_currency, other_treasury) = fixtures::other_currency(ctx);
    let second = token::initialize(&mut issuance, subject.uid(), &other_currency, other_treasury);
    destroy(first); destroy(second); destroy(currency); destroy(other_currency);
    destroy(issuance); destroy(shares); destroy(registry); destroy(subject);
}

#[test, expected_failure(abort_code = 1, location = share)]
fun foreign_issuance_cannot_tokenize() {
    let ctx = &mut tx_context::dummy();
    let mut registry = share::registry_for_testing(ctx);
    let mut subject = fixtures::subject(ctx);
    let (mut issuance, shares) = share::initialize_for_testing(&mut registry, subject.uid());
    let (mut currency, treasury, metadata) = fixtures::currency(6, ctx);
    currency.delete_metadata_cap(metadata);
    let mut conversion = token::initialize(&mut issuance, subject.uid(), &currency, treasury);
    let mut foreign = fixtures::subject(ctx);
    let (foreign_issuance, foreign_shares) = share::initialize_for_testing(&mut registry, foreign.uid());
    let invalid = conversion.tokenize(foreign_shares);
    destroy(invalid); destroy(conversion); destroy(currency);
    destroy(foreign); destroy(foreign_issuance);
    destroy(issuance); destroy(shares); destroy(registry); destroy(subject);
}
