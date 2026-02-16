// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IReputationRegistry} from "./interfaces/IReputationRegistry.sol";
import {AgentRegistry} from "./AgentRegistry.sol";

/// @title AgentReputation
/// @notice ERC-8004 Reputation Registry implementation
/// @dev Records feedback from clients about agents, with revocation and response support
contract AgentReputation is IReputationRegistry {
    // =========================================================================
    // Types
    // =========================================================================

    struct FeedbackEntry {
        int128 value;
        uint8 valueDecimals;
        string tag1;
        string tag2;
        bool isRevoked;
    }

    struct ResponseEntry {
        address responder;
        string responseURI;
        bytes32 responseHash;
    }

    // =========================================================================
    // State
    // =========================================================================

    AgentRegistry public immutable identityRegistry;

    /// @notice Feedback storage: agentId => clientAddress => feedbackIndex => FeedbackEntry
    mapping(uint256 => mapping(address => mapping(uint64 => FeedbackEntry))) private _feedback;

    /// @notice Feedback count per client per agent: agentId => clientAddress => count
    mapping(uint256 => mapping(address => uint64)) private _feedbackCount;

    /// @notice All clients who gave feedback to an agent: agentId => client[]
    mapping(uint256 => address[]) private _clients;

    /// @notice Track if a client has given feedback (to avoid duplicates in _clients array)
    mapping(uint256 => mapping(address => bool)) private _isClient;

    /// @notice Responses to feedback: agentId => clientAddress => feedbackIndex => ResponseEntry[]
    mapping(uint256 => mapping(address => mapping(uint64 => ResponseEntry[]))) private _responses;

    // =========================================================================
    // Errors
    // =========================================================================

    error AgentDoesNotExist();
    error InvalidValueDecimals();
    error CannotRateOwnAgent();
    error FeedbackDoesNotExist();
    error NotFeedbackAuthor();
    error FeedbackAlreadyRevoked();
    error EmptyClientList();

    // =========================================================================
    // Constructor
    // =========================================================================

    constructor(address _identityRegistry) {
        identityRegistry = AgentRegistry(_identityRegistry);
    }

    // =========================================================================
    // Configuration
    // =========================================================================

    /// @inheritdoc IReputationRegistry
    function getIdentityRegistry() external view returns (address) {
        return address(identityRegistry);
    }

    // =========================================================================
    // Feedback Submission
    // =========================================================================

    /// @inheritdoc IReputationRegistry
    function giveFeedback(
        uint256 agentId,
        int128 value,
        uint8 valueDecimals,
        string calldata tag1,
        string calldata tag2,
        string calldata endpoint,
        string calldata feedbackURI,
        bytes32 feedbackHash
    ) external {
        // Validate agent exists
        if (!identityRegistry.exists(agentId)) revert AgentDoesNotExist();

        // Validate decimals
        if (valueDecimals > 18) revert InvalidValueDecimals();

        // Submitter must not be the agent owner or approved operator
        address agentOwner = identityRegistry.ownerOf(agentId);
        if (msg.sender == agentOwner) revert CannotRateOwnAgent();

        // Track client
        if (!_isClient[agentId][msg.sender]) {
            _clients[agentId].push(msg.sender);
            _isClient[agentId][msg.sender] = true;
        }

        // Store feedback
        uint64 feedbackIndex = _feedbackCount[agentId][msg.sender];
        _feedback[agentId][msg.sender][feedbackIndex] = FeedbackEntry({
            value: value,
            valueDecimals: valueDecimals,
            tag1: tag1,
            tag2: tag2,
            isRevoked: false
        });
        _feedbackCount[agentId][msg.sender] = feedbackIndex + 1;

        emit NewFeedback(
            agentId,
            msg.sender,
            feedbackIndex,
            value,
            valueDecimals,
            tag1,
            tag1,
            tag2,
            endpoint,
            feedbackURI,
            feedbackHash
        );
    }

    // =========================================================================
    // Feedback Management
    // =========================================================================

    /// @inheritdoc IReputationRegistry
    function revokeFeedback(uint256 agentId, uint64 feedbackIndex) external {
        if (feedbackIndex >= _feedbackCount[agentId][msg.sender]) revert FeedbackDoesNotExist();

        FeedbackEntry storage entry = _feedback[agentId][msg.sender][feedbackIndex];
        if (entry.isRevoked) revert FeedbackAlreadyRevoked();

        entry.isRevoked = true;
        emit FeedbackRevoked(agentId, msg.sender, feedbackIndex);
    }

    /// @inheritdoc IReputationRegistry
    function appendResponse(
        uint256 agentId,
        address clientAddress,
        uint64 feedbackIndex,
        string calldata responseURI,
        bytes32 responseHash
    ) external {
        if (feedbackIndex >= _feedbackCount[agentId][clientAddress]) revert FeedbackDoesNotExist();

        _responses[agentId][clientAddress][feedbackIndex].push(
            ResponseEntry({responder: msg.sender, responseURI: responseURI, responseHash: responseHash})
        );

        emit ResponseAppended(agentId, clientAddress, feedbackIndex, msg.sender, responseURI, responseHash);
    }

    // =========================================================================
    // Read Functions
    // =========================================================================

    /// @inheritdoc IReputationRegistry
    function getSummary(
        uint256 agentId,
        address[] calldata clientAddresses,
        string memory tag1,
        string memory tag2
    ) external view returns (uint64 count, int128 summaryValue, uint8 summaryValueDecimals) {
        if (clientAddresses.length == 0) revert EmptyClientList();

        // Use 18 decimals for internal aggregation
        summaryValueDecimals = 18;
        int256 total = 0;

        for (uint256 i = 0; i < clientAddresses.length; i++) {
            address client = clientAddresses[i];
            uint64 feedbackTotal = _feedbackCount[agentId][client];

            for (uint64 j = 0; j < feedbackTotal; j++) {
                FeedbackEntry storage entry = _feedback[agentId][client][j];

                // Skip revoked
                if (entry.isRevoked) continue;

                // Filter by tags if provided
                if (bytes(tag1).length > 0 && keccak256(bytes(entry.tag1)) != keccak256(bytes(tag1))) continue;
                if (bytes(tag2).length > 0 && keccak256(bytes(entry.tag2)) != keccak256(bytes(tag2))) continue;

                // Normalize to 18 decimals and accumulate
                int256 normalized = int256(entry.value) * int256(10 ** (18 - entry.valueDecimals));
                total += normalized;
                count++;
            }
        }

        // Safe cast back to int128 (within range for practical usage)
        summaryValue = int128(total / (count > 0 ? int256(uint256(count)) : int256(1)));
    }

    /// @inheritdoc IReputationRegistry
    function readFeedback(uint256 agentId, address clientAddress, uint64 feedbackIndex)
        external
        view
        returns (int128 value, uint8 valueDecimals, string memory tag1, string memory tag2, bool isRevoked)
    {
        if (feedbackIndex >= _feedbackCount[agentId][clientAddress]) revert FeedbackDoesNotExist();
        FeedbackEntry storage entry = _feedback[agentId][clientAddress][feedbackIndex];
        return (entry.value, entry.valueDecimals, entry.tag1, entry.tag2, entry.isRevoked);
    }

    /// @inheritdoc IReputationRegistry
    function getClients(uint256 agentId) external view returns (address[] memory) {
        return _clients[agentId];
    }

    /// @inheritdoc IReputationRegistry
    function getLastIndex(uint256 agentId, address clientAddress) external view returns (uint64) {
        return _feedbackCount[agentId][clientAddress];
    }

    /// @notice Get the number of responses to a feedback entry
    function getResponseCount(
        uint256 agentId,
        address clientAddress,
        uint64 feedbackIndex
    ) external view returns (uint64) {
        return uint64(_responses[agentId][clientAddress][feedbackIndex].length);
    }
}
