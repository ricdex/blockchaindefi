// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/SimpleAMM.sol";
import "../contracts/MockERC20.sol";

contract SimpleAMMTest is Test {
    SimpleAMM public amm;
    MockERC20 public tokenA;
    MockERC20 public tokenB;

    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    uint256 public constant INITIAL_LIQUIDITY_A = 1_000_000e18;
    uint256 public constant INITIAL_LIQUIDITY_B = 1_000_000e18;
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    function setUp() public {
        tokenA = new MockERC20("Token A", "TKA");
        tokenB = new MockERC20("Token B", "TKB");

        amm = new SimpleAMM(address(tokenA), address(tokenB));

        // Mintear tokens a alice y bob
        tokenA.mint(alice, 10_000_000e18);
        tokenB.mint(alice, 10_000_000e18);
        tokenA.mint(bob, 10_000_000e18);
        tokenB.mint(bob, 10_000_000e18);

        // Alice aprueba el AMM
        vm.startPrank(alice);
        tokenA.approve(address(amm), type(uint256).max);
        tokenB.approve(address(amm), type(uint256).max);
        vm.stopPrank();

        // Bob aprueba el AMM
        vm.startPrank(bob);
        tokenA.approve(address(amm), type(uint256).max);
        tokenB.approve(address(amm), type(uint256).max);
        vm.stopPrank();
    }

    // -------------------------------------------------------
    // Helper: agrega liquidez inicial
    // -------------------------------------------------------

    function _addInitialLiquidity() internal returns (uint256 lpTokens) {
        vm.prank(alice);
        lpTokens = amm.addLiquidity(INITIAL_LIQUIDITY_A, INITIAL_LIQUIDITY_B);
    }

    // -------------------------------------------------------
    // addLiquidity tests
    // -------------------------------------------------------

    function test_addLiquidity_initialDeposit() public {
        uint256 lpTokens = _addInitialLiquidity();

        // LP tokens = sqrt(1M * 1M) - MINIMUM_LIQUIDITY
        uint256 expectedLP = 1_000_000e18 - MINIMUM_LIQUIDITY;
        assertEq(lpTokens, expectedLP);
        assertEq(amm.balanceOf(alice), expectedLP);
    }

    function test_addLiquidity_updatesReserves() public {
        _addInitialLiquidity();

        (uint256 resA, uint256 resB) = amm.getReserves();
        assertEq(resA, INITIAL_LIQUIDITY_A);
        assertEq(resB, INITIAL_LIQUIDITY_B);
    }

    function test_addLiquidity_transfersTokens() public {
        uint256 aliceABefore = tokenA.balanceOf(alice);
        uint256 aliceBBefore = tokenB.balanceOf(alice);

        _addInitialLiquidity();

        assertEq(tokenA.balanceOf(alice), aliceABefore - INITIAL_LIQUIDITY_A);
        assertEq(tokenB.balanceOf(alice), aliceBBefore - INITIAL_LIQUIDITY_B);
        assertEq(tokenA.balanceOf(address(amm)), INITIAL_LIQUIDITY_A);
        assertEq(tokenB.balanceOf(address(amm)), INITIAL_LIQUIDITY_B);
    }

    function test_addLiquidity_burnsMinimumLiquidity() public {
        _addInitialLiquidity();

        // address(1) tiene los dead shares
        assertEq(amm.balanceOf(address(1)), MINIMUM_LIQUIDITY);
    }

    function test_addLiquidity_emitsEvent() public {
        uint256 expectedLP = 1_000_000e18 - MINIMUM_LIQUIDITY;

        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit SimpleAMM.AddLiquidity(alice, INITIAL_LIQUIDITY_A, INITIAL_LIQUIDITY_B, expectedLP);

        amm.addLiquidity(INITIAL_LIQUIDITY_A, INITIAL_LIQUIDITY_B);
    }

    function test_addLiquidity_subsequentDeposit() public {
        _addInitialLiquidity();

        // Bob agrega liquidez proporcional (10% del pool)
        uint256 addAmountA = 100_000e18;
        uint256 addAmountB = 100_000e18;

        vm.prank(bob);
        uint256 lpTokens = amm.addLiquidity(addAmountA, addAmountB);

        // Deberia recibir ~10% del total LP supply existente
        // totalSupply = 1_000_000e18, deposit = 10%
        // lpTokens = (100_000e18 * 1_000_000e18) / 1_000_000e18 = 100_000e18
        assertEq(lpTokens, 100_000e18);
        assertEq(amm.balanceOf(bob), lpTokens);
    }

    function test_addLiquidity_revertsWithZeroAmountA() public {
        vm.prank(alice);
        vm.expectRevert(SimpleAMM.ZeroAmount.selector);
        amm.addLiquidity(0, 1000e18);
    }

    function test_addLiquidity_revertsWithZeroAmountB() public {
        vm.prank(alice);
        vm.expectRevert(SimpleAMM.ZeroAmount.selector);
        amm.addLiquidity(1000e18, 0);
    }

    // -------------------------------------------------------
    // swap tests
    // -------------------------------------------------------

    function test_swap_tokenAForTokenB() public {
        _addInitialLiquidity();

        uint256 swapAmount = 10_000e18;

        // Calcular amountOut esperado
        // amountInWithFee = 10_000e18 * 997 = 9_970_000e18
        // amountOut = (1_000_000e18 * 9_970_000e18) / (1_000_000e18 * 1000 + 9_970_000e18)
        uint256 expectedOut = amm.getAmountOut(address(tokenA), swapAmount);

        uint256 bobBBefore = tokenB.balanceOf(bob);

        vm.prank(bob);
        uint256 amountOut = amm.swap(address(tokenA), swapAmount);

        assertEq(amountOut, expectedOut);
        assertEq(tokenB.balanceOf(bob), bobBBefore + amountOut);
    }

    function test_swap_tokenBForTokenA() public {
        _addInitialLiquidity();

        uint256 swapAmount = 5_000e18;
        uint256 expectedOut = amm.getAmountOut(address(tokenB), swapAmount);

        uint256 bobABefore = tokenA.balanceOf(bob);

        vm.prank(bob);
        uint256 amountOut = amm.swap(address(tokenB), swapAmount);

        assertEq(amountOut, expectedOut);
        assertEq(tokenA.balanceOf(bob), bobABefore + amountOut);
    }

    function test_swap_updatesReserves() public {
        _addInitialLiquidity();

        uint256 swapAmount = 10_000e18;

        vm.prank(bob);
        uint256 amountOut = amm.swap(address(tokenA), swapAmount);

        (uint256 resA, uint256 resB) = amm.getReserves();
        assertEq(resA, INITIAL_LIQUIDITY_A + swapAmount);
        assertEq(resB, INITIAL_LIQUIDITY_B - amountOut);
    }

    function test_swap_constantProductHoldsWithFee() public {
        _addInitialLiquidity();

        uint256 kBefore = INITIAL_LIQUIDITY_A * INITIAL_LIQUIDITY_B;

        uint256 swapAmount = 50_000e18;

        vm.prank(bob);
        amm.swap(address(tokenA), swapAmount);

        (uint256 resA, uint256 resB) = amm.getReserves();
        uint256 kAfter = resA * resB;

        // k deberia aumentar (o mantenerse) por el fee
        // Nunca disminuir
        assertGe(kAfter, kBefore);
    }

    function test_swap_feeCalculation() public {
        _addInitialLiquidity();

        uint256 swapAmount = 100_000e18; // 10% del pool

        vm.prank(bob);
        uint256 amountOut = amm.swap(address(tokenA), swapAmount);

        // Sin fee, amountOut seria:
        // (1M * 100K) / (1M + 100K) = 90909.09... e18
        uint256 amountOutNoFee = (INITIAL_LIQUIDITY_B * swapAmount) /
            (INITIAL_LIQUIDITY_A + swapAmount);

        // Con fee deberia ser menor
        assertLt(amountOut, amountOutNoFee);

        // La diferencia es aproximadamente 0.3%
        // amountOut ~= amountOutNoFee * 0.997 (aproximadamente, no exacto por la formula)
        assertGt(amountOut, (amountOutNoFee * 990) / 1000); // al menos 99% del sin-fee
    }

    function test_swap_emitsEvent() public {
        _addInitialLiquidity();

        uint256 swapAmount = 1_000e18;
        uint256 expectedOut = amm.getAmountOut(address(tokenA), swapAmount);

        vm.prank(bob);
        vm.expectEmit(true, true, false, true);
        emit SimpleAMM.Swap(bob, address(tokenA), swapAmount, expectedOut);

        amm.swap(address(tokenA), swapAmount);
    }

    function test_swap_revertsWithZeroAmount() public {
        _addInitialLiquidity();

        vm.prank(bob);
        vm.expectRevert(SimpleAMM.ZeroAmount.selector);
        amm.swap(address(tokenA), 0);
    }

    function test_swap_revertsWithInvalidToken() public {
        _addInitialLiquidity();

        vm.prank(bob);
        vm.expectRevert(SimpleAMM.InvalidToken.selector);
        amm.swap(address(0xDEAD), 1000e18);
    }

    function test_swap_priceImpactOnLargeSwap() public {
        _addInitialLiquidity();

        // Swap pequeno: 1000 tokens
        uint256 smallOut = amm.getAmountOut(address(tokenA), 1_000e18);
        uint256 smallPrice = (1_000e18 * 1e18) / smallOut; // precio por token

        // Swap grande: 500K tokens (50% del pool)
        uint256 largeOut = amm.getAmountOut(address(tokenA), 500_000e18);
        uint256 largePrice = (500_000e18 * 1e18) / largeOut; // precio por token

        // El swap grande deberia tener peor precio (mas caro)
        assertGt(largePrice, smallPrice);
    }

    // -------------------------------------------------------
    // removeLiquidity tests
    // -------------------------------------------------------

    function test_removeLiquidity_returnsProportionalTokens() public {
        uint256 lpTokens = _addInitialLiquidity();

        uint256 aliceABefore = tokenA.balanceOf(alice);
        uint256 aliceBBefore = tokenB.balanceOf(alice);

        vm.prank(alice);
        (uint256 amountA, uint256 amountB) = amm.removeLiquidity(lpTokens);

        // Deberia recibir casi todo (menos lo de MINIMUM_LIQUIDITY)
        assertEq(tokenA.balanceOf(alice), aliceABefore + amountA);
        assertEq(tokenB.balanceOf(alice), aliceBBefore + amountB);

        // Las cantidades deberian ser cercanas al deposito original
        // (menos la proporcion de MINIMUM_LIQUIDITY)
        assertGt(amountA, INITIAL_LIQUIDITY_A - 2000); // rounding tolerance
        assertGt(amountB, INITIAL_LIQUIDITY_B - 2000);
    }

    function test_removeLiquidity_updatesReserves() public {
        uint256 lpTokens = _addInitialLiquidity();

        vm.prank(alice);
        (uint256 amountA, uint256 amountB) = amm.removeLiquidity(lpTokens);

        (uint256 resA, uint256 resB) = amm.getReserves();
        assertEq(resA, INITIAL_LIQUIDITY_A - amountA);
        assertEq(resB, INITIAL_LIQUIDITY_B - amountB);
    }

    function test_removeLiquidity_burnsLPTokens() public {
        uint256 lpTokens = _addInitialLiquidity();

        uint256 totalBefore = amm.totalSupply();

        vm.prank(alice);
        amm.removeLiquidity(lpTokens);

        assertEq(amm.balanceOf(alice), 0);
        assertEq(amm.totalSupply(), totalBefore - lpTokens);
    }

    function test_removeLiquidity_emitsEvent() public {
        uint256 lpTokens = _addInitialLiquidity();

        // Calcular lo que deberia recibir
        uint256 expectedA = (lpTokens * INITIAL_LIQUIDITY_A) / amm.totalSupply();
        uint256 expectedB = (lpTokens * INITIAL_LIQUIDITY_B) / amm.totalSupply();

        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit SimpleAMM.RemoveLiquidity(alice, expectedA, expectedB, lpTokens);

        amm.removeLiquidity(lpTokens);
    }

    function test_removeLiquidity_partialWithdraw() public {
        uint256 lpTokens = _addInitialLiquidity();
        uint256 halfLP = lpTokens / 2;

        vm.prank(alice);
        (uint256 amountA, uint256 amountB) = amm.removeLiquidity(halfLP);

        // Deberia recibir ~mitad de las reservas
        // (proporcional a su share del total supply)
        assertApproxEqRel(amountA, INITIAL_LIQUIDITY_A / 2, 1e15); // 0.1% tolerance
        assertApproxEqRel(amountB, INITIAL_LIQUIDITY_B / 2, 1e15);
    }

    function test_removeLiquidity_revertsWithZeroAmount() public {
        _addInitialLiquidity();

        vm.prank(alice);
        vm.expectRevert(SimpleAMM.ZeroAmount.selector);
        amm.removeLiquidity(0);
    }

    function test_removeLiquidity_revertsIfInsufficientLP() public {
        _addInitialLiquidity();

        uint256 aliceLP = amm.balanceOf(alice);

        vm.prank(alice);
        vm.expectRevert(SimpleAMM.InsufficientLPTokens.selector);
        amm.removeLiquidity(aliceLP + 1);
    }

    // -------------------------------------------------------
    // removeLiquidity despues de swaps (LP gana fees)
    // -------------------------------------------------------

    function test_removeLiquidity_afterSwaps_LPEarnsFees() public {
        uint256 lpTokens = _addInitialLiquidity();

        // Bob hace varios swaps que generan fees
        vm.startPrank(bob);
        for (uint256 i = 0; i < 10; i++) {
            amm.swap(address(tokenA), 50_000e18);
            amm.swap(address(tokenB), 50_000e18);
        }
        vm.stopPrank();

        // Alice retira toda su liquidez
        vm.prank(alice);
        (uint256 amountA, uint256 amountB) = amm.removeLiquidity(lpTokens);

        // Debido a los fees acumulados, k aumento
        // Alice deberia recibir mas valor total que lo que deposito
        // (puede recibir menos de un token pero mas del otro, el valor total sube)
        (uint256 resA, uint256 resB) = amm.getReserves();

        // El k restante (solo MINIMUM_LIQUIDITY queda) deberia ser mayor que el k original
        // proporcional a MINIMUM_LIQUIDITY
        // Pero mas importante: amountA * amountB > initial proporcional
        uint256 totalProductReceived = amountA * amountB;
        uint256 totalProductDeposited = INITIAL_LIQUIDITY_A * INITIAL_LIQUIDITY_B;

        // Considerando la proporcion de LP tokens que tenia alice
        // El producto deberia ser >= al depositado (gracias a fees)
        assertGe(
            totalProductReceived,
            (totalProductDeposited * lpTokens * lpTokens) /
                (amm.totalSupply() + lpTokens) /
                (amm.totalSupply() + lpTokens)
        );

        // Verificacion simple: al menos uno de los amounts es >= al original proporcional
        // despues de muchos swaps con fee, el pool crece
        assertGt(resA + amountA, INITIAL_LIQUIDITY_A - 1);
    }

    // -------------------------------------------------------
    // View functions tests
    // -------------------------------------------------------

    function test_getPrice_initialPrice() public {
        _addInitialLiquidity();

        // Ratio 1:1, precio deberia ser ~1e18
        uint256 price = amm.getPrice();
        assertEq(price, 1e18);
    }

    function test_getPrice_afterSwap() public {
        _addInitialLiquidity();

        // Swap cambia el precio
        vm.prank(bob);
        amm.swap(address(tokenA), 100_000e18);

        uint256 price = amm.getPrice();

        // Despues de comprar tokenB con tokenA:
        // reserveA subio, reserveB bajo
        // precio de tokenA en tokenB deberia bajar (< 1e18)
        assertLt(price, 1e18);
    }

    function test_getPrice_zeroReserves() public view {
        // Sin liquidez, precio es 0
        uint256 price = amm.getPrice();
        assertEq(price, 0);
    }

    function test_getAmountOut_revertsWithZero() public {
        _addInitialLiquidity();

        vm.expectRevert(SimpleAMM.ZeroAmount.selector);
        amm.getAmountOut(address(tokenA), 0);
    }

    function test_getAmountOut_revertsWithInvalidToken() public {
        _addInitialLiquidity();

        vm.expectRevert(SimpleAMM.InvalidToken.selector);
        amm.getAmountOut(address(0xDEAD), 1000e18);
    }

    // -------------------------------------------------------
    // Integration: flujo completo
    // -------------------------------------------------------

    function test_fullFlow() public {
        // 1. Alice agrega liquidez
        vm.prank(alice);
        uint256 aliceLP = amm.addLiquidity(1_000_000e18, 1_000_000e18);

        // 2. Bob agrega liquidez
        vm.prank(bob);
        uint256 bobLP = amm.addLiquidity(500_000e18, 500_000e18);

        // 3. Alice hace un swap
        vm.prank(alice);
        uint256 swapOut = amm.swap(address(tokenA), 10_000e18);
        assertGt(swapOut, 0);

        // 4. Bob retira su liquidez
        vm.prank(bob);
        (uint256 bobAmountA, uint256 bobAmountB) = amm.removeLiquidity(bobLP);

        // Bob deberia recibir tokens (no necesariamente las mismas cantidades por el swap)
        assertGt(bobAmountA, 0);
        assertGt(bobAmountB, 0);

        // 5. Alice retira su liquidez
        vm.prank(alice);
        (uint256 aliceAmountA, uint256 aliceAmountB) = amm.removeLiquidity(aliceLP);

        assertGt(aliceAmountA, 0);
        assertGt(aliceAmountB, 0);

        // 6. Solo quedan las dead shares (MINIMUM_LIQUIDITY)
        assertEq(amm.totalSupply(), MINIMUM_LIQUIDITY);
    }
}
