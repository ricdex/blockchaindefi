// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IdentityRegistry} from "./IdentityRegistry.sol";

/**
 * @title RWAToken
 * @notice A regulated ERC-20 token for Real World Assets with transfer
 *         restrictions, role-based access control, account freezing,
 *         pause functionality, and forced transfers for compliance.
 *
 * @dev Simplified implementation inspired by ERC-3643 (T-REX).
 *      In production, consider using the full T-REX standard or
 *      OpenZeppelin's AccessControl for more robust role management.
 *
 * Roles:
 *   - ADMIN: manages roles, initial configuration
 *   - COMPLIANCE_OFFICER: manages whitelist, freeze, force transfer, recovery
 *   - AGENT: pause/unpause all transfers
 */
contract RWAToken {
    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------

    error NotAdmin();
    error NotComplianceOfficer();
    error NotAgent();
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance(uint256 available, uint256 required);
    error InsufficientAllowance(uint256 available, uint256 required);
    error TransfersPaused();
    error AccountFrozenError(address account);
    error SenderNotWhitelisted(address sender);
    error ReceiverNotWhitelisted(address receiver);
    error SenderCountryRestricted(address sender);
    error ReceiverCountryRestricted(address receiver);
    error AccountNotFrozen(address account);
    error SameAddress();

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event AccountFrozen(address indexed account);
    event AccountUnfrozen(address indexed account);
    event ForcedTransfer(
        address indexed from,
        address indexed to,
        uint256 amount,
        address indexed complianceOfficer
    );
    event TokenRecovery(
        address indexed lostWallet,
        address indexed newWallet,
        uint256 amount,
        address indexed complianceOfficer
    );
    event Paused(address indexed agent);
    event Unpaused(address indexed agent);
    event RoleGranted(bytes32 indexed role, address indexed account);
    event RoleRevoked(bytes32 indexed role, address indexed account);

    // -----------------------------------------------------------------------
    // Role Constants
    // -----------------------------------------------------------------------

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant COMPLIANCE_OFFICER_ROLE = keccak256("COMPLIANCE_OFFICER_ROLE");
    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");

    // -----------------------------------------------------------------------
    // ERC-20 State
    // -----------------------------------------------------------------------

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // -----------------------------------------------------------------------
    // Compliance State
    // -----------------------------------------------------------------------

    /// @notice Reference to the IdentityRegistry for whitelist checks.
    IdentityRegistry public identityRegistry;

    /// @notice Role assignments: role hash -> address -> has role.
    mapping(bytes32 => mapping(address => bool)) public roles;

    /// @notice Individually frozen accounts.
    mapping(address => bool) public frozenAccounts;

    /// @notice Global pause flag for all transfers.
    bool public paused;

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------

    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert TransfersPaused();
        _;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    /**
     * @param _name             Token name.
     * @param _symbol           Token symbol.
     * @param _identityRegistry Address of the deployed IdentityRegistry.
     * @param _initialSupply    Tokens to mint to the deployer.
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _identityRegistry,
        uint256 _initialSupply
    ) {
        if (_identityRegistry == address(0)) revert ZeroAddress();

        name = _name;
        symbol = _symbol;
        identityRegistry = IdentityRegistry(_identityRegistry);

        // Grant all roles to deployer
        roles[ADMIN_ROLE][msg.sender] = true;
        roles[COMPLIANCE_OFFICER_ROLE][msg.sender] = true;
        roles[AGENT_ROLE][msg.sender] = true;

        emit RoleGranted(ADMIN_ROLE, msg.sender);
        emit RoleGranted(COMPLIANCE_OFFICER_ROLE, msg.sender);
        emit RoleGranted(AGENT_ROLE, msg.sender);

        // Mint initial supply to deployer
        if (_initialSupply > 0) {
            totalSupply = _initialSupply;
            balanceOf[msg.sender] = _initialSupply;
            emit Transfer(address(0), msg.sender, _initialSupply);
        }
    }

    // -----------------------------------------------------------------------
    // Role Management (ADMIN only)
    // -----------------------------------------------------------------------

    /**
     * @notice Grant a role to an account.
     * @param role    The role identifier.
     * @param account The address to grant the role to.
     */
    function grantRole(bytes32 role, address account) external onlyRole(ADMIN_ROLE) {
        if (account == address(0)) revert ZeroAddress();
        roles[role][account] = true;
        emit RoleGranted(role, account);
    }

    /**
     * @notice Revoke a role from an account.
     * @param role    The role identifier.
     * @param account The address to revoke the role from.
     */
    function revokeRole(bytes32 role, address account) external onlyRole(ADMIN_ROLE) {
        if (account == address(0)) revert ZeroAddress();
        roles[role][account] = false;
        emit RoleRevoked(role, account);
    }

    /**
     * @notice Check if an account has a specific role.
     * @param role    The role identifier.
     * @param account The address to check.
     * @return True if the account has the role.
     */
    function hasRole(bytes32 role, address account) external view returns (bool) {
        return roles[role][account];
    }

    // -----------------------------------------------------------------------
    // ERC-20 Functions
    // -----------------------------------------------------------------------

    /**
     * @notice Approve a spender to transfer tokens on behalf of the caller.
     * @param spender The address being approved.
     * @param amount  The number of tokens approved.
     * @return True on success.
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /**
     * @notice Transfer tokens to a recipient. Both sender and receiver must
     *         be whitelisted, not frozen, and transfers must not be paused.
     * @param to     The recipient address.
     * @param amount The number of tokens to transfer.
     * @return True on success.
     */
    function transfer(address to, uint256 amount) external whenNotPaused returns (bool) {
        _validateCompliance(msg.sender, to);
        _transfer(msg.sender, to, amount);
        return true;
    }

    /**
     * @notice Transfer tokens on behalf of another account. Subject to all
     *         compliance checks and allowance limits.
     * @param from   The sender address.
     * @param to     The recipient address.
     * @param amount The number of tokens to transfer.
     * @return True on success.
     */
    function transferFrom(address from, address to, uint256 amount) external whenNotPaused returns (bool) {
        _validateCompliance(from, to);

        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) {
                revert InsufficientAllowance(currentAllowance, amount);
            }
            allowance[from][msg.sender] = currentAllowance - amount;
        }

        _transfer(from, to, amount);
        return true;
    }

    // -----------------------------------------------------------------------
    // Compliance Officer Functions
    // -----------------------------------------------------------------------

    /**
     * @notice Freeze an individual account, blocking all transfers to/from it.
     * @param account The address to freeze.
     */
    function freezeAccount(address account) external onlyRole(COMPLIANCE_OFFICER_ROLE) {
        if (account == address(0)) revert ZeroAddress();
        frozenAccounts[account] = true;
        emit AccountFrozen(account);
    }

    /**
     * @notice Unfreeze a previously frozen account.
     * @param account The address to unfreeze.
     */
    function unfreezeAccount(address account) external onlyRole(COMPLIANCE_OFFICER_ROLE) {
        if (account == address(0)) revert ZeroAddress();
        if (!frozenAccounts[account]) revert AccountNotFrozen(account);
        frozenAccounts[account] = false;
        emit AccountUnfrozen(account);
    }

    /**
     * @notice Force transfer tokens between two addresses. Used for
     *         regulatory compliance (e.g., court orders, sanctions enforcement).
     * @param from   The address to transfer from.
     * @param to     The address to transfer to.
     * @param amount The number of tokens to transfer.
     */
    function forceTransfer(
        address from,
        address to,
        uint256 amount
    ) external onlyRole(COMPLIANCE_OFFICER_ROLE) {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        _transfer(from, to, amount);
        emit ForcedTransfer(from, to, amount, msg.sender);
    }

    /**
     * @notice Recover tokens from a lost wallet to a new wallet.
     *         The new wallet must be a verified investor.
     * @param lostWallet The address of the lost/compromised wallet.
     * @param newWallet  The address of the replacement wallet.
     */
    function recoverTokens(
        address lostWallet,
        address newWallet
    ) external onlyRole(COMPLIANCE_OFFICER_ROLE) {
        if (lostWallet == address(0) || newWallet == address(0)) revert ZeroAddress();
        if (lostWallet == newWallet) revert SameAddress();
        if (!identityRegistry.isVerifiedInvestor(newWallet)) {
            revert ReceiverNotWhitelisted(newWallet);
        }

        uint256 amount = balanceOf[lostWallet];
        if (amount == 0) revert ZeroAmount();

        _transfer(lostWallet, newWallet, amount);
        emit TokenRecovery(lostWallet, newWallet, amount, msg.sender);
    }

    // -----------------------------------------------------------------------
    // Agent Functions
    // -----------------------------------------------------------------------

    /**
     * @notice Pause all token transfers.
     */
    function pause() external onlyRole(AGENT_ROLE) {
        paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @notice Unpause token transfers.
     */
    function unpause() external onlyRole(AGENT_ROLE) {
        paused = false;
        emit Unpaused(msg.sender);
    }

    // -----------------------------------------------------------------------
    // Internal Functions
    // -----------------------------------------------------------------------

    /**
     * @dev Validate that both sender and receiver pass compliance checks.
     */
    function _validateCompliance(address from, address to) internal view {
        // Check frozen status
        if (frozenAccounts[from]) revert AccountFrozenError(from);
        if (frozenAccounts[to]) revert AccountFrozenError(to);

        // Check whitelist
        if (!identityRegistry.isVerifiedInvestor(from)) {
            revert SenderNotWhitelisted(from);
        }
        if (!identityRegistry.isVerifiedInvestor(to)) {
            revert ReceiverNotWhitelisted(to);
        }

        // Check country restrictions
        uint16 fromCountry = identityRegistry.getCountryCode(from);
        uint16 toCountry = identityRegistry.getCountryCode(to);

        if (identityRegistry.isCountryRestricted(fromCountry)) {
            revert SenderCountryRestricted(from);
        }
        if (identityRegistry.isCountryRestricted(toCountry)) {
            revert ReceiverCountryRestricted(to);
        }
    }

    /**
     * @dev Execute the token transfer (no compliance checks here).
     */
    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 senderBalance = balanceOf[from];
        if (senderBalance < amount) {
            revert InsufficientBalance(senderBalance, amount);
        }

        balanceOf[from] = senderBalance - amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    /**
     * @dev Internal role check that reverts with the appropriate error.
     */
    function _checkRole(bytes32 role) internal view {
        if (role == ADMIN_ROLE && !roles[ADMIN_ROLE][msg.sender]) {
            revert NotAdmin();
        } else if (role == COMPLIANCE_OFFICER_ROLE && !roles[COMPLIANCE_OFFICER_ROLE][msg.sender]) {
            revert NotComplianceOfficer();
        } else if (role == AGENT_ROLE && !roles[AGENT_ROLE][msg.sender]) {
            revert NotAgent();
        }
    }
}
