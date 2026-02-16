// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SoulboundToken
/// @notice Non-transferable ERC-721 token representing verifiable credentials
/// @dev Implements minimal ERC-721 with transfers blocked (soulbound). Inspired by ERC-5192.
contract SoulboundToken {
    // =========================================================================
    // State
    // =========================================================================

    string public name;
    string public symbol;

    /// @notice Only the registry contract can mint/revoke
    address public registry;

    uint256 private _nextTokenId;

    /// @notice Token ownership
    mapping(uint256 => address) private _owners;

    /// @notice Balance per address
    mapping(address => uint256) private _balances;

    /// @notice Token metadata URI
    mapping(uint256 => string) private _tokenURIs;

    /// @notice Credential data associated with each token
    struct CredentialData {
        uint256 credentialTypeId;
        address issuer;
        uint256 issuedAt;
        string metadataURI;
    }

    mapping(uint256 => CredentialData) public credentials;

    // =========================================================================
    // Events
    // =========================================================================

    /// @notice ERC-721 Transfer event (emitted on mint and burn only)
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /// @notice ERC-5192 Locked event
    event Locked(uint256 tokenId);

    /// @notice Credential-specific events
    event CredentialIssued(
        uint256 indexed tokenId,
        address indexed recipient,
        uint256 indexed credentialTypeId,
        address issuer
    );

    event CredentialRevoked(uint256 indexed tokenId, address indexed holder);

    // =========================================================================
    // Errors
    // =========================================================================

    error OnlyRegistry();
    error TransferBlocked();
    error TokenDoesNotExist();
    error NotTokenHolder();
    error ZeroAddress();

    // =========================================================================
    // Modifiers
    // =========================================================================

    modifier onlyRegistry() {
        if (msg.sender != registry) revert OnlyRegistry();
        _;
    }

    // =========================================================================
    // Constructor
    // =========================================================================

    /// @param _name Token collection name
    /// @param _symbol Token collection symbol
    /// @param _registry Address of the CredentialRegistry that controls minting
    constructor(string memory _name, string memory _symbol, address _registry) {
        name = _name;
        symbol = _symbol;
        registry = _registry;
    }

    // =========================================================================
    // ERC-721 View Functions (Read-only)
    // =========================================================================

    /// @notice Get the balance of an address
    function balanceOf(address owner) external view returns (uint256) {
        if (owner == address(0)) revert ZeroAddress();
        return _balances[owner];
    }

    /// @notice Get the owner of a token
    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _owners[tokenId];
        if (owner == address(0)) revert TokenDoesNotExist();
        return owner;
    }

    /// @notice Get the token URI
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        if (_owners[tokenId] == address(0)) revert TokenDoesNotExist();
        return _tokenURIs[tokenId];
    }

    // =========================================================================
    // ERC-5192: Soulbound
    // =========================================================================

    /// @notice Check if a token is locked (always true for SBTs)
    /// @return True, since all tokens are soulbound
    function locked(uint256 tokenId) external view returns (bool) {
        if (_owners[tokenId] == address(0)) revert TokenDoesNotExist();
        return true;
    }

    // =========================================================================
    // Transfer Functions (All blocked)
    // =========================================================================

    /// @notice Blocked - SBTs cannot be transferred
    function transferFrom(address, address, uint256) external pure {
        revert TransferBlocked();
    }

    /// @notice Blocked - SBTs cannot be transferred
    function safeTransferFrom(address, address, uint256) external pure {
        revert TransferBlocked();
    }

    /// @notice Blocked - SBTs cannot be transferred
    function safeTransferFrom(address, address, uint256, bytes calldata) external pure {
        revert TransferBlocked();
    }

    /// @notice Blocked - SBTs cannot be approved for transfer
    function approve(address, uint256) external pure {
        revert TransferBlocked();
    }

    /// @notice Blocked - SBTs cannot be approved for transfer
    function setApprovalForAll(address, bool) external pure {
        revert TransferBlocked();
    }

    // =========================================================================
    // Mint and Burn (Registry-controlled)
    // =========================================================================

    /// @notice Mint a new SBT credential to a recipient
    /// @dev Only callable by the CredentialRegistry
    /// @param to The recipient address
    /// @param credentialTypeId The type of credential
    /// @param issuer The address of the issuer
    /// @param metadataURI The URI for credential metadata
    /// @return tokenId The ID of the minted token
    function mint(
        address to,
        uint256 credentialTypeId,
        address issuer,
        string calldata metadataURI
    ) external onlyRegistry returns (uint256 tokenId) {
        if (to == address(0)) revert ZeroAddress();

        tokenId = _nextTokenId++;
        _owners[tokenId] = to;
        _balances[to] += 1;
        _tokenURIs[tokenId] = metadataURI;

        credentials[tokenId] = CredentialData({
            credentialTypeId: credentialTypeId,
            issuer: issuer,
            issuedAt: block.timestamp,
            metadataURI: metadataURI
        });

        emit Transfer(address(0), to, tokenId);
        emit Locked(tokenId);
        emit CredentialIssued(tokenId, to, credentialTypeId, issuer);
    }

    /// @notice Burn an SBT (revoke credential)
    /// @dev Callable by the registry (for issuer revocation) or by the token holder
    /// @param tokenId The token to burn
    function burn(uint256 tokenId) external {
        address owner = _owners[tokenId];
        if (owner == address(0)) revert TokenDoesNotExist();

        // Only the holder or the registry can burn
        if (msg.sender != owner && msg.sender != registry) revert NotTokenHolder();

        _balances[owner] -= 1;
        delete _owners[tokenId];
        delete _tokenURIs[tokenId];
        delete credentials[tokenId];

        emit Transfer(owner, address(0), tokenId);
        emit CredentialRevoked(tokenId, owner);
    }

    // =========================================================================
    // Query Functions
    // =========================================================================

    /// @notice Check if a token exists
    /// @param tokenId The token to check
    /// @return True if the token exists
    function exists(uint256 tokenId) external view returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /// @notice Get the next token ID that will be minted
    function nextTokenId() external view returns (uint256) {
        return _nextTokenId;
    }
}
