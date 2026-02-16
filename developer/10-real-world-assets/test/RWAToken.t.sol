// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {IdentityRegistry} from "../contracts/IdentityRegistry.sol";
import {RWAToken} from "../contracts/RWAToken.sol";

contract RWATokenTest is Test {
    IdentityRegistry internal registry;
    RWAToken internal token;

    address internal admin = makeAddr("admin");
    address internal complianceOfficer = makeAddr("complianceOfficer");
    address internal agent = makeAddr("agent");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal charlie = makeAddr("charlie");
    address internal eve = makeAddr("eve"); // non-whitelisted

    uint16 internal constant COUNTRY_US = 840;
    uint16 internal constant COUNTRY_DE = 276;
    uint16 internal constant COUNTRY_KP = 408; // restricted country

    uint256 internal constant INITIAL_SUPPLY = 1_000_000e18;
    uint256 internal constant TRANSFER_AMOUNT = 10_000e18;

    // -----------------------------------------------------------------------
    // Setup
    // -----------------------------------------------------------------------

    function setUp() public {
        // Deploy as admin
        vm.startPrank(admin);

        registry = new IdentityRegistry();
        token = new RWAToken("RWA Property Token", "RWAP", address(registry), INITIAL_SUPPLY);

        // Grant roles
        token.grantRole(token.COMPLIANCE_OFFICER_ROLE(), complianceOfficer);
        token.grantRole(token.AGENT_ROLE(), agent);

        // Set compliance officer on registry
        registry.setComplianceOfficer(complianceOfficer, true);

        // Register investors in whitelist
        registry.addInvestor(admin, COUNTRY_US);
        registry.addInvestor(alice, COUNTRY_US);
        registry.addInvestor(bob, COUNTRY_DE);
        registry.addInvestor(charlie, COUNTRY_KP);

        // Distribute tokens to investors
        token.transfer(alice, TRANSFER_AMOUNT * 5);
        token.transfer(bob, TRANSFER_AMOUNT * 3);

        vm.stopPrank();
    }

    // -----------------------------------------------------------------------
    // Whitelisted Transfer Works
    // -----------------------------------------------------------------------

    function test_transfer_whitelistedSucceeds() public {
        vm.prank(alice);
        bool success = token.transfer(bob, TRANSFER_AMOUNT);

        assertTrue(success);
        assertEq(token.balanceOf(bob), TRANSFER_AMOUNT * 3 + TRANSFER_AMOUNT);
    }

    function test_transferFrom_whitelistedSucceeds() public {
        vm.prank(alice);
        token.approve(bob, TRANSFER_AMOUNT);

        vm.prank(bob);
        bool success = token.transferFrom(alice, bob, TRANSFER_AMOUNT);

        assertTrue(success);
    }

    // -----------------------------------------------------------------------
    // Non-Whitelisted Transfer Reverts
    // -----------------------------------------------------------------------

    function test_transfer_nonWhitelistedSenderReverts() public {
        // Eve is not whitelisted
        vm.prank(eve);
        vm.expectRevert(
            abi.encodeWithSelector(RWAToken.SenderNotWhitelisted.selector, eve)
        );
        token.transfer(alice, 1);
    }

    function test_transfer_nonWhitelistedReceiverReverts() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(RWAToken.ReceiverNotWhitelisted.selector, eve)
        );
        token.transfer(eve, TRANSFER_AMOUNT);
    }

    // -----------------------------------------------------------------------
    // Freeze Account Blocks Transfers
    // -----------------------------------------------------------------------

    function test_freeze_blocksSending() public {
        vm.prank(complianceOfficer);
        token.freezeAccount(alice);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(RWAToken.AccountFrozenError.selector, alice)
        );
        token.transfer(bob, TRANSFER_AMOUNT);
    }

    function test_freeze_blocksReceiving() public {
        vm.prank(complianceOfficer);
        token.freezeAccount(bob);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(RWAToken.AccountFrozenError.selector, bob)
        );
        token.transfer(bob, TRANSFER_AMOUNT);
    }

    function test_unfreeze_allowsTransferAgain() public {
        vm.startPrank(complianceOfficer);
        token.freezeAccount(alice);
        token.unfreezeAccount(alice);
        vm.stopPrank();

        vm.prank(alice);
        bool success = token.transfer(bob, TRANSFER_AMOUNT);
        assertTrue(success);
    }

    function test_freeze_emitsEvent() public {
        vm.prank(complianceOfficer);

        vm.expectEmit(true, false, false, false);
        emit RWAToken.AccountFrozen(alice);

        token.freezeAccount(alice);
    }

    function test_unfreeze_revertsIfNotFrozen() public {
        vm.prank(complianceOfficer);
        vm.expectRevert(
            abi.encodeWithSelector(RWAToken.AccountNotFrozen.selector, alice)
        );
        token.unfreezeAccount(alice);
    }

    // -----------------------------------------------------------------------
    // Pause Blocks All Transfers
    // -----------------------------------------------------------------------

    function test_pause_blocksAllTransfers() public {
        vm.prank(agent);
        token.pause();

        vm.prank(alice);
        vm.expectRevert(RWAToken.TransfersPaused.selector);
        token.transfer(bob, TRANSFER_AMOUNT);
    }

    function test_unpause_allowsTransfersAgain() public {
        vm.prank(agent);
        token.pause();

        vm.prank(agent);
        token.unpause();

        vm.prank(alice);
        bool success = token.transfer(bob, TRANSFER_AMOUNT);
        assertTrue(success);
    }

    function test_pause_emitsEvent() public {
        vm.prank(agent);

        vm.expectEmit(true, false, false, false);
        emit RWAToken.Paused(agent);

        token.pause();
    }

    // -----------------------------------------------------------------------
    // Force Transfer by Compliance Officer
    // -----------------------------------------------------------------------

    function test_forceTransfer_byComplianceOfficerSucceeds() public {
        uint256 aliceBefore = token.balanceOf(alice);
        uint256 bobBefore = token.balanceOf(bob);

        vm.prank(complianceOfficer);

        vm.expectEmit(true, true, true, true);
        emit RWAToken.ForcedTransfer(alice, bob, TRANSFER_AMOUNT, complianceOfficer);

        token.forceTransfer(alice, bob, TRANSFER_AMOUNT);

        assertEq(token.balanceOf(alice), aliceBefore - TRANSFER_AMOUNT);
        assertEq(token.balanceOf(bob), bobBefore + TRANSFER_AMOUNT);
    }

    function test_forceTransfer_worksEvenWhenPaused() public {
        vm.prank(agent);
        token.pause();

        vm.prank(complianceOfficer);
        // forceTransfer does NOT check whenNotPaused
        token.forceTransfer(alice, bob, TRANSFER_AMOUNT);

        // Verify transfer happened
        assertEq(token.balanceOf(bob), TRANSFER_AMOUNT * 3 + TRANSFER_AMOUNT);
    }

    function test_forceTransfer_worksOnFrozenAccounts() public {
        vm.startPrank(complianceOfficer);
        token.freezeAccount(alice);
        // forceTransfer bypasses freeze checks
        token.forceTransfer(alice, bob, TRANSFER_AMOUNT);
        vm.stopPrank();

        assertEq(token.balanceOf(bob), TRANSFER_AMOUNT * 3 + TRANSFER_AMOUNT);
    }

    // -----------------------------------------------------------------------
    // Cannot Force Transfer Without Role
    // -----------------------------------------------------------------------

    function test_forceTransfer_revertsWithoutRole() public {
        vm.prank(alice);
        vm.expectRevert(RWAToken.NotComplianceOfficer.selector);
        token.forceTransfer(bob, alice, TRANSFER_AMOUNT);
    }

    function test_freezeAccount_revertsWithoutRole() public {
        vm.prank(alice);
        vm.expectRevert(RWAToken.NotComplianceOfficer.selector);
        token.freezeAccount(bob);
    }

    function test_pause_revertsWithoutRole() public {
        vm.prank(alice);
        vm.expectRevert(RWAToken.NotAgent.selector);
        token.pause();
    }

    // -----------------------------------------------------------------------
    // Country Restriction Works
    // -----------------------------------------------------------------------

    function test_countryRestriction_blocksTransferFromRestrictedCountry() public {
        // Charlie is from COUNTRY_KP (restricted)
        // First give charlie some tokens via force transfer
        vm.startPrank(complianceOfficer);
        token.forceTransfer(admin, charlie, TRANSFER_AMOUNT);

        // Restrict COUNTRY_KP
        registry.restrictCountry(COUNTRY_KP);
        vm.stopPrank();

        // Charlie cannot send tokens
        vm.prank(charlie);
        vm.expectRevert(
            abi.encodeWithSelector(RWAToken.SenderCountryRestricted.selector, charlie)
        );
        token.transfer(alice, 1_000e18);
    }

    function test_countryRestriction_blocksTransferToRestrictedCountry() public {
        // Restrict COUNTRY_KP
        vm.prank(complianceOfficer);
        registry.restrictCountry(COUNTRY_KP);

        // Cannot send tokens to charlie (COUNTRY_KP)
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(RWAToken.ReceiverCountryRestricted.selector, charlie)
        );
        token.transfer(charlie, TRANSFER_AMOUNT);
    }

    function test_countryUnrestriction_allowsTransferAgain() public {
        vm.startPrank(complianceOfficer);
        registry.restrictCountry(COUNTRY_KP);
        registry.unrestrictCountry(COUNTRY_KP);

        // Give charlie tokens
        token.forceTransfer(admin, charlie, TRANSFER_AMOUNT);
        vm.stopPrank();

        // Charlie can send after unrestriction
        vm.prank(charlie);
        bool success = token.transfer(alice, 1_000e18);
        assertTrue(success);
    }

    // -----------------------------------------------------------------------
    // Add/Remove Investors from Whitelist
    // -----------------------------------------------------------------------

    function test_addInvestor_allowsTransfers() public {
        // Register eve as investor
        vm.prank(complianceOfficer);
        registry.addInvestor(eve, COUNTRY_US);

        // Give eve some tokens via force transfer
        vm.prank(complianceOfficer);
        token.forceTransfer(admin, eve, TRANSFER_AMOUNT);

        // Eve can now transfer
        vm.prank(eve);
        bool success = token.transfer(alice, 1_000e18);
        assertTrue(success);
    }

    function test_removeInvestor_blocksTransfers() public {
        // Remove alice from whitelist
        vm.prank(complianceOfficer);
        registry.removeInvestor(alice);

        // Alice can no longer send
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(RWAToken.SenderNotWhitelisted.selector, alice)
        );
        token.transfer(bob, TRANSFER_AMOUNT);
    }

    function test_removeInvestor_blocksReceiving() public {
        vm.prank(complianceOfficer);
        registry.removeInvestor(bob);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(RWAToken.ReceiverNotWhitelisted.selector, bob)
        );
        token.transfer(bob, TRANSFER_AMOUNT);
    }

    // -----------------------------------------------------------------------
    // Role-Based Access Control
    // -----------------------------------------------------------------------

    function test_grantRole_onlyAdmin() public {
        address newOfficer = makeAddr("newOfficer");

        vm.prank(admin);
        token.grantRole(token.COMPLIANCE_OFFICER_ROLE(), newOfficer);

        assertTrue(token.hasRole(token.COMPLIANCE_OFFICER_ROLE(), newOfficer));
    }

    function test_grantRole_revertsForNonAdmin() public {
        vm.prank(alice);
        vm.expectRevert(RWAToken.NotAdmin.selector);
        token.grantRole(token.COMPLIANCE_OFFICER_ROLE(), alice);
    }

    function test_revokeRole_removesPermission() public {
        vm.startPrank(admin);
        token.revokeRole(token.COMPLIANCE_OFFICER_ROLE(), complianceOfficer);
        vm.stopPrank();

        assertFalse(token.hasRole(token.COMPLIANCE_OFFICER_ROLE(), complianceOfficer));

        // Compliance officer can no longer freeze accounts
        vm.prank(complianceOfficer);
        vm.expectRevert(RWAToken.NotComplianceOfficer.selector);
        token.freezeAccount(alice);
    }

    // -----------------------------------------------------------------------
    // Token Recovery
    // -----------------------------------------------------------------------

    function test_recoverTokens_movesAllTokensToNewWallet() public {
        address newAliceWallet = makeAddr("newAliceWallet");

        // Register new wallet
        vm.startPrank(complianceOfficer);
        registry.addInvestor(newAliceWallet, COUNTRY_US);

        uint256 aliceBalance = token.balanceOf(alice);

        vm.expectEmit(true, true, true, true);
        emit RWAToken.TokenRecovery(alice, newAliceWallet, aliceBalance, complianceOfficer);

        token.recoverTokens(alice, newAliceWallet);
        vm.stopPrank();

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(newAliceWallet), aliceBalance);
    }

    function test_recoverTokens_revertsForNonWhitelistedNewWallet() public {
        vm.prank(complianceOfficer);
        vm.expectRevert(
            abi.encodeWithSelector(RWAToken.ReceiverNotWhitelisted.selector, eve)
        );
        token.recoverTokens(alice, eve);
    }

    function test_recoverTokens_revertsWithoutRole() public {
        vm.prank(alice);
        vm.expectRevert(RWAToken.NotComplianceOfficer.selector);
        token.recoverTokens(bob, alice);
    }

    function test_recoverTokens_revertsForSameAddress() public {
        vm.prank(complianceOfficer);
        vm.expectRevert(RWAToken.SameAddress.selector);
        token.recoverTokens(alice, alice);
    }

    function test_recoverTokens_revertsForZeroBalance() public {
        address emptyWallet = makeAddr("emptyWallet");
        address newWallet = makeAddr("newWallet");

        vm.startPrank(complianceOfficer);
        registry.addInvestor(emptyWallet, COUNTRY_US);
        registry.addInvestor(newWallet, COUNTRY_US);

        vm.expectRevert(RWAToken.ZeroAmount.selector);
        token.recoverTokens(emptyWallet, newWallet);
        vm.stopPrank();
    }

    // -----------------------------------------------------------------------
    // Edge Cases
    // -----------------------------------------------------------------------

    function test_transfer_revertsOnInsufficientBalance() public {
        uint256 aliceBalance = token.balanceOf(alice);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                RWAToken.InsufficientBalance.selector,
                aliceBalance,
                aliceBalance + 1
            )
        );
        token.transfer(bob, aliceBalance + 1);
    }

    function test_transferFrom_revertsOnInsufficientAllowance() public {
        vm.prank(alice);
        token.approve(bob, 100);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(RWAToken.InsufficientAllowance.selector, 100, 200)
        );
        token.transferFrom(alice, bob, 200);
    }
}
