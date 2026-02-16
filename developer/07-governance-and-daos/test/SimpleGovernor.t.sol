// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {GovernanceToken} from "../contracts/GovernanceToken.sol";
import {SimpleGovernor} from "../contracts/SimpleGovernor.sol";
import {Treasury} from "../contracts/Treasury.sol";

contract SimpleGovernorTest is Test {
    GovernanceToken public token;
    SimpleGovernor public governor;
    Treasury public treasury;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public carol = makeAddr("carol");
    address public recipient = makeAddr("recipient");

    uint256 constant VOTING_DELAY = 1;     // 1 block
    uint256 constant VOTING_PERIOD = 50;   // 50 blocks
    uint256 constant TIMELOCK_DELAY = 10;  // 10 blocks
    uint256 constant QUORUM_BPS = 400;     // 4%

    uint256 constant ALICE_TOKENS = 600_000e18;  // 60%
    uint256 constant BOB_TOKENS = 300_000e18;    // 30%
    uint256 constant CAROL_TOKENS = 100_000e18;  // 10%

    function setUp() public {
        // Deploy GovernanceToken with initial distribution
        address[] memory holders = new address[](3);
        holders[0] = alice;
        holders[1] = bob;
        holders[2] = carol;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = ALICE_TOKENS;
        amounts[1] = BOB_TOKENS;
        amounts[2] = CAROL_TOKENS;

        token = new GovernanceToken(holders, amounts);

        // Deploy Governor
        governor = new SimpleGovernor(
            address(token),
            VOTING_DELAY,
            VOTING_PERIOD,
            TIMELOCK_DELAY,
            QUORUM_BPS
        );

        // Deploy Treasury controlled by Governor
        treasury = new Treasury(address(governor));

        // Fund treasury
        vm.deal(address(treasury), 100 ether);

        // Delegate voting power (users must delegate to activate votes)
        vm.prank(alice);
        token.delegate(alice);

        vm.prank(bob);
        token.delegate(bob);

        vm.prank(carol);
        token.delegate(carol);
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    function _createSendEthProposal(address to, uint256 amount)
        internal
        returns (uint256 proposalId)
    {
        address[] memory targets = new address[](1);
        targets[0] = address(treasury);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature(
            "execute(address,uint256,bytes)",
            to,
            amount,
            ""
        );

        string memory description = "Send ETH from treasury";

        vm.prank(alice);
        proposalId = governor.propose(targets, values, calldatas, description);
    }

    function _advanceBlocks(uint256 blocks) internal {
        vm.roll(block.number + blocks);
    }

    // =========================================================================
    // Proposal Creation Tests
    // =========================================================================

    function test_CreateProposal() public {
        uint256 proposalId = _createSendEthProposal(recipient, 1 ether);

        assertEq(proposalId, 1);
        assertEq(uint256(governor.state(proposalId)), uint256(SimpleGovernor.ProposalState.Pending));
    }

    function test_CreateProposal_EmitsEvent() public {
        address[] memory targets = new address[](1);
        targets[0] = address(treasury);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature(
            "execute(address,uint256,bytes)",
            recipient,
            1 ether,
            ""
        );

        vm.prank(alice);
        vm.expectEmit(true, true, false, false);
        emit SimpleGovernor.ProposalCreated(
            1, alice, targets, values, calldatas, "Send ETH",
            block.number + VOTING_DELAY,
            block.number + VOTING_DELAY + VOTING_PERIOD
        );
        governor.propose(targets, values, calldatas, "Send ETH");
    }

    function test_CreateProposal_RevertsOnEmptyTargets() public {
        address[] memory targets = new address[](0);
        uint256[] memory values = new uint256[](0);
        bytes[] memory calldatas = new bytes[](0);

        vm.prank(alice);
        vm.expectRevert(SimpleGovernor.InvalidProposal.selector);
        governor.propose(targets, values, calldatas, "Empty proposal");
    }

    function test_CreateProposal_RevertsOnLengthMismatch() public {
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](2);

        vm.prank(alice);
        vm.expectRevert(SimpleGovernor.ArrayLengthMismatch.selector);
        governor.propose(targets, values, calldatas, "Mismatched");
    }

    // =========================================================================
    // Voting Tests
    // =========================================================================

    function test_VoteDuringVotingPeriod() public {
        uint256 proposalId = _createSendEthProposal(recipient, 1 ether);

        // Advance past voting delay
        _advanceBlocks(VOTING_DELAY + 1);

        assertEq(uint256(governor.state(proposalId)), uint256(SimpleGovernor.ProposalState.Active));

        vm.prank(alice);
        governor.vote(proposalId, 1); // For

        (uint256 forVotes, uint256 againstVotes, uint256 abstainVotes) =
            governor.proposalVotes(proposalId);
        assertEq(forVotes, ALICE_TOKENS);
        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 0);
    }

    function test_VoteAgainst() public {
        uint256 proposalId = _createSendEthProposal(recipient, 1 ether);
        _advanceBlocks(VOTING_DELAY + 1);

        vm.prank(bob);
        governor.vote(proposalId, 0); // Against

        (, uint256 againstVotes,) = governor.proposalVotes(proposalId);
        assertEq(againstVotes, BOB_TOKENS);
    }

    function test_VoteAbstain() public {
        uint256 proposalId = _createSendEthProposal(recipient, 1 ether);
        _advanceBlocks(VOTING_DELAY + 1);

        vm.prank(carol);
        governor.vote(proposalId, 2); // Abstain

        (,, uint256 abstainVotes) = governor.proposalVotes(proposalId);
        assertEq(abstainVotes, CAROL_TOKENS);
    }

    function test_CannotVoteBeforeVotingStarts() public {
        uint256 proposalId = _createSendEthProposal(recipient, 1 ether);

        // Don't advance blocks - still in Pending
        vm.prank(alice);
        vm.expectRevert(SimpleGovernor.ProposalNotActive.selector);
        governor.vote(proposalId, 1);
    }

    function test_CannotVoteAfterVotingEnds() public {
        uint256 proposalId = _createSendEthProposal(recipient, 1 ether);

        // Advance past voting period
        _advanceBlocks(VOTING_DELAY + VOTING_PERIOD + 1);

        vm.prank(alice);
        vm.expectRevert(SimpleGovernor.ProposalNotActive.selector);
        governor.vote(proposalId, 1);
    }

    function test_CannotVoteTwice() public {
        uint256 proposalId = _createSendEthProposal(recipient, 1 ether);
        _advanceBlocks(VOTING_DELAY + 1);

        vm.startPrank(alice);
        governor.vote(proposalId, 1);

        vm.expectRevert(SimpleGovernor.AlreadyVoted.selector);
        governor.vote(proposalId, 1);
        vm.stopPrank();
    }

    function test_CannotVoteWithNoVotingPower() public {
        uint256 proposalId = _createSendEthProposal(recipient, 1 ether);
        _advanceBlocks(VOTING_DELAY + 1);

        address nobody = makeAddr("nobody");
        vm.prank(nobody);
        vm.expectRevert(SimpleGovernor.NoVotingPower.selector);
        governor.vote(proposalId, 1);
    }

    function test_CannotVoteWithInvalidType() public {
        uint256 proposalId = _createSendEthProposal(recipient, 1 ether);
        _advanceBlocks(VOTING_DELAY + 1);

        vm.prank(alice);
        vm.expectRevert(SimpleGovernor.InvalidVoteType.selector);
        governor.vote(proposalId, 3);
    }

    function test_VoteCastEmitsEvent() public {
        uint256 proposalId = _createSendEthProposal(recipient, 1 ether);
        _advanceBlocks(VOTING_DELAY + 1);

        vm.expectEmit(true, true, false, true);
        emit SimpleGovernor.VoteCast(alice, proposalId, 1, ALICE_TOKENS);

        vm.prank(alice);
        governor.vote(proposalId, 1);
    }

    // =========================================================================
    // Proposal State Tests
    // =========================================================================

    function test_ProposalSucceeds() public {
        uint256 proposalId = _createSendEthProposal(recipient, 1 ether);
        _advanceBlocks(VOTING_DELAY + 1);

        // Alice votes For (60% of supply, well above 4% quorum)
        vm.prank(alice);
        governor.vote(proposalId, 1);

        // Advance past voting period
        _advanceBlocks(VOTING_PERIOD);

        assertEq(uint256(governor.state(proposalId)), uint256(SimpleGovernor.ProposalState.Succeeded));
    }

    function test_ProposalDefeated_NoQuorum() public {
        uint256 proposalId = _createSendEthProposal(recipient, 1 ether);
        _advanceBlocks(VOTING_DELAY + 1);

        // No one votes -> no quorum
        _advanceBlocks(VOTING_PERIOD);

        assertEq(uint256(governor.state(proposalId)), uint256(SimpleGovernor.ProposalState.Defeated));
    }

    function test_ProposalDefeated_MoreAgainst() public {
        uint256 proposalId = _createSendEthProposal(recipient, 1 ether);
        _advanceBlocks(VOTING_DELAY + 1);

        // Carol votes For (10%), Alice + Bob vote Against (90%)
        vm.prank(carol);
        governor.vote(proposalId, 1);

        vm.prank(alice);
        governor.vote(proposalId, 0);

        vm.prank(bob);
        governor.vote(proposalId, 0);

        _advanceBlocks(VOTING_PERIOD);

        assertEq(uint256(governor.state(proposalId)), uint256(SimpleGovernor.ProposalState.Defeated));
    }

    function test_ProposalDefeated_EqualVotes() public {
        uint256 proposalId = _createSendEthProposal(recipient, 1 ether);
        _advanceBlocks(VOTING_DELAY + 1);

        // Transfer tokens so alice and bob have equal amounts
        vm.prank(alice);
        token.transfer(bob, 150_000e18);
        // Now alice has 450k, bob has 450k

        // Re-delegate after transfer
        vm.prank(alice);
        token.delegate(alice);
        vm.prank(bob);
        token.delegate(bob);

        vm.prank(alice);
        governor.vote(proposalId, 1); // For: 450k

        vm.prank(bob);
        governor.vote(proposalId, 0); // Against: 450k

        _advanceBlocks(VOTING_PERIOD);

        // Equal votes -> defeated (forVotes <= againstVotes)
        assertEq(uint256(governor.state(proposalId)), uint256(SimpleGovernor.ProposalState.Defeated));
    }

    // =========================================================================
    // Execution Tests
    // =========================================================================

    function test_ExecuteAfterTimelockDelay() public {
        uint256 proposalId = _createSendEthProposal(recipient, 1 ether);
        _advanceBlocks(VOTING_DELAY + 1);

        vm.prank(alice);
        governor.vote(proposalId, 1);

        // Advance past voting period + timelock
        _advanceBlocks(VOTING_PERIOD + TIMELOCK_DELAY);

        uint256 recipientBalanceBefore = recipient.balance;

        governor.execute(proposalId);

        assertEq(recipient.balance - recipientBalanceBefore, 1 ether);
        assertEq(uint256(governor.state(proposalId)), uint256(SimpleGovernor.ProposalState.Executed));
    }

    function test_CannotExecuteBeforeTimelock() public {
        uint256 proposalId = _createSendEthProposal(recipient, 1 ether);
        _advanceBlocks(VOTING_DELAY + 1);

        vm.prank(alice);
        governor.vote(proposalId, 1);

        // Advance past voting but NOT past timelock
        _advanceBlocks(VOTING_PERIOD);

        vm.expectRevert(SimpleGovernor.ProposalNotReady.selector);
        governor.execute(proposalId);
    }

    function test_CannotExecuteDefeatedProposal() public {
        uint256 proposalId = _createSendEthProposal(recipient, 1 ether);
        _advanceBlocks(VOTING_DELAY + 1);

        // No votes
        _advanceBlocks(VOTING_PERIOD + TIMELOCK_DELAY);

        vm.expectRevert(SimpleGovernor.ProposalNotSucceeded.selector);
        governor.execute(proposalId);
    }

    function test_CannotExecuteTwice() public {
        uint256 proposalId = _createSendEthProposal(recipient, 1 ether);
        _advanceBlocks(VOTING_DELAY + 1);

        vm.prank(alice);
        governor.vote(proposalId, 1);

        _advanceBlocks(VOTING_PERIOD + TIMELOCK_DELAY);

        governor.execute(proposalId);

        vm.expectRevert(SimpleGovernor.ProposalNotSucceeded.selector);
        governor.execute(proposalId);
    }

    function test_ExecuteEmitsEvent() public {
        uint256 proposalId = _createSendEthProposal(recipient, 1 ether);
        _advanceBlocks(VOTING_DELAY + 1);

        vm.prank(alice);
        governor.vote(proposalId, 1);

        _advanceBlocks(VOTING_PERIOD + TIMELOCK_DELAY);

        vm.expectEmit(true, false, false, false);
        emit SimpleGovernor.ProposalExecuted(proposalId);

        governor.execute(proposalId);
    }

    // =========================================================================
    // End-to-End Test
    // =========================================================================

    function test_EndToEnd_ProposeVoteExecuteSendETH() public {
        uint256 sendAmount = 5 ether;
        uint256 recipientBalanceBefore = recipient.balance;

        // 1. Alice proposes to send ETH from treasury to recipient
        uint256 proposalId = _createSendEthProposal(recipient, sendAmount);
        assertEq(uint256(governor.state(proposalId)), uint256(SimpleGovernor.ProposalState.Pending));

        // 2. Wait for voting delay
        _advanceBlocks(VOTING_DELAY + 1);
        assertEq(uint256(governor.state(proposalId)), uint256(SimpleGovernor.ProposalState.Active));

        // 3. Alice and Bob vote For, Carol abstains
        vm.prank(alice);
        governor.vote(proposalId, 1);

        vm.prank(bob);
        governor.vote(proposalId, 1);

        vm.prank(carol);
        governor.vote(proposalId, 2);

        // 4. Advance past voting period
        _advanceBlocks(VOTING_PERIOD);
        assertEq(uint256(governor.state(proposalId)), uint256(SimpleGovernor.ProposalState.Succeeded));

        // 5. Wait for timelock delay
        _advanceBlocks(TIMELOCK_DELAY);

        // 6. Execute
        governor.execute(proposalId);
        assertEq(uint256(governor.state(proposalId)), uint256(SimpleGovernor.ProposalState.Executed));

        // 7. Verify recipient received ETH
        assertEq(recipient.balance - recipientBalanceBefore, sendAmount);
    }

    // =========================================================================
    // Delegation Tests
    // =========================================================================

    function test_DelegatedVotingPower() public {
        // Carol delegates to Alice
        vm.prank(carol);
        token.delegate(alice);

        // Alice now has her tokens + Carol's tokens as voting power
        assertEq(token.getVotes(alice), ALICE_TOKENS + CAROL_TOKENS);
        assertEq(token.getVotes(carol), 0);

        uint256 proposalId = _createSendEthProposal(recipient, 1 ether);
        _advanceBlocks(VOTING_DELAY + 1);

        // Alice votes with combined power
        vm.prank(alice);
        governor.vote(proposalId, 1);

        (uint256 forVotes,,) = governor.proposalVotes(proposalId);
        assertEq(forVotes, ALICE_TOKENS + CAROL_TOKENS);
    }

    // =========================================================================
    // Quorum Tests
    // =========================================================================

    function test_QuorumCalculation() public {
        uint256 proposalId = _createSendEthProposal(recipient, 1 ether);

        // Total supply = 1,000,000e18, quorum = 4% = 40,000e18
        uint256 expectedQuorum = (1_000_000e18 * QUORUM_BPS) / 10000;
        assertEq(governor.quorum(proposalId), expectedQuorum);
        assertEq(expectedQuorum, 40_000e18);
    }
}
