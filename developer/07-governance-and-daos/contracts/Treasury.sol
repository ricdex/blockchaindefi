// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Treasury
/// @notice Simple treasury contract controlled by a governor
/// @dev Holds ETH and can execute arbitrary calls, only callable by the governor
contract Treasury {
    address public governor;

    event EthReceived(address indexed sender, uint256 amount);
    event CallExecuted(address indexed target, uint256 value, bytes data);

    error OnlyGovernor();
    error CallFailed();

    modifier onlyGovernor() {
        if (msg.sender != governor) revert OnlyGovernor();
        _;
    }

    constructor(address _governor) {
        governor = _governor;
    }

    /// @notice Execute an arbitrary call from the treasury
    /// @param target The address to call
    /// @param value The ETH value to send
    /// @param data The calldata to send
    function execute(address target, uint256 value, bytes calldata data) external onlyGovernor {
        (bool success,) = target.call{value: value}(data);
        if (!success) revert CallFailed();
        emit CallExecuted(target, value, data);
    }

    /// @notice Allow the treasury to receive ETH
    receive() external payable {
        emit EthReceived(msg.sender, msg.value);
    }
}
