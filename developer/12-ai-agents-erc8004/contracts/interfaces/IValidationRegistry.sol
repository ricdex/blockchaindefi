// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IValidationRegistry
/// @notice ERC-8004 Validation Registry interface
/// @dev Tracks validation requests and responses from independent validators
interface IValidationRegistry {
    // =========================================================================
    // Events
    // =========================================================================

    event ValidationRequested(
        address indexed validatorAddress,
        uint256 indexed agentId,
        string requestURI,
        bytes32 indexed requestHash
    );

    event ValidationResponded(
        address indexed validatorAddress,
        uint256 indexed agentId,
        bytes32 indexed requestHash,
        uint8 response,
        string responseURI,
        bytes32 responseHash,
        string tag
    );

    // =========================================================================
    // Configuration
    // =========================================================================

    /// @notice Get the linked Identity Registry address
    /// @return The Identity Registry contract address
    function getIdentityRegistry() external view returns (address);

    // =========================================================================
    // Validation Request
    // =========================================================================

    /// @notice Submit a validation request for an agent
    /// @dev MUST be called by the agent owner or approved operator
    /// @param validatorAddress The address of the validator to request
    /// @param agentId The agent to be validated
    /// @param requestURI Off-chain URI with request details (optional)
    /// @param requestHash Unique hash identifying this request
    function validationRequest(
        address validatorAddress,
        uint256 agentId,
        string memory requestURI,
        bytes32 requestHash
    ) external;

    // =========================================================================
    // Validation Response
    // =========================================================================

    /// @notice Submit a validation response
    /// @dev MUST be called by the specified validatorAddress
    /// @param requestHash The request being responded to
    /// @param response Score from 0-100 (0=failed, 100=passed)
    /// @param responseURI Off-chain URI with response details (optional)
    /// @param responseHash Hash of the response content (optional)
    /// @param tag Category tag for the validation (optional)
    function validationResponse(
        bytes32 requestHash,
        uint8 response,
        string memory responseURI,
        bytes32 responseHash,
        string memory tag
    ) external;

    // =========================================================================
    // Read Functions
    // =========================================================================

    /// @notice Get the current status of a validation request
    /// @param requestHash The request hash to look up
    /// @return validatorAddress The assigned validator
    /// @return agentId The agent being validated
    /// @return response The validation score (0 if pending)
    /// @return responseHash Hash of the response content
    /// @return tag The validation category tag
    /// @return lastUpdate Timestamp of the last update
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
        );

    /// @notice Get aggregated validation summary for an agent
    /// @param agentId The agent ID
    /// @param validatorAddresses List of validators to include
    /// @param tag Filter by tag (empty = no filter)
    /// @return count Number of matching validations
    /// @return averageResponse Average score across validations
    function getSummary(uint256 agentId, address[] calldata validatorAddresses, string memory tag)
        external
        view
        returns (uint64 count, uint8 averageResponse);

    /// @notice Get all validation request hashes for an agent
    /// @param agentId The agent ID
    /// @return requestHashes Array of request hashes
    function getAgentValidations(uint256 agentId)
        external
        view
        returns (bytes32[] memory requestHashes);

    /// @notice Get all request hashes assigned to a validator
    /// @param validatorAddress The validator address
    /// @return requestHashes Array of request hashes
    function getValidatorRequests(address validatorAddress)
        external
        view
        returns (bytes32[] memory requestHashes);
}
