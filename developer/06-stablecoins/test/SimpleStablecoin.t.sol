// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {SimpleStablecoin} from "../contracts/SimpleStablecoin.sol";
import {MockOracle} from "../contracts/MockOracle.sol";

contract SimpleStablecoinTest is Test {
    SimpleStablecoin public stablecoin;
    MockOracle public oracle;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public liquidator = makeAddr("liquidator");

    // ETH price: $3000 with 8 decimals
    int256 constant INITIAL_ETH_PRICE = 3000e8;

    function setUp() public {
        oracle = new MockOracle(INITIAL_ETH_PRICE);
        stablecoin = new SimpleStablecoin(address(oracle));

        // Fund test accounts
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(liquidator, 100 ether);
    }

    // =========================================================================
    // Deposit Collateral Tests
    // =========================================================================

    function test_DepositCollateral() public {
        vm.prank(alice);
        stablecoin.depositCollateral{value: 1 ether}();

        (uint256 collateral, uint256 debt) = stablecoin.cdps(alice);
        assertEq(collateral, 1 ether);
        assertEq(debt, 0);
    }

    function test_DepositCollateral_EmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit SimpleStablecoin.CollateralDeposited(alice, 1 ether);

        vm.prank(alice);
        stablecoin.depositCollateral{value: 1 ether}();
    }

    function test_DepositCollateral_RevertsOnZero() public {
        vm.prank(alice);
        vm.expectRevert(SimpleStablecoin.ZeroAmount.selector);
        stablecoin.depositCollateral{value: 0}();
    }

    function test_DepositCollateral_Multiple() public {
        vm.startPrank(alice);
        stablecoin.depositCollateral{value: 1 ether}();
        stablecoin.depositCollateral{value: 2 ether}();
        vm.stopPrank();

        (uint256 collateral,) = stablecoin.cdps(alice);
        assertEq(collateral, 3 ether);
    }

    // =========================================================================
    // Mint Stablecoin Tests
    // =========================================================================

    function test_MintStablecoin_WithinRatio() public {
        vm.startPrank(alice);
        stablecoin.depositCollateral{value: 1 ether}();

        // 1 ETH = $3000, 150% ratio -> max mint = $2000
        // Mint $1000 (safe, ratio = 300%)
        stablecoin.mintStablecoin(1000e18);
        vm.stopPrank();

        assertEq(stablecoin.balanceOf(alice), 1000e18);
        assertEq(stablecoin.totalSupply(), 1000e18);

        (, uint256 debt) = stablecoin.cdps(alice);
        assertEq(debt, 1000e18);
    }

    function test_MintStablecoin_AtExactRatio() public {
        vm.startPrank(alice);
        stablecoin.depositCollateral{value: 1 ether}();

        // 1 ETH = $3000, 150% ratio -> max mint = $2000
        stablecoin.mintStablecoin(2000e18);
        vm.stopPrank();

        assertEq(stablecoin.balanceOf(alice), 2000e18);
        uint256 ratio = stablecoin.getCollateralRatio(alice);
        assertEq(ratio, 15000); // 150% in BPS
    }

    function test_MintStablecoin_RevertsAboveRatio() public {
        vm.startPrank(alice);
        stablecoin.depositCollateral{value: 1 ether}();

        // Trying to mint $2001 with $3000 collateral -> ratio < 150%
        vm.expectRevert(SimpleStablecoin.BelowMinCollateralRatio.selector);
        stablecoin.mintStablecoin(2001e18);
        vm.stopPrank();
    }

    function test_MintStablecoin_RevertsOnZero() public {
        vm.startPrank(alice);
        stablecoin.depositCollateral{value: 1 ether}();
        vm.expectRevert(SimpleStablecoin.ZeroAmount.selector);
        stablecoin.mintStablecoin(0);
        vm.stopPrank();
    }

    function test_MintStablecoin_EmitsEvent() public {
        vm.startPrank(alice);
        stablecoin.depositCollateral{value: 1 ether}();

        vm.expectEmit(true, false, false, true);
        emit SimpleStablecoin.StablecoinMinted(alice, 1000e18);

        stablecoin.mintStablecoin(1000e18);
        vm.stopPrank();
    }

    // =========================================================================
    // Burn Stablecoin Tests
    // =========================================================================

    function test_BurnStablecoin() public {
        vm.startPrank(alice);
        stablecoin.depositCollateral{value: 1 ether}();
        stablecoin.mintStablecoin(1000e18);

        stablecoin.burnStablecoin(500e18);
        vm.stopPrank();

        assertEq(stablecoin.balanceOf(alice), 500e18);
        (, uint256 debt) = stablecoin.cdps(alice);
        assertEq(debt, 500e18);
    }

    function test_BurnStablecoin_EmitsEvent() public {
        vm.startPrank(alice);
        stablecoin.depositCollateral{value: 1 ether}();
        stablecoin.mintStablecoin(1000e18);

        vm.expectEmit(true, false, false, true);
        emit SimpleStablecoin.StablecoinBurned(alice, 500e18);

        stablecoin.burnStablecoin(500e18);
        vm.stopPrank();
    }

    function test_BurnStablecoin_RevertsOnZero() public {
        vm.startPrank(alice);
        stablecoin.depositCollateral{value: 1 ether}();
        stablecoin.mintStablecoin(1000e18);

        vm.expectRevert(SimpleStablecoin.ZeroAmount.selector);
        stablecoin.burnStablecoin(0);
        vm.stopPrank();
    }

    // =========================================================================
    // Withdraw Collateral Tests
    // =========================================================================

    function test_WithdrawCollateral_NoDebt() public {
        vm.startPrank(alice);
        stablecoin.depositCollateral{value: 2 ether}();
        stablecoin.withdrawCollateral(1 ether);
        vm.stopPrank();

        (uint256 collateral,) = stablecoin.cdps(alice);
        assertEq(collateral, 1 ether);
    }

    function test_WithdrawCollateral_WithDebt_Healthy() public {
        vm.startPrank(alice);
        stablecoin.depositCollateral{value: 3 ether}();
        stablecoin.mintStablecoin(2000e18);

        // 3 ETH ($9000) with $2000 debt = 450% ratio
        // Withdraw 1 ETH -> 2 ETH ($6000) with $2000 debt = 300% still healthy
        stablecoin.withdrawCollateral(1 ether);
        vm.stopPrank();

        (uint256 collateral,) = stablecoin.cdps(alice);
        assertEq(collateral, 2 ether);
    }

    function test_WithdrawCollateral_RevertsIfUndercollateralized() public {
        vm.startPrank(alice);
        stablecoin.depositCollateral{value: 1 ether}();
        stablecoin.mintStablecoin(2000e18); // exactly 150%

        // Withdrawing any collateral would break ratio
        vm.expectRevert(SimpleStablecoin.BelowMinCollateralRatio.selector);
        stablecoin.withdrawCollateral(0.01 ether);
        vm.stopPrank();
    }

    function test_WithdrawCollateral_RevertsOnInsufficientCollateral() public {
        vm.startPrank(alice);
        stablecoin.depositCollateral{value: 1 ether}();

        vm.expectRevert(SimpleStablecoin.InsufficientCollateral.selector);
        stablecoin.withdrawCollateral(2 ether);
        vm.stopPrank();
    }

    function test_WithdrawCollateral_EmitsEvent() public {
        vm.startPrank(alice);
        stablecoin.depositCollateral{value: 2 ether}();

        vm.expectEmit(true, false, false, true);
        emit SimpleStablecoin.CollateralWithdrawn(alice, 1 ether);

        stablecoin.withdrawCollateral(1 ether);
        vm.stopPrank();
    }

    // =========================================================================
    // Liquidation Tests
    // =========================================================================

    function test_Liquidation_Success() public {
        // Alice opens a CDP
        vm.startPrank(alice);
        stablecoin.depositCollateral{value: 1 ether}();
        stablecoin.mintStablecoin(2000e18); // 150% ratio at $3000
        vm.stopPrank();

        // Give liquidator some sUSD to repay
        _mintStablecoinFor(liquidator, 2000e18);

        // Price drops to $2000 -> ratio = 2000/2000*10000 = 10000 (100%) < 150%
        oracle.setPrice(2000e8);

        assertFalse(stablecoin.isPositionHealthy(alice));

        uint256 liquidatorEthBefore = liquidator.balance;

        vm.prank(liquidator);
        stablecoin.liquidate(alice);

        // Liquidator should have received collateral at discount
        uint256 liquidatorEthAfter = liquidator.balance;
        assertTrue(liquidatorEthAfter > liquidatorEthBefore);

        // Alice's debt should be 0
        (, uint256 debt) = stablecoin.cdps(alice);
        assertEq(debt, 0);

        // Liquidator's sUSD should be burned
        assertEq(stablecoin.balanceOf(liquidator), 0);
    }

    function test_Liquidation_CollateralWithDiscount() public {
        // Alice opens a CDP
        vm.startPrank(alice);
        stablecoin.depositCollateral{value: 1 ether}();
        stablecoin.mintStablecoin(2000e18); // 150% ratio at $3000
        vm.stopPrank();

        _mintStablecoinFor(liquidator, 2000e18);

        // Price drops to $2500 -> ratio = 2500/2000*10000 = 12500 (125%) < 150%
        oracle.setPrice(2500e8);

        uint256 liquidatorEthBefore = liquidator.balance;

        vm.prank(liquidator);
        stablecoin.liquidate(alice);

        uint256 liquidatorEthAfter = liquidator.balance;
        uint256 ethReceived = liquidatorEthAfter - liquidatorEthBefore;

        // Debt = 2000 sUSD, ETH price = $2500
        // Collateral to seize = 2000e18 * 1e8 / 2500e8 = 0.8 ETH
        // With 10% discount = 0.8 * 1.1 = 0.88 ETH
        assertEq(ethReceived, 0.88 ether);
    }

    function test_Liquidation_RevertsOnHealthyPosition() public {
        vm.startPrank(alice);
        stablecoin.depositCollateral{value: 1 ether}();
        stablecoin.mintStablecoin(1000e18); // 300% ratio
        vm.stopPrank();

        _mintStablecoinFor(liquidator, 1000e18);

        vm.prank(liquidator);
        vm.expectRevert(SimpleStablecoin.PositionHealthy.selector);
        stablecoin.liquidate(alice);
    }

    function test_Liquidation_RevertsOnNoDebt() public {
        vm.prank(alice);
        stablecoin.depositCollateral{value: 1 ether}();

        vm.prank(liquidator);
        vm.expectRevert(SimpleStablecoin.NoDebtToLiquidate.selector);
        stablecoin.liquidate(alice);
    }

    function test_Liquidation_EmitsEvent() public {
        vm.startPrank(alice);
        stablecoin.depositCollateral{value: 1 ether}();
        stablecoin.mintStablecoin(2000e18);
        vm.stopPrank();

        _mintStablecoinFor(liquidator, 2000e18);

        oracle.setPrice(2500e8);

        vm.expectEmit(true, true, false, true);
        emit SimpleStablecoin.Liquidated(liquidator, alice, 2000e18, 0.88 ether);

        vm.prank(liquidator);
        stablecoin.liquidate(alice);
    }

    function test_Liquidation_CapsAtAvailableCollateral() public {
        // Alice opens a CDP
        vm.startPrank(alice);
        stablecoin.depositCollateral{value: 1 ether}();
        stablecoin.mintStablecoin(2000e18);
        vm.stopPrank();

        _mintStablecoinFor(liquidator, 2000e18);

        // Price drops drastically -> collateral with discount exceeds available
        oracle.setPrice(1500e8);

        uint256 liquidatorEthBefore = liquidator.balance;

        vm.prank(liquidator);
        stablecoin.liquidate(alice);

        uint256 ethReceived = liquidator.balance - liquidatorEthBefore;

        // Collateral with discount would be > 1 ETH, so capped at 1 ETH
        assertEq(ethReceived, 1 ether);

        // Alice's remaining collateral should be 0
        (uint256 collateral,) = stablecoin.cdps(alice);
        assertEq(collateral, 0);
    }

    // =========================================================================
    // View Functions Tests
    // =========================================================================

    function test_GetCollateralRatio() public {
        vm.startPrank(alice);
        stablecoin.depositCollateral{value: 1 ether}();
        stablecoin.mintStablecoin(1000e18);
        vm.stopPrank();

        // 1 ETH = $3000, debt = $1000 -> ratio = 300% = 30000 BPS
        uint256 ratio = stablecoin.getCollateralRatio(alice);
        assertEq(ratio, 30000);
    }

    function test_GetCollateralRatio_NoDebt() public {
        vm.prank(alice);
        stablecoin.depositCollateral{value: 1 ether}();

        uint256 ratio = stablecoin.getCollateralRatio(alice);
        assertEq(ratio, type(uint256).max);
    }

    function test_IsPositionHealthy() public {
        vm.startPrank(alice);
        stablecoin.depositCollateral{value: 1 ether}();
        stablecoin.mintStablecoin(2000e18); // exactly 150%
        vm.stopPrank();

        assertTrue(stablecoin.isPositionHealthy(alice));

        // Price drops slightly
        oracle.setPrice(2999e8);
        assertFalse(stablecoin.isPositionHealthy(alice));
    }

    // =========================================================================
    // ERC-20 Tests
    // =========================================================================

    function test_Transfer() public {
        vm.startPrank(alice);
        stablecoin.depositCollateral{value: 1 ether}();
        stablecoin.mintStablecoin(1000e18);
        stablecoin.transfer(bob, 500e18);
        vm.stopPrank();

        assertEq(stablecoin.balanceOf(alice), 500e18);
        assertEq(stablecoin.balanceOf(bob), 500e18);
    }

    function test_TransferFrom() public {
        vm.startPrank(alice);
        stablecoin.depositCollateral{value: 1 ether}();
        stablecoin.mintStablecoin(1000e18);
        stablecoin.approve(bob, 500e18);
        vm.stopPrank();

        vm.prank(bob);
        stablecoin.transferFrom(alice, bob, 500e18);

        assertEq(stablecoin.balanceOf(alice), 500e18);
        assertEq(stablecoin.balanceOf(bob), 500e18);
        assertEq(stablecoin.allowance(alice, bob), 0);
    }

    function test_Transfer_RevertsOnInsufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert(SimpleStablecoin.InsufficientBalance.selector);
        stablecoin.transfer(bob, 1e18);
    }

    // =========================================================================
    // Integration / End-to-End Tests
    // =========================================================================

    function test_FullCDPLifecycle() public {
        // 1. Alice deposits collateral
        vm.startPrank(alice);
        stablecoin.depositCollateral{value: 2 ether}();

        // 2. Alice mints stablecoin
        stablecoin.mintStablecoin(3000e18); // ratio = 6000/3000 = 200%

        // 3. Alice uses stablecoin (transfers some)
        stablecoin.transfer(bob, 1000e18);

        // 4. Alice gets back some from bob (simulated)
        vm.stopPrank();
        vm.prank(bob);
        stablecoin.transfer(alice, 1000e18);

        // 5. Alice burns stablecoin and withdraws
        vm.startPrank(alice);
        stablecoin.burnStablecoin(3000e18);
        stablecoin.withdrawCollateral(2 ether);
        vm.stopPrank();

        (uint256 collateral, uint256 debt) = stablecoin.cdps(alice);
        assertEq(collateral, 0);
        assertEq(debt, 0);
        assertEq(stablecoin.balanceOf(alice), 0);
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    /// @dev Mint sUSD for an address by opening a CDP (for testing liquidation)
    function _mintStablecoinFor(address user, uint256 amount) internal {
        vm.startPrank(user);
        // Deposit enough collateral for 200% ratio
        uint256 ethPrice = uint256(oracle.getLatestPrice());
        uint256 collateralNeeded = (amount * 2 * 1e8) / ethPrice;
        stablecoin.depositCollateral{value: collateralNeeded}();
        stablecoin.mintStablecoin(amount);
        vm.stopPrank();
    }
}
