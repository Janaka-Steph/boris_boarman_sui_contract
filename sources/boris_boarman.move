#[allow(duplicate_alias)]
module boris_boarman::FundRelease {

use sui::table;
use sui::object::{Self, UID};
use sui::tx_context::{Self, TxContext};
use sui::coin::{Self, Coin};
use sui::sui::SUI;
use sui::event;
use sui::transfer;

/// Error codes
const EUnauthorized: u64 = 0;
const EInvalidAmount: u64 = 1;
const EProposalNotActive: u64 = 3;
const EInvalidProposal: u64 = 4;

/// Status values for proposals
const ACTIVE: u8 = 0;
const COMPLETED: u8 = 1;

// Events
public struct ProposalCreated has copy, drop {
    proposal_id: u64,
    creator: address,
    recipient: address,
    amount: u64,
}

public struct FundsReleased has copy, drop {
    proposal_id: u64,
    recipient: address,
    amount: u64,
    timestamp: u64,
}

// Public struct to represent an approved funding proposal
public struct FundingProposal has key, store {
    id: UID,                      // Sui's internal unique identifier for objects
    proposal_id: u64,             // Application-level ID for the proposal
    creator: address,             // Address that created the proposal
    recipient: address,           // Address to release funds to
    approved_amount: u64,         // Approved funding amount
    status: u8,                   // Current status of the proposal
    completion_time: Option<u64>, // Timestamp when proposal was completed
    created_at: u64,              // Timestamp when proposal was created
}

// Public struct to store funding proposals by Proposal ID
public struct FundingProposals has key {
    id: UID,                                       // Sui's internal unique identifier for objects
    proposals: table::Table<u64, FundingProposal>, // Table to store proposals by ID
    admin: address,                                // Admin address (backend server) authorized to release funds
    next_proposal_id: u64                          // Next proposal ID to be used
}

// Initializes the contract with an empty table for proposals
fun init(ctx: &mut TxContext) {
    let admin = tx_context::sender(ctx);
    let proposals = FundingProposals {
        id: object::new(ctx),
        proposals: table::new(ctx),
        admin,
        next_proposal_id: 0
    };
    transfer::share_object(proposals);
}

#[test_only]
public fun test_init(ctx: &mut TxContext) {
    init(ctx)
}

// Create a new funding proposal (can be created by anyone)
public fun create_proposal(
    proposals: &mut FundingProposals, 
    recipient: address, 
    approved_amount: u64, 
    ctx: &mut TxContext
) {
    let creator = tx_context::sender(ctx);
    let proposal_id = proposals.next_proposal_id;
    
    // Amount must be greater than 0
    assert!(approved_amount > 0, EInvalidAmount);
    
    // Create and store the proposal
    table::add(&mut proposals.proposals, proposal_id, FundingProposal {
        id: object::new(ctx),
        proposal_id,
        creator,
        recipient,
        approved_amount,
        status: ACTIVE,
        completion_time: option::none(),
        created_at: tx_context::epoch(ctx),
    });

    // Increment the proposal ID for next use
    proposals.next_proposal_id = proposal_id + 1;

    // Emit creation event
    event::emit(ProposalCreated {
        proposal_id,
        creator,
        recipient,
        amount: approved_amount,
    });
}

// Release funds for a specific proposal (only admin/backend can release)
public fun release_funds(
    proposals: &mut FundingProposals, 
    proposal_id: u64, 
    payment: Coin<SUI>, 
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);

    // Only the admin (backend server) can release funds
    assert!(sender == proposals.admin, EUnauthorized);

    // Check if the proposal exists
    assert!(table::contains(&proposals.proposals, proposal_id), EInvalidProposal);
    
    let proposal = table::borrow_mut(&mut proposals.proposals, proposal_id);
    
    // Ensure proposal is active
    assert!(proposal.status == ACTIVE, EProposalNotActive);
    
    // Ensure the payment amount matches the approved amount
    assert!(coin::value(&payment) == proposal.approved_amount, EInvalidAmount);
    
    // Update the proposal status before transfer
    proposal.status = COMPLETED;
    proposal.completion_time = option::some(tx_context::epoch(ctx));

    // Transfer funds to the recipient
    transfer::public_transfer(payment, proposal.recipient);

    // Emit funds released event
    event::emit(FundsReleased {
        proposal_id,
        recipient: proposal.recipient,
        amount: proposal.approved_amount,
        timestamp: tx_context::epoch(ctx),
    });
}

// View functions
public fun get_proposal_status(proposals: &FundingProposals, proposal_id: u64): u8 {
    let proposal = table::borrow(&proposals.proposals, proposal_id);
    proposal.status
}

public fun get_proposal_amount(proposals: &FundingProposals, proposal_id: u64): u64 {
    let proposal = table::borrow(&proposals.proposals, proposal_id);
    proposal.approved_amount
}

public fun get_proposal_recipient(proposals: &FundingProposals, proposal_id: u64): address {
    let proposal = table::borrow(&proposals.proposals, proposal_id);
    proposal.recipient
}

public fun get_proposal_creator(proposals: &FundingProposals, proposal_id: u64): address {
    let proposal = table::borrow(&proposals.proposals, proposal_id);
    proposal.creator
}
}
