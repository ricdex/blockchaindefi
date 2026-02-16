// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IValidationRegistry} from "./interfaces/IValidationRegistry.sol";
import {AgentRegistry} from "./AgentRegistry.sol";

/// @title AgentValidation
/// @notice ERC-8004 Validation Registry implementation
/// @dev Tracks validation requests and responses from independent validators
contract AgentValidation is IValidationRegistry {
    // =========================================================================
    // Types
    // =========================================================================

    struct ValidationEntry {
        address validatorAddress;
        uint256 agentId;
        address requester;
        uint8 response;
        bytes32 responseHash;
        string tag;
        uint256 lastUpdate;
        bool exists;
        bool responded;
    }

    // =========================================================================
    // State
    // =========================================================================

    AgentRegistry public immutable identityRegistry;

    /// @notice Validation entries by request hash
    mapping(bytes32 => ValidationEntry) private _validations;

    /// @notice All request hashes for an agent
    mapping(uint256 => bytes32[]) private _agentValidations;

    /// @notice All request hashes for a validator
    mapping(address => bytes32[]) private _validatorRequests;

    // =========================================================================
    // Errors
    // =========================================================================

    error AgentDoesNotExist();
    error NotOwnerOrApproved();
    error RequestAlreadyExists();
    error RequestDoesNotExist();
    error NotAssignedValidator();
    error InvalidResponse();
    error ZeroAddress();

    // =========================================================================
    // Constructor
    // =========================================================================

    constructor(address _identityRegistry) {
        identityRegistry = AgentRegistry(_identityRegistry);
    }

    // =========================================================================
    // Configuration
    // =========================================================================

    /// @inheritdoc IValidationRegistry
    function getIdentityRegistry() external view returns (address) {
        return address(identityRegistry);
    }

    // =========================================================================
    // Validation Request
    // =========================================================================

    /// @inheritdoc IValidationRegistry
    function validationRequest(
        address validatorAddress,
        uint256 agentId,
        string memory requestURI,
        bytes32 requestHash
    ) external {
        // Must be called by agent owner or approved operator
        if (!_isOwnerOrApproved(msg.sender, agentId)) revert NotOwnerOrApproved();
        if (validatorAddress == address(0)) revert ZeroAddress();
        if (!identityRegistry.exists(agentId)) revert AgentDoesNotExist();
        if (_validations[requestHash].exists) revert RequestAlreadyExists();

        _validations[requestHash] = ValidationEntry({
            validatorAddress: validatorAddress,
            agentId: agentId,
            requester: msg.sender,
            response: 0,
            responseHash: bytes32(0),
            tag: "",
            lastUpdate: block.timestamp,
            exists: true,
            responded: false
        });

        _agentValidations[agentId].push(requestHash);
        _validatorRequests[validatorAddress].push(requestHash);

        emit ValidationRequested(validatorAddress, agentId, requestURI, requestHash);
    }

    // =========================================================================
    // Validation Response
    // =========================================================================

    /// @inheritdoc IValidationRegistry
    function validationResponse(
        bytes32 requestHash,
        uint8 response,
        string memory responseURI,
        bytes32 responseHash,
        string memory tag
    ) external {
        ValidationEntry storage entry = _validations[requestHash];
        if (!entry.exists) revert RequestDoesNotExist();
        if (msg.sender != entry.validatorAddress) revert NotAssignedValidator();
        if (response > 100) revert InvalidResponse();

        entry.response = response;
        entry.responseHash = responseHash;
        entry.tag = tag;
        entry.lastUpdate = block.timestamp;
        entry.responded = true;

        emit ValidationResponded(
            msg.sender,
            entry.agentId,
            requestHash,
            response,
            responseURI,
            responseHash,
            tag
        );
    }

    // =========================================================================
    // Read Functions
    // =========================================================================

    /// @inheritdoc IValidationRegistry
    function getValidationStatus(bytes32 requestHash)
        external
        view
        returns (
            address validatorAddress,
            uint256 agentId,
            uint8 response,
            bytes32 responseHash,
            string memory tag,
            uint256 lastUpdate
        )
    {
        ValidationEntry storage entry = _validations[requestHash];
        if (!entry.exists) revert RequestDoesNotExist();
        return (
            entry.validatorAddress,
            entry.agentId,
            entry.response,
            entry.responseHash,
            entry.tag,
            entry.lastUpdate
        );
    }

    /// @inheritdoc IValidationRegistry
    function getSummary(uint256 agentId, address[] calldata validatorAddresses, string memory tag)
        external
        view
        returns (uint64 count, uint8 averageResponse)
    {
        bytes32[] storage hashes = _agentValidations[agentId];
        uint256 totalResponse = 0;

        for (uint256 i = 0; i < hashes.length; i++) {
            ValidationEntry storage entry = _validations[hashes[i]];

            // Must have responded
            if (!entry.responded) continue;

            // Filter by validator list
            bool validatorMatch = false;
            for (uint256 j = 0; j < validatorAddresses.length; j++) {
                if (entry.validatorAddress == validatorAddresses[j]) {
                    validatorMatch = true;
                    break;
                }
            }
            if (!validatorMatch) continue;

            // Filter by tag if provided
            if (bytes(tag).length > 0 && keccak256(bytes(entry.tag)) != keccak256(bytes(tag))) continue;

            totalResponse += entry.response;
            count++;
        }

        if (count > 0) {
            averageResponse = uint8(totalResponse / count);
        }
    }

    /// @inheritdoc IValidationRegistry
    function getAgentValidations(uint256 agentId)
        external
        view
        returns (bytes32[] memory requestHashes)
    {
        return _agentValidations[agentId];
    }

    /// @inheritdoc IValidationRegistry
    function getValidatorRequests(address validatorAddress)
        external
        view
        returns (bytes32[] memory requestHashes)
    {
        return _validatorRequests[validatorAddress];
    }

    // =========================================================================
    // Internal
    // =========================================================================

    function _isOwnerOrApproved(address spender, uint256 agentId) internal view returns (bool) {
        address owner = identityRegistry.ownerOf(agentId);
        return (
            spender == owner
                || identityRegistry.getApproved(agentId) == spender
                || identityRegistry.isApprovedForAll(owner, spender)
        );
    }
}
