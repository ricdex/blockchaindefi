// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {AgentRegistry} from "../contracts/AgentRegistry.sol";
import {AgentReputation} from "../contracts/AgentReputation.sol";

contract AgentReputationTest is Test {
    AgentRegistry public identityRegistry;
    AgentReputation public reputation;

    address public agentOwner = makeAddr("agentOwner");
    address public client1 = makeAddr("client1");
    address public client2 = makeAddr("client2");
    address public client3 = makeAddr("client3");

    uint256 public agentId;

    function setUp() public {
        identityRegistry = new AgentRegistry("ERC8004 Agents", "AGENT");
        reputation = new AgentReputation(address(identityRegistry));

        // Register an agent
        vm.prank(agentOwner);
        agentId = identityRegistry.register("https://example.com/agent.json");
    }

    // =========================================================================
    // Configuration Tests
    // =========================================================================

    function test_getIdentityRegistry() public view {
        assertEq(reputation.getIdentityRegistry(), address(identityRegistry));
    }

    // =========================================================================
    // Feedback Submission Tests
    // =========================================================================

    function test_giveFeedback_basic() public {
        vm.prank(client1);
        reputation.giveFeedback(agentId, 5, 0, "quality", "speed", "", "", bytes32(0));

        (int128 value, uint8 decimals, string memory tag1, string memory tag2, bool isRevoked) =
            reputation.readFeedback(agentId, client1, 0);

        assertEq(value, 5);
        assertEq(decimals, 0);
        assertEq(tag1, "quality");
        assertEq(tag2, "speed");
        assertFalse(isRevoked);
    }

    function test_giveFeedback_emitsEvent() public {
        vm.prank(client1);
        vm.expectEmit(true, true, false, true);
        emit AgentReputation.NewFeedback(
            agentId, client1, 0, 5, 0, "quality", "quality", "speed", "https://endpoint", "ipfs://review", bytes32(0)
        );

        reputation.giveFeedback(
            agentId, 5, 0, "quality", "speed", "https://endpoint", "ipfs://review", bytes32(0)
        );
    }

    function test_giveFeedback_withDecimals() public {
        vm.prank(client1);
        reputation.giveFeedback(agentId, 4500, 2, "", "", "", "", bytes32(0));

        (int128 value, uint8 decimals,,, ) = reputation.readFeedback(agentId, client1, 0);
        assertEq(value, 4500); // 45.00
        assertEq(decimals, 2);
    }

    function test_giveFeedback_negativeFeedback() public {
        vm.prank(client1);
        reputation.giveFeedback(agentId, -3, 0, "reliability", "", "", "", bytes32(0));

        (int128 value,,,, ) = reputation.readFeedback(agentId, client1, 0);
        assertEq(value, -3);
    }

    function test_giveFeedback_multipleFromSameClient() public {
        vm.startPrank(client1);
        reputation.giveFeedback(agentId, 5, 0, "", "", "", "", bytes32(0));
        reputation.giveFeedback(agentId, 3, 0, "", "", "", "", bytes32(0));
        reputation.giveFeedback(agentId, 4, 0, "", "", "", "", bytes32(0));
        vm.stopPrank();

        assertEq(reputation.getLastIndex(agentId, client1), 3);
    }

    function test_giveFeedback_multipleClients() public {
        vm.prank(client1);
        reputation.giveFeedback(agentId, 5, 0, "", "", "", "", bytes32(0));

        vm.prank(client2);
        reputation.giveFeedback(agentId, 4, 0, "", "", "", "", bytes32(0));

        vm.prank(client3);
        reputation.giveFeedback(agentId, 3, 0, "", "", "", "", bytes32(0));

        address[] memory clients = reputation.getClients(agentId);
        assertEq(clients.length, 3);
    }

    function test_giveFeedback_agentDoesNotExist_reverts() public {
        vm.prank(client1);
        vm.expectRevert(AgentReputation.AgentDoesNotExist.selector);
        reputation.giveFeedback(999, 5, 0, "", "", "", "", bytes32(0));
    }

    function test_giveFeedback_invalidDecimals_reverts() public {
        vm.prank(client1);
        vm.expectRevert(AgentReputation.InvalidValueDecimals.selector);
        reputation.giveFeedback(agentId, 5, 19, "", "", "", "", bytes32(0));
    }

    function test_giveFeedback_ownerCannotRateOwnAgent_reverts() public {
        vm.prank(agentOwner);
        vm.expectRevert(AgentReputation.CannotRateOwnAgent.selector);
        reputation.giveFeedback(agentId, 5, 0, "", "", "", "", bytes32(0));
    }

    // =========================================================================
    // Feedback Revocation Tests
    // =========================================================================

    function test_revokeFeedback_byAuthor() public {
        vm.prank(client1);
        reputation.giveFeedback(agentId, 5, 0, "", "", "", "", bytes32(0));

        vm.prank(client1);
        reputation.revokeFeedback(agentId, 0);

        (,,,, bool isRevoked) = reputation.readFeedback(agentId, client1, 0);
        assertTrue(isRevoked);
    }

    function test_revokeFeedback_emitsEvent() public {
        vm.prank(client1);
        reputation.giveFeedback(agentId, 5, 0, "", "", "", "", bytes32(0));

        vm.prank(client1);
        vm.expectEmit(true, true, true, false);
        emit AgentReputation.FeedbackRevoked(agentId, client1, 0);

        reputation.revokeFeedback(agentId, 0);
    }

    function test_revokeFeedback_nonExistent_reverts() public {
        vm.prank(client1);
        vm.expectRevert(AgentReputation.FeedbackDoesNotExist.selector);
        reputation.revokeFeedback(agentId, 0);
    }

    function test_revokeFeedback_alreadyRevoked_reverts() public {
        vm.prank(client1);
        reputation.giveFeedback(agentId, 5, 0, "", "", "", "", bytes32(0));

        vm.startPrank(client1);
        reputation.revokeFeedback(agentId, 0);

        vm.expectRevert(AgentReputation.FeedbackAlreadyRevoked.selector);
        reputation.revokeFeedback(agentId, 0);
        vm.stopPrank();
    }

    // =========================================================================
    // Response Tests
    // =========================================================================

    function test_appendResponse() public {
        vm.prank(client1);
        reputation.giveFeedback(agentId, 2, 0, "", "", "", "", bytes32(0));

        // Agent owner responds
        vm.prank(agentOwner);
        reputation.appendResponse(agentId, client1, 0, "ipfs://response", keccak256("response"));

        assertEq(reputation.getResponseCount(agentId, client1, 0), 1);
    }

    function test_appendResponse_emitsEvent() public {
        vm.prank(client1);
        reputation.giveFeedback(agentId, 2, 0, "", "", "", "", bytes32(0));

        vm.prank(agentOwner);
        vm.expectEmit(true, true, false, true);
        emit AgentReputation.ResponseAppended(
            agentId, client1, 0, agentOwner, "ipfs://response", keccak256("response")
        );

        reputation.appendResponse(agentId, client1, 0, "ipfs://response", keccak256("response"));
    }

    function test_appendResponse_nonExistentFeedback_reverts() public {
        vm.prank(agentOwner);
        vm.expectRevert(AgentReputation.FeedbackDoesNotExist.selector);
        reputation.appendResponse(agentId, client1, 0, "ipfs://response", bytes32(0));
    }

    // =========================================================================
    // Summary Tests
    // =========================================================================

    function test_getSummary_basicAverage() public {
        vm.prank(client1);
        reputation.giveFeedback(agentId, 4, 0, "", "", "", "", bytes32(0));

        vm.prank(client2);
        reputation.giveFeedback(agentId, 6, 0, "", "", "", "", bytes32(0));

        address[] memory clients = new address[](2);
        clients[0] = client1;
        clients[1] = client2;

        (uint64 count, int128 summaryValue, ) = reputation.getSummary(agentId, clients, "", "");

        assertEq(count, 2);
        // Average of 4 and 6 = 5, normalized to 18 decimals
        assertEq(summaryValue, 5 * 1e18);
    }

    function test_getSummary_excludesRevokedFeedback() public {
        vm.prank(client1);
        reputation.giveFeedback(agentId, 1, 0, "", "", "", "", bytes32(0));

        vm.prank(client2);
        reputation.giveFeedback(agentId, 5, 0, "", "", "", "", bytes32(0));

        // Revoke client1's feedback
        vm.prank(client1);
        reputation.revokeFeedback(agentId, 0);

        address[] memory clients = new address[](2);
        clients[0] = client1;
        clients[1] = client2;

        (uint64 count, int128 summaryValue, ) = reputation.getSummary(agentId, clients, "", "");

        assertEq(count, 1);
        assertEq(summaryValue, 5 * 1e18);
    }

    function test_getSummary_filtersByTag() public {
        vm.prank(client1);
        reputation.giveFeedback(agentId, 5, 0, "quality", "", "", "", bytes32(0));

        vm.prank(client2);
        reputation.giveFeedback(agentId, 2, 0, "speed", "", "", "", bytes32(0));

        address[] memory clients = new address[](2);
        clients[0] = client1;
        clients[1] = client2;

        (uint64 count, int128 summaryValue, ) = reputation.getSummary(agentId, clients, "quality", "");

        assertEq(count, 1);
        assertEq(summaryValue, 5 * 1e18);
    }

    function test_getSummary_emptyClientList_reverts() public {
        address[] memory clients = new address[](0);

        vm.expectRevert(AgentReputation.EmptyClientList.selector);
        reputation.getSummary(agentId, clients, "", "");
    }

    // =========================================================================
    // Client Tracking Tests
    // =========================================================================

    function test_getClients_returnsUniqueClients() public {
        // Client1 gives feedback twice
        vm.startPrank(client1);
        reputation.giveFeedback(agentId, 5, 0, "", "", "", "", bytes32(0));
        reputation.giveFeedback(agentId, 4, 0, "", "", "", "", bytes32(0));
        vm.stopPrank();

        address[] memory clients = reputation.getClients(agentId);
        assertEq(clients.length, 1); // Only 1 unique client
    }

    function test_getLastIndex() public {
        vm.startPrank(client1);
        reputation.giveFeedback(agentId, 5, 0, "", "", "", "", bytes32(0));
        reputation.giveFeedback(agentId, 4, 0, "", "", "", "", bytes32(0));
        vm.stopPrank();

        assertEq(reputation.getLastIndex(agentId, client1), 2);
        assertEq(reputation.getLastIndex(agentId, client2), 0);
    }
}
