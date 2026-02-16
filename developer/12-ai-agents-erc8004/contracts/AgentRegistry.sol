// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IIdentityRegistry} from "./interfaces/IIdentityRegistry.sol";

/// @title AgentRegistry
/// @notice ERC-8004 Identity Registry implementation
/// @dev ERC-721 based agent registration with extensible metadata and EIP-712 wallet verification
contract AgentRegistry is IIdentityRegistry {
    // =========================================================================
    // Constants
    // =========================================================================

    /// @notice Reserved metadata key for agent wallet
    string public constant AGENT_WALLET_KEY = "agentWallet";

    /// @notice EIP-712 domain separator components
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 public constant SET_AGENT_WALLET_TYPEHASH =
        keccak256("SetAgentWallet(uint256 agentId,address newWallet,uint256 deadline)");

    // =========================================================================
    // ERC-721 State
    // =========================================================================

    string public name;
    string public symbol;

    uint256 private _nextTokenId;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // =========================================================================
    // Agent State
    // =========================================================================

    /// @notice Agent URI (points to registration file JSON)
    mapping(uint256 => string) private _agentURIs;

    /// @notice Agent metadata: agentId => key => value
    mapping(uint256 => mapping(string => bytes)) private _metadata;

    /// @notice Agent wallet: agentId => wallet address
    mapping(uint256 => address) private _agentWallets;

    /// @notice EIP-712 domain separator (computed at deploy)
    bytes32 public immutable DOMAIN_SEPARATOR;

    // =========================================================================
    // Events (ERC-721)
    // =========================================================================

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    // =========================================================================
    // Errors
    // =========================================================================

    error NotOwnerOrApproved();
    error TokenDoesNotExist();
    error ZeroAddress();
    error TransferToNonReceiver();
    error ReservedMetadataKey();
    error InvalidSignature();
    error SignatureExpired();
    error WalletAlreadyLinked();

    // =========================================================================
    // Constructor
    // =========================================================================

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(_name)),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    // =========================================================================
    // Registration (IIdentityRegistry)
    // =========================================================================

    /// @inheritdoc IIdentityRegistry
    function register(string memory agentURI, MetadataEntry[] calldata metadata)
        external
        returns (uint256 agentId)
    {
        agentId = _mint(msg.sender);
        _agentURIs[agentId] = agentURI;

        for (uint256 i = 0; i < metadata.length; i++) {
            if (_isReservedKey(metadata[i].metadataKey)) revert ReservedMetadataKey();
            _metadata[agentId][metadata[i].metadataKey] = metadata[i].metadataValue;
            emit MetadataSet(agentId, metadata[i].metadataKey, metadata[i].metadataKey, metadata[i].metadataValue);
        }

        emit Registered(agentId, agentURI, msg.sender);
    }

    /// @inheritdoc IIdentityRegistry
    function register(string memory agentURI) external returns (uint256 agentId) {
        agentId = _mint(msg.sender);
        _agentURIs[agentId] = agentURI;
        emit Registered(agentId, agentURI, msg.sender);
    }

    /// @inheritdoc IIdentityRegistry
    function register() external returns (uint256 agentId) {
        agentId = _mint(msg.sender);
        emit Registered(agentId, "", msg.sender);
    }

    // =========================================================================
    // URI Management
    // =========================================================================

    /// @inheritdoc IIdentityRegistry
    function setAgentURI(uint256 agentId, string calldata newURI) external {
        if (!_isApprovedOrOwner(msg.sender, agentId)) revert NotOwnerOrApproved();
        _agentURIs[agentId] = newURI;
        emit URIUpdated(agentId, newURI, msg.sender);
    }

    /// @notice Get the agent URI (ERC-721 tokenURI compatible)
    function tokenURI(uint256 agentId) external view returns (string memory) {
        if (_owners[agentId] == address(0)) revert TokenDoesNotExist();
        return _agentURIs[agentId];
    }

    // =========================================================================
    // Metadata
    // =========================================================================

    /// @inheritdoc IIdentityRegistry
    function getMetadata(uint256 agentId, string memory metadataKey)
        external
        view
        returns (bytes memory)
    {
        if (_owners[agentId] == address(0)) revert TokenDoesNotExist();
        return _metadata[agentId][metadataKey];
    }

    /// @inheritdoc IIdentityRegistry
    function setMetadata(uint256 agentId, string memory metadataKey, bytes memory metadataValue)
        external
    {
        if (!_isApprovedOrOwner(msg.sender, agentId)) revert NotOwnerOrApproved();
        if (_isReservedKey(metadataKey)) revert ReservedMetadataKey();
        _metadata[agentId][metadataKey] = metadataValue;
        emit MetadataSet(agentId, metadataKey, metadataKey, metadataValue);
    }

    // =========================================================================
    // Agent Wallet
    // =========================================================================

    /// @inheritdoc IIdentityRegistry
    function setAgentWallet(
        uint256 agentId,
        address newWallet,
        uint256 deadline,
        bytes calldata signature
    ) external {
        if (!_isApprovedOrOwner(msg.sender, agentId)) revert NotOwnerOrApproved();
        if (newWallet == address(0)) revert ZeroAddress();
        if (block.timestamp > deadline) revert SignatureExpired();

        // Verify EIP-712 signature from the new wallet
        bytes32 structHash = keccak256(abi.encode(SET_AGENT_WALLET_TYPEHASH, agentId, newWallet, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));

        address recovered = _recoverSigner(digest, signature);
        if (recovered != newWallet) revert InvalidSignature();

        _agentWallets[agentId] = newWallet;
        emit MetadataSet(agentId, AGENT_WALLET_KEY, AGENT_WALLET_KEY, abi.encodePacked(newWallet));
    }

    /// @inheritdoc IIdentityRegistry
    function getAgentWallet(uint256 agentId) external view returns (address) {
        if (_owners[agentId] == address(0)) revert TokenDoesNotExist();
        return _agentWallets[agentId];
    }

    /// @inheritdoc IIdentityRegistry
    function unsetAgentWallet(uint256 agentId) external {
        if (!_isApprovedOrOwner(msg.sender, agentId)) revert NotOwnerOrApproved();
        delete _agentWallets[agentId];
        emit MetadataSet(agentId, AGENT_WALLET_KEY, AGENT_WALLET_KEY, "");
    }

    // =========================================================================
    // ERC-721 View Functions
    // =========================================================================

    function balanceOf(address owner) external view returns (uint256) {
        if (owner == address(0)) revert ZeroAddress();
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _owners[tokenId];
        if (owner == address(0)) revert TokenDoesNotExist();
        return owner;
    }

    function getApproved(uint256 tokenId) public view returns (address) {
        if (_owners[tokenId] == address(0)) revert TokenDoesNotExist();
        return _tokenApprovals[tokenId];
    }

    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function exists(uint256 tokenId) external view returns (bool) {
        return _owners[tokenId] != address(0);
    }

    function nextTokenId() external view returns (uint256) {
        return _nextTokenId;
    }

    // =========================================================================
    // ERC-721 Transfer Functions
    // =========================================================================

    function approve(address to, uint256 tokenId) external {
        address owner = ownerOf(tokenId);
        if (msg.sender != owner && !isApprovedForAll(owner, msg.sender)) revert NotOwnerOrApproved();
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) revert NotOwnerOrApproved();
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata) external {
        transferFrom(from, to, tokenId);
    }

    // =========================================================================
    // ERC-165
    // =========================================================================

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x80ac58cd // ERC-721
            || interfaceId == 0x01ffc9a7; // ERC-165
    }

    // =========================================================================
    // Internal Functions
    // =========================================================================

    function _mint(address to) internal returns (uint256 tokenId) {
        if (to == address(0)) revert ZeroAddress();
        tokenId = _nextTokenId++;
        _owners[tokenId] = to;
        _balances[to] += 1;
        emit Transfer(address(0), to, tokenId);
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        if (ownerOf(tokenId) != from) revert NotOwnerOrApproved();
        if (to == address(0)) revert ZeroAddress();

        delete _tokenApprovals[tokenId];

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        // ERC-8004: Clear agent wallet on transfer
        delete _agentWallets[tokenId];

        emit Transfer(from, to, tokenId);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    function _isReservedKey(string memory key) internal pure returns (bool) {
        return keccak256(bytes(key)) == keccak256(bytes("agentWallet"));
    }

    function _recoverSigner(bytes32 digest, bytes calldata signature) internal pure returns (address) {
        if (signature.length != 65) revert InvalidSignature();
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }
        if (v < 27) v += 27;
        address recovered = ecrecover(digest, v, r, s);
        if (recovered == address(0)) revert InvalidSignature();
        return recovered;
    }
}
