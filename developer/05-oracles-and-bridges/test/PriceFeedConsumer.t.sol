// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/MockAggregatorV3.sol";
import "../contracts/PriceFeedConsumer.sol";

/// @title PriceFeedConsumerTest
/// @notice Tests completos del sistema de collateral + liquidation:
///         - Depositar collateral
///         - Borrowear dentro del LTV
///         - No borrowear por encima del LTV
///         - Price drop -> liquidacion
///         - Stale price reverts
///         - Price recovery -> no liquidatable
contract PriceFeedConsumerTest is Test {
    MockAggregatorV3 public mockFeed;
    PriceFeedConsumer public consumer;

    address public alice;
    address public bob;
    address public liquidator;

    // ETH/USD = $2000.00 con 8 decimales (formato Chainlink)
    int256 constant INITIAL_ETH_PRICE = 2000_00000000; // $2000 * 1e8
    uint8 constant FEED_DECIMALS = 8;

    // Cantidad de ETH que Alice deposita
    uint256 constant ALICE_DEPOSIT = 10 ether; // 10 ETH

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        liquidator = makeAddr("liquidator");

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        // Deploy mock price feed y consumer
        mockFeed = new MockAggregatorV3(INITIAL_ETH_PRICE, FEED_DECIMALS);
        consumer = new PriceFeedConsumer(address(mockFeed));
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    function _depositAsAlice() internal {
        vm.prank(alice);
        consumer.deposit{value: ALICE_DEPOSIT}();
    }

    /// @dev Calcula USD amount con 18 decimales
    function _usd(uint256 amount) internal pure returns (uint256) {
        return amount * 1e18;
    }

    // =========================================================================
    // Deposit tests
    // =========================================================================

    function test_Deposit() public {
        _depositAsAlice();

        (uint256 collateral, uint256 borrowed) = consumer.positions(alice);
        assertEq(collateral, ALICE_DEPOSIT, "Collateral should be 10 ETH");
        assertEq(borrowed, 0, "No borrow yet");
    }

    function test_DepositMultipleTimes() public {
        vm.startPrank(alice);
        consumer.deposit{value: 5 ether}();
        consumer.deposit{value: 5 ether}();
        vm.stopPrank();

        (uint256 collateral, ) = consumer.positions(alice);
        assertEq(collateral, 10 ether);
    }

    function test_DepositZeroReverts() public {
        vm.prank(alice);
        vm.expectRevert("Must send ETH");
        consumer.deposit{value: 0}();
    }

    function test_DepositEmitsEvent() public {
        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit PriceFeedConsumer.Deposit(alice, ALICE_DEPOSIT);
        consumer.deposit{value: ALICE_DEPOSIT}();
    }

    // =========================================================================
    // Price feed tests
    // =========================================================================

    function test_GetETHPrice() public view {
        uint256 price = consumer.getETHPrice();
        // $2000 con 18 decimales
        assertEq(price, 2000e18, "ETH price should be $2000");
    }

    function test_GetCollateralValueUSD() public {
        _depositAsAlice();

        uint256 value = consumer.getCollateralValueUSD(alice);
        // 10 ETH * $2000 = $20,000 con 18 decimales
        assertEq(value, 20_000e18, "Collateral value should be $20,000");
    }

    // =========================================================================
    // Borrow tests
    // =========================================================================

    function test_BorrowWithinLTV() public {
        _depositAsAlice();

        // 10 ETH * $2000 = $20,000 collateral
        // Max LTV 75% = $15,000
        // Borrowear $10,000 (dentro del limite)
        vm.prank(alice);
        consumer.borrow(_usd(10_000));

        (, uint256 borrowed) = consumer.positions(alice);
        assertEq(borrowed, _usd(10_000));
    }

    function test_BorrowExactlyMaxLTV() public {
        _depositAsAlice();

        // Max borrow = $20,000 * 75% = $15,000
        vm.prank(alice);
        consumer.borrow(_usd(15_000));

        (, uint256 borrowed) = consumer.positions(alice);
        assertEq(borrowed, _usd(15_000));
    }

    function test_BorrowAboveLTVReverts() public {
        _depositAsAlice();

        // Intentar borrowear $15,001 (por encima del limite)
        vm.prank(alice);
        vm.expectRevert("Exceeds max LTV");
        consumer.borrow(_usd(15_001));
    }

    function test_BorrowMultipleTimes() public {
        _depositAsAlice();

        vm.startPrank(alice);
        consumer.borrow(_usd(5_000));
        consumer.borrow(_usd(5_000));

        (, uint256 borrowed) = consumer.positions(alice);
        assertEq(borrowed, _usd(10_000));

        // Tercer borrow que excede LTV
        vm.expectRevert("Exceeds max LTV");
        consumer.borrow(_usd(6_000)); // total seria 16,000 > 15,000
        vm.stopPrank();
    }

    function test_BorrowWithNoCollateralReverts() public {
        vm.prank(bob);
        vm.expectRevert("No collateral");
        consumer.borrow(_usd(1_000));
    }

    function test_BorrowZeroReverts() public {
        _depositAsAlice();
        vm.prank(alice);
        vm.expectRevert("Must borrow something");
        consumer.borrow(0);
    }

    function test_GetMaxBorrow() public {
        _depositAsAlice();

        uint256 maxBorrow = consumer.getMaxBorrow(alice);
        assertEq(maxBorrow, _usd(15_000));

        // Despues de borrowear, el max borrow disponible disminuye
        vm.prank(alice);
        consumer.borrow(_usd(10_000));

        maxBorrow = consumer.getMaxBorrow(alice);
        assertEq(maxBorrow, _usd(5_000));
    }

    // =========================================================================
    // Repay tests
    // =========================================================================

    function test_Repay() public {
        _depositAsAlice();

        vm.startPrank(alice);
        consumer.borrow(_usd(10_000));
        consumer.repay(_usd(5_000));

        (, uint256 borrowed) = consumer.positions(alice);
        assertEq(borrowed, _usd(5_000));
        vm.stopPrank();
    }

    function test_RepayFull() public {
        _depositAsAlice();

        vm.startPrank(alice);
        consumer.borrow(_usd(10_000));
        consumer.repay(_usd(10_000));

        (, uint256 borrowed) = consumer.positions(alice);
        assertEq(borrowed, 0);
        vm.stopPrank();
    }

    function test_RepayMoreThanDebtReverts() public {
        _depositAsAlice();

        vm.startPrank(alice);
        consumer.borrow(_usd(10_000));

        vm.expectRevert("Repay exceeds debt");
        consumer.repay(_usd(10_001));
        vm.stopPrank();
    }

    function test_RepayWithNoDebtReverts() public {
        _depositAsAlice();
        vm.prank(alice);
        vm.expectRevert("No debt");
        consumer.repay(_usd(1_000));
    }

    // =========================================================================
    // Withdraw tests
    // =========================================================================

    function test_WithdrawCollateral() public {
        _depositAsAlice();

        uint256 balanceBefore = alice.balance;

        vm.prank(alice);
        consumer.withdraw(5 ether);

        (uint256 collateral, ) = consumer.positions(alice);
        assertEq(collateral, 5 ether);
        assertEq(alice.balance, balanceBefore + 5 ether);
    }

    function test_WithdrawAllCollateralNoBorrow() public {
        _depositAsAlice();

        vm.prank(alice);
        consumer.withdraw(ALICE_DEPOSIT);

        (uint256 collateral, ) = consumer.positions(alice);
        assertEq(collateral, 0);
    }

    function test_WithdrawWouldExceedLTVReverts() public {
        _depositAsAlice();

        vm.startPrank(alice);
        // Borrow $14,000 (dentro de max $15,000)
        consumer.borrow(_usd(14_000));

        // Intentar retirar 1 ETH ($2000) dejaria collateral en 9 ETH = $18,000
        // Max borrow para 9 ETH = $18,000 * 75% = $13,500 < $14,000
        vm.expectRevert("Would exceed LTV");
        consumer.withdraw(1 ether);
        vm.stopPrank();
    }

    function test_WithdrawInsufficientCollateralReverts() public {
        _depositAsAlice();

        vm.prank(alice);
        vm.expectRevert("Insufficient collateral");
        consumer.withdraw(11 ether);
    }

    // =========================================================================
    // Liquidation tests - Price drops
    // =========================================================================

    function test_PositionNotLiquidatableInitially() public {
        _depositAsAlice();
        vm.prank(alice);
        consumer.borrow(_usd(10_000));

        assertFalse(consumer.isLiquidatable(alice));
    }

    function test_PriceDropMakesPositionLiquidatable() public {
        _depositAsAlice();

        // Borrowear $14,000 (collateral value = $20,000, ratio = 142%)
        vm.prank(alice);
        consumer.borrow(_usd(14_000));

        // Precio cae de $2000 a $1400
        // Nuevo collateral value = 10 * $1400 = $14,000
        // Ratio = $14,000 / $14,000 = 100% < 110% -> LIQUIDATABLE
        mockFeed.updatePrice(1400_00000000);

        assertTrue(consumer.isLiquidatable(alice), "Position should be liquidatable");
    }

    function test_LiquidationWorks() public {
        _depositAsAlice();

        vm.prank(alice);
        consumer.borrow(_usd(14_000));

        // Precio cae
        mockFeed.updatePrice(1400_00000000);

        // Liquidador liquida la posicion
        uint256 liquidatorBalanceBefore = liquidator.balance;

        vm.prank(liquidator);
        consumer.liquidate(alice);

        // Liquidador recibe todo el collateral (10 ETH)
        assertEq(
            liquidator.balance,
            liquidatorBalanceBefore + ALICE_DEPOSIT,
            "Liquidator should receive all collateral"
        );

        // La posicion de Alice queda limpia
        (uint256 collateral, uint256 borrowed) = consumer.positions(alice);
        assertEq(collateral, 0, "Collateral should be 0");
        assertEq(borrowed, 0, "Debt should be 0");
    }

    function test_LiquidationEmitsEvent() public {
        _depositAsAlice();
        vm.prank(alice);
        consumer.borrow(_usd(14_000));
        mockFeed.updatePrice(1400_00000000);

        vm.prank(liquidator);
        vm.expectEmit(true, true, false, true);
        emit PriceFeedConsumer.Liquidate(liquidator, alice, ALICE_DEPOSIT, _usd(14_000));
        consumer.liquidate(alice);
    }

    function test_CannotLiquidateHealthyPosition() public {
        _depositAsAlice();
        vm.prank(alice);
        consumer.borrow(_usd(10_000));

        // Posicion sana: collateral $20,000, borrow $10,000, ratio 200%
        vm.prank(liquidator);
        vm.expectRevert("Position is healthy");
        consumer.liquidate(alice);
    }

    function test_CannotLiquidateNoDebt() public {
        _depositAsAlice();

        vm.prank(liquidator);
        vm.expectRevert("No debt to liquidate");
        consumer.liquidate(alice);
    }

    // =========================================================================
    // Price recovery - no longer liquidatable
    // =========================================================================

    function test_PriceRecoveryMakesPositionHealthy() public {
        _depositAsAlice();
        vm.prank(alice);
        consumer.borrow(_usd(14_000));

        // Precio cae -> liquidatable
        mockFeed.updatePrice(1400_00000000);
        assertTrue(consumer.isLiquidatable(alice));

        // Precio se recupera a $2000
        mockFeed.updatePrice(2000_00000000);
        assertFalse(
            consumer.isLiquidatable(alice),
            "Position should be healthy after price recovery"
        );

        // Liquidacion ya no es posible
        vm.prank(liquidator);
        vm.expectRevert("Position is healthy");
        consumer.liquidate(alice);
    }

    // =========================================================================
    // Stale price tests
    // =========================================================================

    function test_StalePriceReverts() public {
        _depositAsAlice();

        // Simular que el precio no se actualiza por 2 horas
        uint256 staleTimestamp = block.timestamp - 2 hours;
        mockFeed.updatePriceWithTimestamp(INITIAL_ETH_PRICE, staleTimestamp);

        // Cualquier operacion que lea el precio deberia revertir
        vm.prank(alice);
        vm.expectRevert("Stale price data");
        consumer.borrow(_usd(1_000));
    }

    function test_StalePriceRevertsOnGetETHPrice() public {
        uint256 staleTimestamp = block.timestamp - 2 hours;
        mockFeed.updatePriceWithTimestamp(INITIAL_ETH_PRICE, staleTimestamp);

        vm.expectRevert("Stale price data");
        consumer.getETHPrice();
    }

    function test_StalePriceRevertsOnLiquidation() public {
        _depositAsAlice();
        vm.prank(alice);
        consumer.borrow(_usd(14_000));

        // Precio cae pero el timestamp es stale
        uint256 staleTimestamp = block.timestamp - 2 hours;
        mockFeed.updatePriceWithTimestamp(1400_00000000, staleTimestamp);

        vm.prank(liquidator);
        vm.expectRevert("Stale price data");
        consumer.liquidate(alice);
    }

    function test_PriceAtExactStalenessLimitIsValid() public {
        // Precio actualizado hace exactamente 1 hora (en el limite)
        uint256 borderlineTimestamp = block.timestamp - 1 hours;
        mockFeed.updatePriceWithTimestamp(INITIAL_ETH_PRICE, borderlineTimestamp);

        // No deberia revertir (justo en el limite, <= MAX_STALENESS)
        uint256 price = consumer.getETHPrice();
        assertEq(price, 2000e18);
    }

    function test_PriceJustOverStalenessLimitReverts() public {
        // Precio actualizado hace 1 hora + 1 segundo
        uint256 justOverTimestamp = block.timestamp - 1 hours - 1;
        mockFeed.updatePriceWithTimestamp(INITIAL_ETH_PRICE, justOverTimestamp);

        vm.expectRevert("Stale price data");
        consumer.getETHPrice();
    }

    // =========================================================================
    // Edge cases
    // =========================================================================

    function test_NegativePriceReverts() public {
        mockFeed.updatePrice(-100_00000000); // precio negativo

        vm.expectRevert("Invalid price: non-positive");
        consumer.getETHPrice();
    }

    function test_ZeroPriceReverts() public {
        mockFeed.updatePrice(0);

        vm.expectRevert("Invalid price: non-positive");
        consumer.getETHPrice();
    }

    function test_MultipleUsersIndependent() public {
        _depositAsAlice();

        vm.prank(bob);
        consumer.deposit{value: 5 ether}();

        vm.prank(alice);
        consumer.borrow(_usd(10_000));

        vm.prank(bob);
        consumer.borrow(_usd(5_000));

        // Verificar independencia
        (uint256 aliceCol, uint256 aliceBor) = consumer.positions(alice);
        (uint256 bobCol, uint256 bobBor) = consumer.positions(bob);

        assertEq(aliceCol, 10 ether);
        assertEq(aliceBor, _usd(10_000));
        assertEq(bobCol, 5 ether);
        assertEq(bobBor, _usd(5_000));
    }

    function test_PriceDropLiquidatesOneNotOther() public {
        // Alice deposita 10 ETH, borrow $14,000 (alto apalancamiento)
        _depositAsAlice();
        vm.prank(alice);
        consumer.borrow(_usd(14_000));

        // Bob deposita 10 ETH, borrow $5,000 (bajo apalancamiento)
        vm.prank(bob);
        consumer.deposit{value: 10 ether}();
        vm.prank(bob);
        consumer.borrow(_usd(5_000));

        // Precio cae a $1400
        mockFeed.updatePrice(1400_00000000);

        // Alice es liquidatable (ratio = 100% < 110%)
        assertTrue(consumer.isLiquidatable(alice));

        // Bob NO es liquidatable (ratio = $14,000/$5,000 = 280%)
        assertFalse(consumer.isLiquidatable(bob));
    }
}
