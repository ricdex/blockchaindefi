// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SoulboundToken} from "./SoulboundToken.sol";

/// @title CredentialRegistry
/// @notice Manages credential types, authorized issuers, and credential issuance/revocation
/// @dev Works with SoulboundToken to mint non-transferable credentials as SBTs
contract CredentialRegistry {
    // =========================================================================
    // Types
    // =========================================================================

    struct CredentialType {
        string name;        // e.g., "Bachelor CS", "Solidity Certification"
        string description; // Description of the credential
        bool active;        // Whether this type is still active
    }

    // =========================================================================
    // State
    // =========================================================================

    address public admin;
    SoulboundToken public soulboundToken;

    /// @notice Counter for credential type IDs
    uint256 public credentialTypeCount;

    /// @notice Credential type definitions
    mapping(uint256 => CredentialType) public credentialTypes;

    /// @notice Authorized issuers per credential type: typeId => issuer => authorized
    mapping(uint256 => mapping(address => bool)) public authorizedIssuers;

    /// @notice Track which credentials a user holds: holder => typeId => tokenId
    /// @dev tokenId + 1 stored (0 means no credential). Allows verifying by type.
    mapping(address => mapping(uint256 => uint256)) private _holderCredentials;

    /// @notice Track if a credential has been revoked (by tokenId)
    mapping(uint256 => bool) public revoked;

    // =========================================================================
    // Events
    // =========================================================================

    event CredentialTypeRegistered(uint256 indexed typeId, string name);
    event IssuerAuthorized(uint256 indexed typeId, address indexed issuer);
    event IssuerRevoked(uint256 indexed typeId, address indexed issuer);
    event CredentialIssued(
        uint256 indexed tokenId,
        address indexed recipient,
        uint256 indexed typeId,
        address issuer
    );
    event CredentialRevoked(uint256 indexed tokenId, address indexed holder, uint256 indexed typeId);

    // =========================================================================
    // Errors
    // =========================================================================

    error OnlyAdmin();
    error NotAuthorizedIssuer();
    error CredentialTypeNotActive();
    error CredentialTypeDoesNotExist();
    error AlreadyHasCredential();
    error NoCredentialToRevoke();
    error NotIssuerOfCredential();
    error ZeroAddress();

    // =========================================================================
    // Modifiers
    // =========================================================================

    modifier onlyAdmin() {
        if (msg.sender != admin) revert OnlyAdmin();
        _;
    }

    modifier validCredentialType(uint256 typeId) {
        if (typeId >= credentialTypeCount) revert CredentialTypeDoesNotExist();
        if (!credentialTypes[typeId].active) revert CredentialTypeNotActive();
        _;
    }

    // =========================================================================
    // Constructor
    // =========================================================================

    /// @param _soulboundToken Address of the SoulboundToken contract
    constructor(address _soulboundToken) {
        admin = msg.sender;
        soulboundToken = SoulboundToken(_soulboundToken);
    }

    // =========================================================================
    // Admin Functions
    // =========================================================================

    /// @notice Register a new credential type
    /// @param _name Name of the credential type
    /// @param _description Description of the credential type
    /// @return typeId The ID of the registered type
    function registerCredentialType(string calldata _name, string calldata _description)
        external
        onlyAdmin
        returns (uint256 typeId)
    {
        typeId = credentialTypeCount++;
        credentialTypes[typeId] = CredentialType({
            name: _name,
            description: _description,
            active: true
        });
        emit CredentialTypeRegistered(typeId, _name);
    }

    /// @notice Authorize an issuer for a specific credential type
    /// @param typeId The credential type ID
    /// @param issuer The address to authorize
    function authorizeIssuer(uint256 typeId, address issuer)
        external
        onlyAdmin
        validCredentialType(typeId)
    {
        if (issuer == address(0)) revert ZeroAddress();
        authorizedIssuers[typeId][issuer] = true;
        emit IssuerAuthorized(typeId, issuer);
    }

    /// @notice Revoke an issuer's authorization for a credential type
    /// @param typeId The credential type ID
    /// @param issuer The address to revoke
    function revokeIssuer(uint256 typeId, address issuer) external onlyAdmin {
        authorizedIssuers[typeId][issuer] = false;
        emit IssuerRevoked(typeId, issuer);
    }

    /// @notice Deactivate a credential type (no new issuance)
    /// @param typeId The credential type ID to deactivate
    function deactivateCredentialType(uint256 typeId) external onlyAdmin {
        if (typeId >= credentialTypeCount) revert CredentialTypeDoesNotExist();
        credentialTypes[typeId].active = false;
    }

    // =========================================================================
    // Issuer Functions
    // =========================================================================

    /// @notice Issue a credential to a recipient (mint SBT)
    /// @param recipient The address receiving the credential
    /// @param typeId The credential type ID
    /// @param metadataURI The URI for credential metadata (IPFS hash, etc.)
    /// @return tokenId The minted SBT token ID
    function issueCredential(address recipient, uint256 typeId, string calldata metadataURI)
        external
        validCredentialType(typeId)
        returns (uint256 tokenId)
    {
        if (!authorizedIssuers[typeId][msg.sender]) revert NotAuthorizedIssuer();
        if (recipient == address(0)) revert ZeroAddress();

        // Check that recipient doesn't already have this credential type
        if (_holderCredentials[recipient][typeId] != 0) revert AlreadyHasCredential();

        // Mint the SBT
        tokenId = soulboundToken.mint(recipient, typeId, msg.sender, metadataURI);

        // Store the credential mapping (tokenId + 1 to distinguish from "no credential" = 0)
        _holderCredentials[recipient][typeId] = tokenId + 1;

        emit CredentialIssued(tokenId, recipient, typeId, msg.sender);
    }

    /// @notice Revoke a credential (burn the SBT)
    /// @dev Only the original issuer of the credential can revoke it
    /// @param tokenId The SBT token ID to revoke
    function revokeCredential(uint256 tokenId) external {
        // Get credential data from the SBT
        (uint256 credTypeId, address issuer,,) = soulboundToken.credentials(tokenId);

        if (msg.sender != issuer) revert NotIssuerOfCredential();

        address holder = soulboundToken.ownerOf(tokenId);

        // Clear the holder credential mapping
        _holderCredentials[holder][credTypeId] = 0;

        // Mark as revoked
        revoked[tokenId] = true;

        // Burn the SBT
        soulboundToken.burn(tokenId);

        emit CredentialRevoked(tokenId, holder, credTypeId);
    }

    // =========================================================================
    // Verification Functions
    // =========================================================================

    /// @notice Verify if an address holds a valid credential of a specific type
    /// @param holder The address to check
    /// @param typeId The credential type ID
    /// @return hasCredential True if the holder has a valid credential
    /// @return tokenId The token ID (0 if no credential)
    function verifyCredential(address holder, uint256 typeId)
        external
        view
        returns (bool hasCredential, uint256 tokenId)
    {
        uint256 stored = _holderCredentials[holder][typeId];
        if (stored == 0) return (false, 0);

        tokenId = stored - 1;

        // Verify the token still exists (not burned)
        if (!soulboundToken.exists(tokenId)) return (false, 0);

        // Verify it's not revoked
        if (revoked[tokenId]) return (false, 0);

        return (true, tokenId);
    }

    /// @notice Check if an address is an authorized issuer for a credential type
    /// @param typeId The credential type ID
    /// @param issuer The address to check
    /// @return True if the address is authorized
    function isAuthorizedIssuer(uint256 typeId, address issuer) external view returns (bool) {
        return authorizedIssuers[typeId][issuer];
    }
}
