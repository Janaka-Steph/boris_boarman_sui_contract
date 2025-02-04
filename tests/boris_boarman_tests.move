#[test_only]
module boris_boarman::boris_boarman_tests {
    use sui::test_scenario as ts;
    use sui::coin;
    use sui::sui::SUI;
    use boris_boarman::FundRelease::{Self, FundingProposals};

    // Test addresses
    const ADMIN: address = @0xAD;
    const USER1: address = @0x42;
    const USER2: address = @0x43;

    // Test setup helper function
    fun setup_test(scenario: &mut ts::Scenario) {
        // Start with admin account
        ts::next_tx(scenario, ADMIN);
        {
            FundRelease::test_init(ts::ctx(scenario));
        }
    }

    #[test]
    fun test_create_proposal() {
        // Initialize scenario with ADMIN account
        let mut scenario = ts::begin(ADMIN);
        setup_test(&mut scenario);

        // Create a proposal as USER1
        ts::next_tx(&mut scenario, USER1);
        {
            let mut proposals = ts::take_shared<FundingProposals>(&scenario);
            FundRelease::create_proposal(&mut proposals, USER2, 1000, ts::ctx(&mut scenario));
            ts::return_shared(proposals);
        };

        // Verify proposal was created correctly
        ts::next_tx(&mut scenario, USER1);
        {
            let proposals = ts::take_shared<FundingProposals>(&scenario);
            assert!(FundRelease::get_proposal_creator(&proposals, 0) == USER1, 0);
            ts::return_shared(proposals);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = FundRelease::EUnauthorized)]
    fun test_unauthorized_release() {
        // Initialize scenario with ADMIN account
        let mut scenario = ts::begin(ADMIN);
        setup_test(&mut scenario);

        // Create a proposal as USER1
        ts::next_tx(&mut scenario, USER1);
        {
            let mut proposals = ts::take_shared<FundingProposals>(&scenario);
            FundRelease::create_proposal(&mut proposals, USER2, 1000, ts::ctx(&mut scenario));
            ts::return_shared(proposals);
        };

        // Try to release funds with non-admin account (should fail)
        ts::next_tx(&mut scenario, USER1);
        {
            let coin = coin::mint_for_testing<SUI>(1000, ts::ctx(&mut scenario));
            let mut proposals = ts::take_shared<FundingProposals>(&scenario);
            FundRelease::release_funds(&mut proposals, 0, coin, ts::ctx(&mut scenario));
            ts::return_shared(proposals);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_successful_release() {
        // Initialize scenario with ADMIN account
        let mut scenario = ts::begin(ADMIN);
        setup_test(&mut scenario);

        // Create a proposal as USER1
        ts::next_tx(&mut scenario, USER1);
        {
            let mut proposals = ts::take_shared<FundingProposals>(&scenario);
            FundRelease::create_proposal(&mut proposals, USER2, 1000, ts::ctx(&mut scenario));
            ts::return_shared(proposals);
        };

        // Release funds as ADMIN (should succeed)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let coin = coin::mint_for_testing<SUI>(1000, ts::ctx(&mut scenario));
            let mut proposals = ts::take_shared<FundingProposals>(&scenario);
            FundRelease::release_funds(&mut proposals, 0, coin, ts::ctx(&mut scenario));
            ts::return_shared(proposals);
        };

        ts::end(scenario);
    }
}
