// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title GovernanceToken
/// @notice ERC-20 token with vote delegation for governance
/// @dev Simplified ERC20Votes: tracks current voting power via delegation
contract GovernanceToken {
    // =========================================================================
    // ERC-20 State
    // =========================================================================

    string public constant name = "Governance Token";
    string public constant symbol = "GOV";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // =========================================================================
    // Voting State
    // =========================================================================

    /// @notice The delegate for each account (address(0) means self-delegated or undelegated)
    mapping(address => address) public delegates;

    /// @notice Current voting power for each account
    mapping(address => uint256) public votes;

    // =========================================================================
    // Events
    // =========================================================================

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event VotingPowerChanged(address indexed delegate, uint256 previousPower, uint256 newPower);

    // =========================================================================
    // Errors
    // =========================================================================

    error InsufficientBalance();
    error InsufficientAllowance();
    error ZeroAddress();

    // =========================================================================
    // Constructor
    // =========================================================================

    /// @param initialHolders Array of addresses to receive initial tokens
    /// @param amounts Array of token amounts (must match initialHolders length)
    constructor(address[] memory initialHolders, uint256[] memory amounts) {
        require(initialHolders.length == amounts.length, "Length mismatch");
        for (uint256 i = 0; i < initialHolders.length; i++) {
            _mint(initialHolders[i], amounts[i]);
        }
    }

    // =========================================================================
    // ERC-20 Functions
    // =========================================================================

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance < amount) revert InsufficientAllowance();
        unchecked {
            allowance[from][msg.sender] = currentAllowance - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    // =========================================================================
    // Voting Functions
    // =========================================================================

    /// @notice Delegate voting power to another address
    /// @dev Delegating to address(0) removes delegation (votes go nowhere until re-delegated)
    /// @param delegatee The address to delegate voting power to
    function delegate(address delegatee) external {
        address currentDelegate = delegates[msg.sender];
        delegates[msg.sender] = delegatee;

        emit DelegateChanged(msg.sender, currentDelegate, delegatee);

        // Move voting power from old delegate to new delegate
        uint256 senderBalance = balanceOf[msg.sender];
        if (senderBalance > 0) {
            if (currentDelegate != address(0)) {
                _moveVotingPower(currentDelegate, address(0), senderBalance);
            }
            if (delegatee != address(0)) {
                _moveVotingPower(address(0), delegatee, senderBalance);
            }
        }
    }

    /// @notice Get the current voting power of an account
    /// @param account The address to query
    /// @return The current voting power
    function getVotes(address account) external view returns (uint256) {
        return votes[account];
    }

    // =========================================================================
    // Internal Functions
    // =========================================================================

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        unchecked {
            balanceOf[from] -= amount;
        }
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);

        // Move voting power when tokens are transferred
        address fromDelegate = delegates[from];
        address toDelegate = delegates[to];

        if (fromDelegate != address(0) && amount > 0) {
            _moveVotingPower(fromDelegate, address(0), amount);
        }
        if (toDelegate != address(0) && amount > 0) {
            _moveVotingPower(address(0), toDelegate, amount);
        }
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);

        // If recipient has delegated, add to delegate's voting power
        address toDelegate = delegates[to];
        if (toDelegate != address(0)) {
            _moveVotingPower(address(0), toDelegate, amount);
        }
    }

    function _moveVotingPower(address from, address to, uint256 amount) internal {
        if (from != address(0)) {
            uint256 oldPower = votes[from];
            uint256 newPower = oldPower - amount;
            votes[from] = newPower;
            emit VotingPowerChanged(from, oldPower, newPower);
        }
        if (to != address(0)) {
            uint256 oldPower = votes[to];
            uint256 newPower = oldPower + amount;
            votes[to] = newPower;
            emit VotingPowerChanged(to, oldPower, newPower);
        }
    }
}
