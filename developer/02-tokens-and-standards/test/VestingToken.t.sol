// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/VestingToken.sol";

contract VestingTokenTest is Test {
    VestingToken public token;

    address public deployer = address(this);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public charlie = address(0xC);

    uint256 public constant INITIAL_SUPPLY = 1_000_000; // 1M tokens
    uint256 public constant DECIMALS = 18;
    uint256 public constant TOTAL_SUPPLY = INITIAL_SUPPLY * 10 ** DECIMALS;

    function setUp() public {
        token = new VestingToken("VestToken", "VST", INITIAL_SUPPLY);
    }

    // -------------------------------------------------------
    // ERC-20: Metadata
    // -------------------------------------------------------

    function test_name() public view {
        assertEq(token.name(), "VestToken");
    }

    function test_symbol() public view {
        assertEq(token.symbol(), "VST");
    }

    function test_decimals() public view {
        assertEq(token.decimals(), 18);
    }

    // -------------------------------------------------------
    // ERC-20: Initial state
    // -------------------------------------------------------

    function test_totalSupply() public view {
        assertEq(token.totalSupply(), TOTAL_SUPPLY);
    }

    function test_deployerGetsAllTokens() public view {
        assertEq(token.balanceOf(deployer), TOTAL_SUPPLY);
    }

    // -------------------------------------------------------
    // ERC-20: transfer
    // -------------------------------------------------------

    function test_transfer_movesTokens() public {
        token.transfer(alice, 1000e18);

        assertEq(token.balanceOf(alice), 1000e18);
        assertEq(token.balanceOf(deployer), TOTAL_SUPPLY - 1000e18);
    }

    function test_transfer_emitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit VestingToken.Transfer(deployer, alice, 500e18);

        token.transfer(alice, 500e18);
    }

    function test_transfer_revertsOnInsufficientBalance() public {
        vm.prank(alice); // alice tiene 0 tokens
        vm.expectRevert(
            abi.encodeWithSelector(
                VestingToken.InsufficientBalance.selector,
                0,
                100e18
            )
        );
        token.transfer(bob, 100e18);
    }

    function test_transfer_revertsToZeroAddress() public {
        vm.expectRevert(VestingToken.ZeroAddress.selector);
        token.transfer(address(0), 100e18);
    }

    // -------------------------------------------------------
    // ERC-20: approve / allowance
    // -------------------------------------------------------

    function test_approve_setsAllowance() public {
        token.approve(alice, 500e18);
        assertEq(token.allowance(deployer, alice), 500e18);
    }

    function test_approve_emitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit VestingToken.Approval(deployer, alice, 500e18);

        token.approve(alice, 500e18);
    }

    function test_approve_canOverwrite() public {
        token.approve(alice, 500e18);
        token.approve(alice, 200e18);
        assertEq(token.allowance(deployer, alice), 200e18);
    }

    // -------------------------------------------------------
    // ERC-20: transferFrom
    // -------------------------------------------------------

    function test_transferFrom_movesTokens() public {
        token.approve(alice, 300e18);

        vm.prank(alice);
        token.transferFrom(deployer, bob, 200e18);

        assertEq(token.balanceOf(bob), 200e18);
        assertEq(token.allowance(deployer, alice), 100e18); // 300 - 200
    }

    function test_transferFrom_revertsOnInsufficientAllowance() public {
        token.approve(alice, 100e18);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                VestingToken.InsufficientAllowance.selector,
                100e18,
                200e18
            )
        );
        token.transferFrom(deployer, bob, 200e18);
    }

    function test_transferFrom_unlimitedAllowanceNotDecreased() public {
        token.approve(alice, type(uint256).max);

        vm.prank(alice);
        token.transferFrom(deployer, bob, 100e18);

        // Unlimited allowance no se decrementa
        assertEq(token.allowance(deployer, alice), type(uint256).max);
    }

    // -------------------------------------------------------
    // Vesting: createVesting
    // -------------------------------------------------------

    uint256 constant VESTING_AMOUNT = 100_000e18;
    uint256 constant VESTING_DURATION = 365 days;
    uint256 constant CLIFF_DURATION = 90 days;

    function _createDefaultVesting(address beneficiary) internal {
        token.createVesting(
            beneficiary,
            VESTING_AMOUNT,
            block.timestamp,
            VESTING_DURATION,
            CLIFF_DURATION
        );
    }

    function test_createVesting_storesSchedule() public {
        uint256 start = block.timestamp;
        _createDefaultVesting(alice);

        (
            uint256 totalAmount,
            uint256 released,
            uint256 startTime,
            uint256 duration,
            uint256 cliffDuration
        ) = token.vestingSchedules(alice);

        assertEq(totalAmount, VESTING_AMOUNT);
        assertEq(released, 0);
        assertEq(startTime, start);
        assertEq(duration, VESTING_DURATION);
        assertEq(cliffDuration, CLIFF_DURATION);
    }

    function test_createVesting_transfersTokensToContract() public {
        uint256 balBefore = token.balanceOf(deployer);
        _createDefaultVesting(alice);

        assertEq(token.balanceOf(deployer), balBefore - VESTING_AMOUNT);
        assertEq(token.balanceOf(address(token)), VESTING_AMOUNT);
    }

    function test_createVesting_emitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit VestingToken.VestingCreated(
            alice,
            VESTING_AMOUNT,
            block.timestamp,
            VESTING_DURATION,
            CLIFF_DURATION
        );

        _createDefaultVesting(alice);
    }

    function test_createVesting_revertsForNonOwner() public {
        vm.prank(alice);
        vm.expectRevert(VestingToken.NotOwner.selector);
        token.createVesting(bob, VESTING_AMOUNT, block.timestamp, VESTING_DURATION, CLIFF_DURATION);
    }

    function test_createVesting_revertsForZeroAddress() public {
        vm.expectRevert(VestingToken.ZeroAddress.selector);
        token.createVesting(address(0), VESTING_AMOUNT, block.timestamp, VESTING_DURATION, CLIFF_DURATION);
    }

    function test_createVesting_revertsForZeroAmount() public {
        vm.expectRevert(VestingToken.InvalidVestingParams.selector);
        token.createVesting(alice, 0, block.timestamp, VESTING_DURATION, CLIFF_DURATION);
    }

    function test_createVesting_revertsForZeroDuration() public {
        vm.expectRevert(VestingToken.InvalidVestingParams.selector);
        token.createVesting(alice, VESTING_AMOUNT, block.timestamp, 0, 0);
    }

    function test_createVesting_revertsIfCliffExceedsDuration() public {
        vm.expectRevert(VestingToken.InvalidVestingParams.selector);
        token.createVesting(alice, VESTING_AMOUNT, block.timestamp, 100 days, 200 days);
    }

    function test_createVesting_revertsIfAlreadyExists() public {
        _createDefaultVesting(alice);

        vm.expectRevert(
            abi.encodeWithSelector(VestingToken.VestingAlreadyExists.selector, alice)
        );
        _createDefaultVesting(alice);
    }

    // -------------------------------------------------------
    // Vesting: vestedAmount y releasableAmount
    // -------------------------------------------------------

    function test_vestedAmount_zeroBeforeCliff() public {
        _createDefaultVesting(alice);

        // Avanzar 89 dias (cliff es 90)
        vm.warp(block.timestamp + 89 days);

        assertEq(token.vestedAmount(alice), 0);
        assertEq(token.releasableAmount(alice), 0);
    }

    function test_vestedAmount_partialAfterCliff() public {
        uint256 start = block.timestamp;
        _createDefaultVesting(alice);

        // Avanzar exactamente al cliff (90 dias)
        vm.warp(start + CLIFF_DURATION);

        uint256 expected = (VESTING_AMOUNT * CLIFF_DURATION) / VESTING_DURATION;
        assertEq(token.vestedAmount(alice), expected);
    }

    function test_vestedAmount_linearDuringVesting() public {
        uint256 start = block.timestamp;
        _createDefaultVesting(alice);

        // Avanzar a la mitad del vesting (182.5 dias)
        vm.warp(start + VESTING_DURATION / 2);

        uint256 expected = VESTING_AMOUNT / 2;
        assertEq(token.vestedAmount(alice), expected);
    }

    function test_vestedAmount_allAfterDuration() public {
        uint256 start = block.timestamp;
        _createDefaultVesting(alice);

        // Avanzar despues del vesting completo
        vm.warp(start + VESTING_DURATION + 1);

        assertEq(token.vestedAmount(alice), VESTING_AMOUNT);
    }

    function test_vestedAmount_zeroForNonBeneficiary() public view {
        assertEq(token.vestedAmount(bob), 0);
    }

    // -------------------------------------------------------
    // Vesting: release
    // -------------------------------------------------------

    function test_release_transfersVestedTokens() public {
        uint256 start = block.timestamp;
        _createDefaultVesting(alice);

        // Avanzar a la mitad del vesting
        vm.warp(start + VESTING_DURATION / 2);

        uint256 expectedRelease = VESTING_AMOUNT / 2;

        token.release(alice);

        assertEq(token.balanceOf(alice), expectedRelease);
    }

    function test_release_emitsEvent() public {
        uint256 start = block.timestamp;
        _createDefaultVesting(alice);

        vm.warp(start + VESTING_DURATION / 2);

        uint256 expectedRelease = VESTING_AMOUNT / 2;

        vm.expectEmit(true, false, false, true);
        emit VestingToken.TokensReleased(alice, expectedRelease);

        token.release(alice);
    }

    function test_release_updatesReleasedAmount() public {
        uint256 start = block.timestamp;
        _createDefaultVesting(alice);

        vm.warp(start + VESTING_DURATION / 2);
        token.release(alice);

        (, uint256 released, , , ) = token.vestingSchedules(alice);
        assertEq(released, VESTING_AMOUNT / 2);
    }

    function test_release_revertsBeforeCliff() public {
        _createDefaultVesting(alice);

        // Avanzar solo 30 dias (cliff es 90)
        vm.warp(block.timestamp + 30 days);

        vm.expectRevert(
            abi.encodeWithSelector(VestingToken.NothingToRelease.selector, alice)
        );
        token.release(alice);
    }

    function test_release_revertsIfNothingNew() public {
        uint256 start = block.timestamp;
        _createDefaultVesting(alice);

        vm.warp(start + VESTING_DURATION / 2);
        token.release(alice); // libera la mitad

        // Sin avanzar el tiempo, no hay mas tokens
        vm.expectRevert(
            abi.encodeWithSelector(VestingToken.NothingToRelease.selector, alice)
        );
        token.release(alice);
    }

    function test_release_revertsForNonBeneficiary() public {
        vm.expectRevert(
            abi.encodeWithSelector(VestingToken.NoVestingSchedule.selector, bob)
        );
        token.release(bob);
    }

    function test_release_multipleClaimsOverTime() public {
        uint256 start = block.timestamp;
        _createDefaultVesting(alice);

        // Primer claim: 25% del vesting
        vm.warp(start + VESTING_DURATION / 4);
        token.release(alice);
        uint256 firstClaim = token.balanceOf(alice);
        assertEq(firstClaim, VESTING_AMOUNT / 4);

        // Segundo claim: avanzar a 75%
        vm.warp(start + (VESTING_DURATION * 3) / 4);
        token.release(alice);
        uint256 secondTotal = token.balanceOf(alice);
        assertEq(secondTotal, (VESTING_AMOUNT * 3) / 4);

        // Tercer claim: despues del final
        vm.warp(start + VESTING_DURATION + 1);
        token.release(alice);
        assertEq(token.balanceOf(alice), VESTING_AMOUNT);
    }

    // -------------------------------------------------------
    // Vesting: multiples beneficiarios
    // -------------------------------------------------------

    function test_multipleBeneficiaries() public {
        uint256 start = block.timestamp;
        uint256 aliceAmount = 50_000e18;
        uint256 bobAmount = 30_000e18;

        token.createVesting(alice, aliceAmount, start, 200 days, 50 days);
        token.createVesting(bob, bobAmount, start, 300 days, 100 days);

        // Avanzar 100 dias: alice esta al 50%, bob esta exactamente en cliff
        vm.warp(start + 100 days);

        // Alice: 100/200 = 50%
        assertEq(token.vestedAmount(alice), aliceAmount / 2);

        // Bob: 100/300 = 33.33%
        assertEq(token.vestedAmount(bob), (bobAmount * 100) / 300);

        // Ambos reclaman
        token.release(alice);
        token.release(bob);

        assertEq(token.balanceOf(alice), aliceAmount / 2);
        assertEq(token.balanceOf(bob), (bobAmount * 100) / 300);
    }

    // -------------------------------------------------------
    // Vesting: vesting sin cliff (cliff = 0)
    // -------------------------------------------------------

    function test_vestingWithoutCliff() public {
        uint256 start = block.timestamp;
        token.createVesting(alice, VESTING_AMOUNT, start, VESTING_DURATION, 0);

        // Inmediatamente despues, deberia haber algo vesteado
        vm.warp(start + 1 days);

        uint256 vested = token.vestedAmount(alice);
        assertGt(vested, 0); // ya hay tokens vesteados
        assertLt(vested, VESTING_AMOUNT); // pero no todos
    }

    // -------------------------------------------------------
    // Edge case: anyone can call release
    // -------------------------------------------------------

    function test_anyoneCanCallRelease() public {
        uint256 start = block.timestamp;
        _createDefaultVesting(alice);

        vm.warp(start + VESTING_DURATION);

        // Charlie (no es ni owner ni beneficiary) llama release para alice
        vm.prank(charlie);
        token.release(alice);

        // Los tokens llegan a alice, no a charlie
        assertEq(token.balanceOf(alice), VESTING_AMOUNT);
        assertEq(token.balanceOf(charlie), 0);
    }
}
