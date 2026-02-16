// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MockOracle
/// @notice Simple mock oracle for ETH/USD price feed (for testing purposes)
/// @dev Returns price with 8 decimals (same convention as Chainlink)
contract MockOracle {
    int256 private _price;
    uint8 private constant DECIMALS = 8;
    address public owner;

    event PriceUpdated(int256 oldPrice, int256 newPrice);

    error OnlyOwner();
    error InvalidPrice();

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    /// @param initialPrice The initial ETH/USD price with 8 decimals (e.g., 3000e8 = $3000)
    constructor(int256 initialPrice) {
        if (initialPrice <= 0) revert InvalidPrice();
        owner = msg.sender;
        _price = initialPrice;
    }

    /// @notice Update the ETH/USD price
    /// @param newPrice The new price with 8 decimals
    function setPrice(int256 newPrice) external onlyOwner {
        if (newPrice <= 0) revert InvalidPrice();
        int256 oldPrice = _price;
        _price = newPrice;
        emit PriceUpdated(oldPrice, newPrice);
    }

    /// @notice Get the latest ETH/USD price
    /// @return price The current price with 8 decimals
    function getLatestPrice() external view returns (int256 price) {
        return _price;
    }

    /// @notice Get the number of decimals for the price feed
    /// @return The number of decimals (8)
    function decimals() external pure returns (uint8) {
        return DECIMALS;
    }
}
