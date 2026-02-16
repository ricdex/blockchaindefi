// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MockOracle} from "./MockOracle.sol";

/// @title SimpleStablecoin
/// @notice CDP-based stablecoin collateralized with ETH
/// @dev Implements ERC-20 inline and CDP management with liquidation mechanics
contract SimpleStablecoin {
    // =========================================================================
    // ERC-20 State
    // =========================================================================

    string public constant name = "Simple USD";
    string public constant symbol = "sUSD";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // =========================================================================
    // CDP State
    // =========================================================================

    struct CDP {
        uint256 collateral; // ETH deposited (in wei)
        uint256 debt;       // sUSD minted (in wei, 18 decimals)
    }

    mapping(address => CDP) public cdps;

    MockOracle public immutable oracle;

    /// @notice Minimum collateral ratio in basis points (15000 = 150%)
    uint256 public constant MIN_COLLATERAL_RATIO = 15000;

    /// @notice Liquidation discount in basis points (1000 = 10%)
    uint256 public constant LIQUIDATION_DISCOUNT = 1000;

    /// @notice Basis points denominator
    uint256 private constant BPS = 10000;

    /// @notice Oracle price decimals
    uint256 private constant ORACLE_DECIMALS = 1e8;

    // =========================================================================
    // Events - ERC-20
    // =========================================================================

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // =========================================================================
    // Events - CDP
    // =========================================================================

    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event StablecoinMinted(address indexed user, uint256 amount);
    event StablecoinBurned(address indexed user, uint256 amount);
    event Liquidated(
        address indexed liquidator,
        address indexed user,
        uint256 debtRepaid,
        uint256 collateralSeized
    );

    // =========================================================================
    // Errors
    // =========================================================================

    error ZeroAmount();
    error InsufficientBalance();
    error InsufficientAllowance();
    error BelowMinCollateralRatio();
    error PositionHealthy();
    error NoDebtToLiquidate();
    error InsufficientCollateral();
    error TransferFailed();

    // =========================================================================
    // Constructor
    // =========================================================================

    /// @param _oracle Address of the MockOracle contract providing ETH/USD price
    constructor(address _oracle) {
        oracle = MockOracle(_oracle);
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
        return _transfer(msg.sender, to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance < amount) revert InsufficientAllowance();
        unchecked {
            allowance[from][msg.sender] = currentAllowance - amount;
        }
        return _transfer(from, to, amount);
    }

    // =========================================================================
    // CDP Functions
    // =========================================================================

    /// @notice Deposit ETH as collateral into the caller's CDP
    function depositCollateral() external payable {
        if (msg.value == 0) revert ZeroAmount();
        cdps[msg.sender].collateral += msg.value;
        emit CollateralDeposited(msg.sender, msg.value);
    }

    /// @notice Mint sUSD stablecoin against the caller's collateral
    /// @param amount Amount of sUSD to mint (18 decimals)
    function mintStablecoin(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        CDP storage position = cdps[msg.sender];
        uint256 newDebt = position.debt + amount;

        // Verify collateral ratio after minting
        if (!_isHealthy(position.collateral, newDebt)) {
            revert BelowMinCollateralRatio();
        }

        position.debt = newDebt;
        _mint(msg.sender, amount);
        emit StablecoinMinted(msg.sender, amount);
    }

    /// @notice Burn sUSD to reduce debt in the caller's CDP
    /// @param amount Amount of sUSD to burn (18 decimals)
    function burnStablecoin(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (amount > cdps[msg.sender].debt) revert ZeroAmount();

        cdps[msg.sender].debt -= amount;
        _burn(msg.sender, amount);
        emit StablecoinBurned(msg.sender, amount);
    }

    /// @notice Withdraw ETH collateral from the caller's CDP
    /// @param amount Amount of ETH to withdraw (in wei)
    function withdrawCollateral(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        CDP storage position = cdps[msg.sender];
        if (position.collateral < amount) revert InsufficientCollateral();

        uint256 newCollateral = position.collateral - amount;

        // If there's still debt, verify ratio remains healthy
        if (position.debt > 0 && !_isHealthy(newCollateral, position.debt)) {
            revert BelowMinCollateralRatio();
        }

        position.collateral = newCollateral;

        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit CollateralWithdrawn(msg.sender, amount);
    }

    /// @notice Liquidate an undercollateralized CDP
    /// @dev Liquidator repays the full debt and receives collateral at a 10% discount
    /// @param user The address of the CDP owner to liquidate
    function liquidate(address user) external {
        CDP storage position = cdps[user];

        if (position.debt == 0) revert NoDebtToLiquidate();
        if (_isHealthy(position.collateral, position.debt)) revert PositionHealthy();

        uint256 debtToRepay = position.debt;
        uint256 ethPrice = _getEthPrice();

        // Calculate collateral value of the debt (how much ETH the debt is worth)
        // debtToRepay is in 18 decimals (sUSD), ethPrice is in 8 decimals
        // collateralValue = debtToRepay / ethPrice (adjusted for decimals)
        uint256 collateralToSeize = (debtToRepay * 1e8) / ethPrice;

        // Apply liquidation bonus (10% more collateral to incentivize liquidators)
        uint256 collateralWithDiscount = (collateralToSeize * (BPS + LIQUIDATION_DISCOUNT)) / BPS;

        // Cap at available collateral
        if (collateralWithDiscount > position.collateral) {
            collateralWithDiscount = position.collateral;
        }

        // Burn stablecoin from liquidator
        _burn(msg.sender, debtToRepay);

        // Update CDP
        position.debt = 0;
        position.collateral -= collateralWithDiscount;

        // Transfer collateral to liquidator
        (bool success,) = payable(msg.sender).call{value: collateralWithDiscount}("");
        if (!success) revert TransferFailed();

        emit Liquidated(msg.sender, user, debtToRepay, collateralWithDiscount);
    }

    // =========================================================================
    // View Functions
    // =========================================================================

    /// @notice Get the current collateral ratio of a CDP in basis points
    /// @param user The CDP owner address
    /// @return ratio The collateral ratio in basis points (e.g., 15000 = 150%)
    function getCollateralRatio(address user) external view returns (uint256 ratio) {
        CDP memory position = cdps[user];
        if (position.debt == 0) return type(uint256).max;
        return _collateralRatio(position.collateral, position.debt);
    }

    /// @notice Check if a CDP is healthy (above minimum collateral ratio)
    /// @param user The CDP owner address
    /// @return True if the position is healthy
    function isPositionHealthy(address user) external view returns (bool) {
        CDP memory position = cdps[user];
        if (position.debt == 0) return true;
        return _isHealthy(position.collateral, position.debt);
    }

    // =========================================================================
    // Internal Functions
    // =========================================================================

    function _transfer(address from, address to, uint256 amount) internal returns (bool) {
        if (balanceOf[from] < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] -= amount;
        }
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] -= amount;
        }
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function _getEthPrice() internal view returns (uint256) {
        int256 price = oracle.getLatestPrice();
        require(price > 0, "Invalid oracle price");
        return uint256(price);
    }

    /// @dev Calculate collateral ratio in basis points
    /// collateralValue (USD) = collateral (ETH) * ethPrice / 1e8
    /// ratio = collateralValue / debt * 10000 (BPS)
    function _collateralRatio(uint256 collateral, uint256 debt) internal view returns (uint256) {
        uint256 ethPrice = _getEthPrice();
        // collateral is in wei (18 decimals), ethPrice in 8 decimals, debt in 18 decimals
        // collateralValueUsd = collateral * ethPrice / 1e8 (result in 18 decimals)
        // ratio = collateralValueUsd * BPS / debt
        uint256 collateralValueUsd = (collateral * ethPrice) / ORACLE_DECIMALS;
        return (collateralValueUsd * BPS) / debt;
    }

    function _isHealthy(uint256 collateral, uint256 debt) internal view returns (bool) {
        if (debt == 0) return true;
        return _collateralRatio(collateral, debt) >= MIN_COLLATERAL_RATIO;
    }
}
