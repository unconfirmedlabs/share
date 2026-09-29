// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0
#[test_only]
module share::fixtures;

public struct Subject has key { id: UID }

public fun subject(ctx: &mut TxContext): Subject { Subject { id: object::new(ctx) } }
public fun uid(self: &mut Subject): &mut UID { &mut self.id }
public fun keep(self: Subject, owner: address) { transfer::transfer(self, owner) }
