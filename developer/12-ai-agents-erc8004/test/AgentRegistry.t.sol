// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {AgentRegistry} from "../contracts/AgentRegistry.sol";
import {IIdentityRegistry} from "../contracts/interfaces/IIdentityRegistry.sol";

contract AgentRegistryTest is Test {
    AgentRegistry public registry;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public operator = makeAddr("operator");

    uint256 public walletPrivateKey = 0xBEEF;
    address public walletAddress;

    string constant AGENT_URI = "https://example.com/agent.json";
    string constant UPDATED_URI = "https://example.com/agent-v2.json";

    function setUp() public {
        registry = new AgentRegistry("ERC8004 Agents", "AGENT");
        walletAddress = vm.addr(walletPrivateKey);
    }

    // =========================================================================
    // Registration Tests
    // =========================================================================

    function test_register_withURIAndMetadata() public {
        IIdentityRegistry.MetadataEntry[] memory metadata = new IIdentityRegistry.MetadataEntry[](2);
        metadata[0] = IIdentityRegistry.MetadataEntry("version", abi.encodePacked("1.0"));
        metadata[1] = IIdentityRegistry.MetadataEntry("protocol", abi.encodePacked("A2A"));

        vm.prank(alice);
        uint256 agentId = registry.register(AGENT_URI, metadata);

        assertEq(agentId, 0);
        assertEq(registry.ownerOf(agentId), alice);
        assertEq(registry.tokenURI(agentId), AGENT_URI);
        assertEq(registry.getMetadata(agentId, "version"), abi.encodePacked("1.0"));
        assertEq(registry.getMetadata(agentId, "protocol"), abi.encodePacked("A2A"));
    }

    function test_register_withURIOnly() public {
        vm.prank(alice);
        uint256 agentId = registry.register(AGENT_URI);

        assertEq(agentId, 0);
        assertEq(registry.ownerOf(agentId), alice);
        assertEq(registry.tokenURI(agentId), AGENT_URI);
    }

    function test_register_withNoArgs() public {
        vm.prank(alice);
        uint256 agentId = registry.register();

        assertEq(agentId, 0);
        assertEq(registry.ownerOf(agentId), alice);
    }

    function test_register_emitsRegisteredEvent() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit IIdentityRegistry.Registered(0, AGENT_URI, alice);

        registry.register(AGENT_URI);
    }

    function test_register_autoIncrementsTokenId() public {
        vm.prank(alice);
        uint256 id1 = registry.register(AGENT_URI);

        vm.prank(bob);
        uint256 id2 = registry.register(AGENT_URI);

        assertEq(id1, 0);
        assertEq(id2, 1);
        assertEq(registry.nextTokenId(), 2);
    }

    function test_register_multipleAgentsSameOwner() public {
        vm.startPrank(alice);
        registry.register("https://agent1.com");
        registry.register("https://agent2.com");
        registry.register("https://agent3.com");
        vm.stopPrank();

        assertEq(registry.balanceOf(alice), 3);
    }

    function test_register_reservedMetadataKey_reverts() public {
        IIdentityRegistry.MetadataEntry[] memory metadata = new IIdentityRegistry.MetadataEntry[](1);
        metadata[0] = IIdentityRegistry.MetadataEntry("agentWallet", abi.encodePacked(alice));

        vm.prank(alice);
        vm.expectRevert(AgentRegistry.ReservedMetadataKey.selector);
        registry.register(AGENT_URI, metadata);
    }

    // =========================================================================
    // URI Management Tests
    // =========================================================================

    function test_setAgentURI_byOwner() public {
        vm.prank(alice);
        uint256 agentId = registry.register(AGENT_URI);

        vm.prank(alice);
        registry.setAgentURI(agentId, UPDATED_URI);

        assertEq(registry.tokenURI(agentId), UPDATED_URI);
    }

    function test_setAgentURI_emitsURIUpdatedEvent() public {
        vm.prank(alice);
        uint256 agentId = registry.register(AGENT_URI);

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit IIdentityRegistry.URIUpdated(agentId, UPDATED_URI, alice);

        registry.setAgentURI(agentId, UPDATED_URI);
    }

    function test_setAgentURI_notOwner_reverts() public {
        vm.prank(alice);
        uint256 agentId = registry.register(AGENT_URI);

        vm.prank(bob);
        vm.expectRevert(AgentRegistry.NotOwnerOrApproved.selector);
        registry.setAgentURI(agentId, UPDATED_URI);
    }

    // =========================================================================
    // Metadata Tests
    // =========================================================================

    function test_setMetadata_byOwner() public {
        vm.prank(alice);
        uint256 agentId = registry.register(AGENT_URI);

        vm.prank(alice);
        registry.setMetadata(agentId, "category", abi.encodePacked("trading"));

        assertEq(registry.getMetadata(agentId, "category"), abi.encodePacked("trading"));
    }

    function test_setMetadata_reservedKey_reverts() public {
        vm.prank(alice);
        uint256 agentId = registry.register(AGENT_URI);

        vm.prank(alice);
        vm.expectRevert(AgentRegistry.ReservedMetadataKey.selector);
        registry.setMetadata(agentId, "agentWallet", abi.encodePacked(bob));
    }

    function test_setMetadata_notOwner_reverts() public {
        vm.prank(alice);
        uint256 agentId = registry.register(AGENT_URI);

        vm.prank(bob);
        vm.expectRevert(AgentRegistry.NotOwnerOrApproved.selector);
        registry.setMetadata(agentId, "key", abi.encodePacked("val"));
    }

    function test_getMetadata_nonexistentToken_reverts() public {
        vm.expectRevert(AgentRegistry.TokenDoesNotExist.selector);
        registry.getMetadata(999, "key");
    }

    // =========================================================================
    // Agent Wallet Tests
    // =========================================================================

    function test_setAgentWallet_withValidSignature() public {
        vm.prank(alice);
        uint256 agentId = registry.register(AGENT_URI);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = _signSetAgentWallet(agentId, walletAddress, deadline, walletPrivateKey);

        vm.prank(alice);
        registry.setAgentWallet(agentId, walletAddress, deadline, signature);

        assertEq(registry.getAgentWallet(agentId), walletAddress);
    }

    function test_setAgentWallet_expiredSignature_reverts() public {
        vm.prank(alice);
        uint256 agentId = registry.register(AGENT_URI);

        uint256 deadline = block.timestamp - 1; // expired
        bytes memory signature = _signSetAgentWallet(agentId, walletAddress, deadline, walletPrivateKey);

        vm.prank(alice);
        vm.expectRevert(AgentRegistry.SignatureExpired.selector);
        registry.setAgentWallet(agentId, walletAddress, deadline, signature);
    }

    function test_setAgentWallet_wrongSigner_reverts() public {
        vm.prank(alice);
        uint256 agentId = registry.register(AGENT_URI);

        uint256 deadline = block.timestamp + 1 hours;
        // Sign with a different key
        uint256 wrongKey = 0xDEAD;
        bytes memory signature = _signSetAgentWallet(agentId, walletAddress, deadline, wrongKey);

        vm.prank(alice);
        vm.expectRevert(AgentRegistry.InvalidSignature.selector);
        registry.setAgentWallet(agentId, walletAddress, deadline, signature);
    }

    function test_unsetAgentWallet() public {
        vm.prank(alice);
        uint256 agentId = registry.register(AGENT_URI);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = _signSetAgentWallet(agentId, walletAddress, deadline, walletPrivateKey);

        vm.prank(alice);
        registry.setAgentWallet(agentId, walletAddress, deadline, signature);
        assertEq(registry.getAgentWallet(agentId), walletAddress);

        vm.prank(alice);
        registry.unsetAgentWallet(agentId);
        assertEq(registry.getAgentWallet(agentId), address(0));
    }

    // =========================================================================
    // Transfer Tests (ERC-721 + wallet clearing)
    // =========================================================================

    function test_transfer_clearsAgentWallet() public {
        vm.prank(alice);
        uint256 agentId = registry.register(AGENT_URI);

        // Set wallet
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = _signSetAgentWallet(agentId, walletAddress, deadline, walletPrivateKey);
        vm.prank(alice);
        registry.setAgentWallet(agentId, walletAddress, deadline, signature);

        // Transfer
        vm.prank(alice);
        registry.transferFrom(alice, bob, agentId);

        // Wallet should be cleared
        assertEq(registry.ownerOf(agentId), bob);
        assertEq(registry.getAgentWallet(agentId), address(0));
    }

    function test_transfer_notOwner_reverts() public {
        vm.prank(alice);
        uint256 agentId = registry.register(AGENT_URI);

        vm.prank(bob);
        vm.expectRevert(AgentRegistry.NotOwnerOrApproved.selector);
        registry.transferFrom(alice, bob, agentId);
    }

    // =========================================================================
    // Approval Tests
    // =========================================================================

    function test_approve_allowsOperatorActions() public {
        vm.prank(alice);
        uint256 agentId = registry.register(AGENT_URI);

        vm.prank(alice);
        registry.approve(operator, agentId);

        // Operator can update URI
        vm.prank(operator);
        registry.setAgentURI(agentId, UPDATED_URI);
        assertEq(registry.tokenURI(agentId), UPDATED_URI);
    }

    function test_setApprovalForAll_allowsOperatorActions() public {
        vm.prank(alice);
        uint256 agentId = registry.register(AGENT_URI);

        vm.prank(alice);
        registry.setApprovalForAll(operator, true);

        // Operator can set metadata
        vm.prank(operator);
        registry.setMetadata(agentId, "key", abi.encodePacked("val"));
        assertEq(registry.getMetadata(agentId, "key"), abi.encodePacked("val"));
    }

    // =========================================================================
    // ERC-165 Tests
    // =========================================================================

    function test_supportsInterface_ERC721() public view {
        assertTrue(registry.supportsInterface(0x80ac58cd)); // ERC-721
    }

    function test_supportsInterface_ERC165() public view {
        assertTrue(registry.supportsInterface(0x01ffc9a7)); // ERC-165
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    function _signSetAgentWallet(
        uint256 agentId,
        address newWallet,
        uint256 deadline,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        bytes32 structHash = keccak256(
            abi.encode(registry.SET_AGENT_WALLET_TYPEHASH(), agentId, newWallet, deadline)
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", registry.DOMAIN_SEPARATOR(), structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }
}
