// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IIdentityRegistry
/// @notice ERC-8004 Identity Registry interface
/// @dev Manages agent registration as ERC-721 NFTs with extensible metadata
interface IIdentityRegistry {
    // =========================================================================
    // Structs
    // =========================================================================

    struct MetadataEntry {
        string metadataKey;
        bytes metadataValue;
    }

    // =========================================================================
    // Events
    // =========================================================================

    event Registered(uint256 indexed agentId, string agentURI, address indexed owner);
    event URIUpdated(uint256 indexed agentId, string newURI, address indexed updatedBy);
    event MetadataSet(
        uint256 indexed agentId,
        string indexed indexedMetadataKey,
        string metadataKey,
        bytes metadataValue
    );

    // =========================================================================
    // Registration
    // =========================================================================

    /// @notice Register a new agent with URI and metadata
    /// @param agentURI URI pointing to the agent registration file (JSON)
    /// @param metadata Array of key-value metadata entries
    /// @return agentId The minted token ID representing the agent
    function register(string memory agentURI, MetadataEntry[] calldata metadata)
        external
        returns (uint256 agentId);

    /// @notice Register a new agent with URI only
    /// @param agentURI URI pointing to the agent registration file
    /// @return agentId The minted token ID
    function register(string memory agentURI) external returns (uint256 agentId);

    /// @notice Register a new agent with no URI or metadata
    /// @return agentId The minted token ID
    function register() external returns (uint256 agentId);

    // =========================================================================
    // URI Management
    // =========================================================================

    /// @notice Update the URI of an agent
    /// @param agentId The agent token ID
    /// @param newURI The new URI
    function setAgentURI(uint256 agentId, string calldata newURI) external;

    // =========================================================================
    // Metadata
    // =========================================================================

    /// @notice Get a metadata value for an agent
    /// @param agentId The agent token ID
    /// @param metadataKey The key to look up
    /// @return The metadata value as bytes
    function getMetadata(uint256 agentId, string memory metadataKey)
        external
        view
        returns (bytes memory);

    /// @notice Set a metadata value for an agent
    /// @param agentId The agent token ID
    /// @param metadataKey The key to set
    /// @param metadataValue The value to store
    function setMetadata(uint256 agentId, string memory metadataKey, bytes memory metadataValue)
        external;

    // =========================================================================
    // Agent Wallet (reserved metadata key with EIP-712 signature)
    // =========================================================================

    /// @notice Set the agent's operational wallet with signature verification
    /// @param agentId The agent token ID
    /// @param newWallet The wallet address to associate
    /// @param deadline Signature expiry timestamp
    /// @param signature EIP-712 or ERC-1271 signature from newWallet
    function setAgentWallet(
        uint256 agentId,
        address newWallet,
        uint256 deadline,
        bytes calldata signature
    ) external;

    /// @notice Get the agent's operational wallet
    /// @param agentId The agent token ID
    /// @return The wallet address (address(0) if unset)
    function getAgentWallet(uint256 agentId) external view returns (address);

    /// @notice Remove the agent's wallet association
    /// @param agentId The agent token ID
    function unsetAgentWallet(uint256 agentId) external;
}
