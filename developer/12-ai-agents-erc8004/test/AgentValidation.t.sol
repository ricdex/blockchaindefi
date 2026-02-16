// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {AgentRegistry} from "../contracts/AgentRegistry.sol";
import {AgentValidation} from "../contracts/AgentValidation.sol";

contract AgentValidationTest is Test {
    AgentRegistry public identityRegistry;
    AgentValidation public validation;

    address public agentOwner = makeAddr("agentOwner");
    address public validator1 = makeAddr("validator1");
    address public validator2 = makeAddr("validator2");
    address public unauthorized = makeAddr("unauthorized");

    uint256 public agentId;
    bytes32 public requestHash1 = keccak256("request-1");
    bytes32 public requestHash2 = keccak256("request-2");
    bytes32 public requestHash3 = keccak256("request-3");

    function setUp() public {
        identityRegistry = new AgentRegistry("ERC8004 Agents", "AGENT");
        validation = new AgentValidation(address(identityRegistry));

        // Register an agent
        vm.prank(agentOwner);
        agentId = identityRegistry.register("https://example.com/agent.json");
    }

    // =========================================================================
    // Configuration Tests
    // =========================================================================

    function test_getIdentityRegistry() public view {
        assertEq(validation.getIdentityRegistry(), address(identityRegistry));
    }

    // =========================================================================
    // Validation Request Tests
    // =========================================================================

    function test_validationRequest_byOwner() public {
        vm.prank(agentOwner);
        validation.validationRequest(validator1, agentId, "https://request.com", requestHash1);

        (address validatorAddr, uint256 aId, uint8 response,,, uint256 lastUpdate) =
            validation.getValidationStatus(requestHash1);

        assertEq(validatorAddr, validator1);
        assertEq(aId, agentId);
        assertEq(response, 0);
        assertTrue(lastUpdate > 0);
    }

    function test_validationRequest_emitsEvent() public {
        vm.prank(agentOwner);
        vm.expectEmit(true, true, false, true);
        emit AgentValidation.ValidationRequested(validator1, agentId, "https://request.com", requestHash1);

        validation.validationRequest(validator1, agentId, "https://request.com", requestHash1);
    }

    function test_validationRequest_notOwner_reverts() public {
        vm.prank(unauthorized);
        vm.expectRevert(AgentValidation.NotOwnerOrApproved.selector);
        validation.validationRequest(validator1, agentId, "", requestHash1);
    }

    function test_validationRequest_duplicateHash_reverts() public {
        vm.startPrank(agentOwner);
        validation.validationRequest(validator1, agentId, "", requestHash1);

        vm.expectRevert(AgentValidation.RequestAlreadyExists.selector);
        validation.validationRequest(validator2, agentId, "", requestHash1);
        vm.stopPrank();
    }

    function test_validationRequest_zeroValidator_reverts() public {
        vm.prank(agentOwner);
        vm.expectRevert(AgentValidation.ZeroAddress.selector);
        validation.validationRequest(address(0), agentId, "", requestHash1);
    }

    function test_validationRequest_nonexistentAgent_reverts() public {
        vm.prank(agentOwner);
        vm.expectRevert(AgentValidation.AgentDoesNotExist.selector);
        validation.validationRequest(validator1, 999, "", requestHash1);
    }

    // =========================================================================
    // Validation Response Tests
    // =========================================================================

    function test_validationResponse_byValidator() public {
        vm.prank(agentOwner);
        validation.validationRequest(validator1, agentId, "", requestHash1);

        vm.prank(validator1);
        validation.validationResponse(requestHash1, 85, "https://response.com", keccak256("report"), "security");

        (,, uint8 response, bytes32 responseHash, string memory tag,) =
            validation.getValidationStatus(requestHash1);

        assertEq(response, 85);
        assertEq(responseHash, keccak256("report"));
        assertEq(tag, "security");
    }

    function test_validationResponse_emitsEvent() public {
        vm.prank(agentOwner);
        validation.validationRequest(validator1, agentId, "", requestHash1);

        vm.prank(validator1);
        vm.expectEmit(true, true, true, true);
        emit AgentValidation.ValidationResponded(
            validator1, agentId, requestHash1, 85, "https://response.com", keccak256("report"), "security"
        );

        validation.validationResponse(requestHash1, 85, "https://response.com", keccak256("report"), "security");
    }

    function test_validationResponse_notAssignedValidator_reverts() public {
        vm.prank(agentOwner);
        validation.validationRequest(validator1, agentId, "", requestHash1);

        vm.prank(validator2);
        vm.expectRevert(AgentValidation.NotAssignedValidator.selector);
        validation.validationResponse(requestHash1, 85, "", bytes32(0), "");
    }

    function test_validationResponse_nonExistentRequest_reverts() public {
        vm.prank(validator1);
        vm.expectRevert(AgentValidation.RequestDoesNotExist.selector);
        validation.validationResponse(requestHash1, 85, "", bytes32(0), "");
    }

    function test_validationResponse_invalidScore_reverts() public {
        vm.prank(agentOwner);
        validation.validationRequest(validator1, agentId, "", requestHash1);

        vm.prank(validator1);
        vm.expectRevert(AgentValidation.InvalidResponse.selector);
        validation.validationResponse(requestHash1, 101, "", bytes32(0), "");
    }

    function test_validationResponse_canUpdateMultipleTimes() public {
        vm.prank(agentOwner);
        validation.validationRequest(validator1, agentId, "", requestHash1);

        vm.startPrank(validator1);
        validation.validationResponse(requestHash1, 50, "", bytes32(0), "initial");
        validation.validationResponse(requestHash1, 90, "", bytes32(0), "final");
        vm.stopPrank();

        (,, uint8 response,,string memory tag,) = validation.getValidationStatus(requestHash1);
        assertEq(response, 90);
        assertEq(tag, "final");
    }

    // =========================================================================
    // Summary Tests
    // =========================================================================

    function test_getSummary_averageScore() public {
        // Create two validation requests with different validators
        vm.startPrank(agentOwner);
        validation.validationRequest(validator1, agentId, "", requestHash1);
        validation.validationRequest(validator2, agentId, "", requestHash2);
        vm.stopPrank();

        vm.prank(validator1);
        validation.validationResponse(requestHash1, 80, "", bytes32(0), "security");

        vm.prank(validator2);
        validation.validationResponse(requestHash2, 60, "", bytes32(0), "security");

        address[] memory validators = new address[](2);
        validators[0] = validator1;
        validators[1] = validator2;

        (uint64 count, uint8 averageResponse) = validation.getSummary(agentId, validators, "security");

        assertEq(count, 2);
        assertEq(averageResponse, 70); // (80 + 60) / 2
    }

    function test_getSummary_filtersByTag() public {
        vm.startPrank(agentOwner);
        validation.validationRequest(validator1, agentId, "", requestHash1);
        validation.validationRequest(validator1, agentId, "", requestHash2);
        vm.stopPrank();

        vm.startPrank(validator1);
        validation.validationResponse(requestHash1, 80, "", bytes32(0), "security");
        validation.validationResponse(requestHash2, 40, "", bytes32(0), "performance");
        vm.stopPrank();

        address[] memory validators = new address[](1);
        validators[0] = validator1;

        (uint64 count, uint8 avg) = validation.getSummary(agentId, validators, "security");
        assertEq(count, 1);
        assertEq(avg, 80);
    }

    function test_getSummary_excludesUnresponded() public {
        vm.startPrank(agentOwner);
        validation.validationRequest(validator1, agentId, "", requestHash1);
        validation.validationRequest(validator2, agentId, "", requestHash2);
        vm.stopPrank();

        // Only validator1 responds
        vm.prank(validator1);
        validation.validationResponse(requestHash1, 90, "", bytes32(0), "");

        address[] memory validators = new address[](2);
        validators[0] = validator1;
        validators[1] = validator2;

        (uint64 count, uint8 avg) = validation.getSummary(agentId, validators, "");
        assertEq(count, 1);
        assertEq(avg, 90);
    }

    // =========================================================================
    // Query Tests
    // =========================================================================

    function test_getAgentValidations() public {
        vm.startPrank(agentOwner);
        validation.validationRequest(validator1, agentId, "", requestHash1);
        validation.validationRequest(validator2, agentId, "", requestHash2);
        vm.stopPrank();

        bytes32[] memory hashes = validation.getAgentValidations(agentId);
        assertEq(hashes.length, 2);
        assertEq(hashes[0], requestHash1);
        assertEq(hashes[1], requestHash2);
    }

    function test_getValidatorRequests() public {
        vm.startPrank(agentOwner);
        validation.validationRequest(validator1, agentId, "", requestHash1);
        validation.validationRequest(validator1, agentId, "", requestHash2);
        vm.stopPrank();

        bytes32[] memory hashes = validation.getValidatorRequests(validator1);
        assertEq(hashes.length, 2);
    }
}
