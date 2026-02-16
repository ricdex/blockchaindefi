// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IReputationRegistry
/// @notice ERC-8004 Reputation Registry interface
/// @dev Records and aggregates feedback signals from clients about agents
interface IReputationRegistry {
    // =========================================================================
    // Events
    // =========================================================================

    event NewFeedback(
        uint256 indexed agentId,
        address indexed clientAddress,
        uint64 feedbackIndex,
        int128 value,
        uint8 valueDecimals,
        string indexed indexedTag1,
        string tag1,
        string tag2,
        string endpoint,
        string feedbackURI,
        bytes32 feedbackHash
    );

    event FeedbackRevoked(
        uint256 indexed agentId,
        address indexed clientAddress,
        uint64 indexed feedbackIndex
    );

    event ResponseAppended(
        uint256 indexed agentId,
        address indexed clientAddress,
        uint64 feedbackIndex,
        address indexed responder,
        string responseURI,
        bytes32 responseHash
    );

    // =========================================================================
    // Configuration
    // =========================================================================

    /// @notice Get the linked Identity Registry address
    /// @return The Identity Registry contract address
    function getIdentityRegistry() external view returns (address);

    // =========================================================================
    // Feedback Submission
    // =========================================================================

    /// @notice Submit feedback for an agent
    /// @param agentId The agent to rate
    /// @param value The feedback value (positive or negative)
    /// @param valueDecimals Decimals for the value (0-18)
    /// @param tag1 Primary category tag (optional, can be empty)
    /// @param tag2 Secondary category tag (optional, can be empty)
    /// @param endpoint The service endpoint being rated (optional)
    /// @param feedbackURI Off-chain URI with detailed feedback (optional)
    /// @param feedbackHash Hash of off-chain feedback content (optional)
    function giveFeedback(
        uint256 agentId,
        int128 value,
        uint8 valueDecimals,
        string calldata tag1,
        string calldata tag2,
        string calldata endpoint,
        string calldata feedbackURI,
        bytes32 feedbackHash
    ) external;

    // =========================================================================
    // Feedback Management
    // =========================================================================

    /// @notice Revoke a previously submitted feedback
    /// @param agentId The agent ID
    /// @param feedbackIndex The index of the feedback to revoke
    function revokeFeedback(uint256 agentId, uint64 feedbackIndex) external;

    /// @notice Append a response to a feedback entry
    /// @param agentId The agent ID
    /// @param clientAddress The original feedback submitter
    /// @param feedbackIndex The feedback index being responded to
    /// @param responseURI Off-chain URI with response content
    /// @param responseHash Hash of the response content
    function appendResponse(
        uint256 agentId,
        address clientAddress,
        uint64 feedbackIndex,
        string calldata responseURI,
        bytes32 responseHash
    ) external;

    // =========================================================================
    // Read Functions
    // =========================================================================

    /// @notice Get an aggregated summary of feedback for an agent
    /// @dev clientAddresses MUST be non-empty to mitigate Sybil attacks
    /// @param agentId The agent ID
    /// @param clientAddresses List of client addresses to include in summary
    /// @param tag1 Filter by primary tag (empty = no filter)
    /// @param tag2 Filter by secondary tag (empty = no filter)
    /// @return count Number of matching feedback entries
    /// @return summaryValue Aggregated value
    /// @return summaryValueDecimals Decimals of the summary value
    function getSummary(
        uint256 agentId,
        address[] calldata clientAddresses,
        string memory tag1,
        string memory tag2
    ) external view returns (uint64 count, int128 summaryValue, uint8 summaryValueDecimals);

    /// @notice Read a specific feedback entry
    /// @param agentId The agent ID
    /// @param clientAddress The feedback submitter
    /// @param feedbackIndex The feedback index
    /// @return value The feedback value
    /// @return valueDecimals The value decimals
    /// @return tag1 Primary tag
    /// @return tag2 Secondary tag
    /// @return isRevoked Whether the feedback was revoked
    function readFeedback(uint256 agentId, address clientAddress, uint64 feedbackIndex)
        external
        view
        returns (int128 value, uint8 valueDecimals, string memory tag1, string memory tag2, bool isRevoked);

    /// @notice Get all clients who have given feedback to an agent
    /// @param agentId The agent ID
    /// @return Array of client addresses
    function getClients(uint256 agentId) external view returns (address[] memory);

    /// @notice Get the last feedback index for a client-agent pair
    /// @param agentId The agent ID
    /// @param clientAddress The client address
    /// @return The last feedback index
    function getLastIndex(uint256 agentId, address clientAddress) external view returns (uint64);
}
