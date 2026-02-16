// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {MockERC20} from "../contracts/MockERC20.sol";
import {FlashLoanProvider} from "../contracts/FlashLoanProvider.sol";
import {FlashLoanBorrower} from "../contracts/FlashLoanBorrower.sol";

contract FlashLoanTest is Test {
    MockERC20 internal token;
    FlashLoanProvider internal provider;
    FlashLoanBorrower internal borrower;

    address internal liquidityProvider = makeAddr("liquidityProvider");
    address internal liquidityProvider2 = makeAddr("liquidityProvider2");
    address internal user = makeAddr("user");

    uint256 internal constant INITIAL_MINT = 1_000_000e18;
    uint256 internal constant DEPOSIT_AMOUNT = 100_000e18;
    uint256 internal constant LOAN_AMOUNT = 50_000e18;

    // -----------------------------------------------------------------------
    // Setup
    // -----------------------------------------------------------------------

    function setUp() public {
        // Deploy token and provider
        token = new MockERC20("Test Token", "TST");
        provider = new FlashLoanProvider(address(token));
        borrower = new FlashLoanBorrower(address(provider), address(token));

        // Mint tokens to liquidity providers
        token.mint(liquidityProvider, INITIAL_MINT);
        token.mint(liquidityProvider2, INITIAL_MINT);

        // Liquidity provider deposits into pool
        vm.startPrank(liquidityProvider);
        token.approve(address(provider), type(uint256).max);
        provider.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    // -----------------------------------------------------------------------
    // Deposit Tests
    // -----------------------------------------------------------------------

    function test_deposit_updatesBalanceAndEmitsEvent() public {
        uint256 depositAmt = 10_000e18;

        vm.startPrank(liquidityProvider2);
        token.approve(address(provider), depositAmt);

        vm.expectEmit(true, false, false, true);
        emit FlashLoanProvider.Deposit(liquidityProvider2, depositAmt);

        provider.deposit(depositAmt);
        vm.stopPrank();

        assertEq(provider.deposits(liquidityProvider2), depositAmt);
        assertEq(provider.poolBalance(), DEPOSIT_AMOUNT + depositAmt);
    }

    function test_deposit_revertsOnZeroAmount() public {
        vm.prank(liquidityProvider);
        vm.expectRevert(FlashLoanProvider.ZeroAmount.selector);
        provider.deposit(0);
    }

    // -----------------------------------------------------------------------
    // Withdraw Tests
    // -----------------------------------------------------------------------

    function test_withdraw_returnsTokensAndEmitsEvent() public {
        uint256 withdrawAmt = 20_000e18;
        uint256 balanceBefore = token.balanceOf(liquidityProvider);

        vm.startPrank(liquidityProvider);

        vm.expectEmit(true, false, false, true);
        emit FlashLoanProvider.Withdrawal(liquidityProvider, withdrawAmt);

        provider.withdraw(withdrawAmt);
        vm.stopPrank();

        assertEq(provider.deposits(liquidityProvider), DEPOSIT_AMOUNT - withdrawAmt);
        assertEq(token.balanceOf(liquidityProvider), balanceBefore + withdrawAmt);
    }

    function test_withdraw_revertsOnZeroAmount() public {
        vm.prank(liquidityProvider);
        vm.expectRevert(FlashLoanProvider.ZeroAmount.selector);
        provider.withdraw(0);
    }

    function test_withdraw_revertsOnInsufficientDeposit() public {
        vm.prank(liquidityProvider);
        vm.expectRevert(
            abi.encodeWithSelector(
                FlashLoanProvider.InsufficientDeposit.selector,
                DEPOSIT_AMOUNT,
                DEPOSIT_AMOUNT + 1
            )
        );
        provider.withdraw(DEPOSIT_AMOUNT + 1);
    }

    // -----------------------------------------------------------------------
    // Flash Loan: Successful Repayment
    // -----------------------------------------------------------------------

    function test_flashLoan_successfulBorrowAndRepay() public {
        uint256 fee = provider.calculateFee(LOAN_AMOUNT);

        // Mint fee tokens to borrower so it can repay principal + fee
        token.mint(address(borrower), fee);

        uint256 poolBalanceBefore = provider.poolBalance();

        vm.prank(user);

        vm.expectEmit(true, false, false, true);
        emit FlashLoanProvider.FlashLoan(address(borrower), LOAN_AMOUNT, fee);

        provider.flashLoan(address(borrower), LOAN_AMOUNT, "");

        // Pool balance should have increased by the fee
        assertEq(provider.poolBalance(), poolBalanceBefore + fee);
        assertEq(provider.totalFeesCollected(), fee);
    }

    // -----------------------------------------------------------------------
    // Flash Loan: Revert if Not Repaid
    // -----------------------------------------------------------------------

    function test_flashLoan_revertsIfNotRepaid() public {
        // Tell borrower not to repay
        borrower.setShouldRepay(false);

        uint256 fee = provider.calculateFee(LOAN_AMOUNT);
        uint256 expectedBalance = provider.poolBalance() + fee;

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                FlashLoanProvider.FlashLoanNotRepaid.selector,
                expectedBalance,
                DEPOSIT_AMOUNT - LOAN_AMOUNT // pool only has original - lent amount
            )
        );
        provider.flashLoan(address(borrower), LOAN_AMOUNT, "");
    }

    // -----------------------------------------------------------------------
    // Flash Loan: Insufficient Pool Liquidity
    // -----------------------------------------------------------------------

    function test_flashLoan_revertsOnInsufficientLiquidity() public {
        uint256 tooMuch = DEPOSIT_AMOUNT + 1;

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                FlashLoanProvider.InsufficientPoolLiquidity.selector,
                DEPOSIT_AMOUNT,
                tooMuch
            )
        );
        provider.flashLoan(address(borrower), tooMuch, "");
    }

    // -----------------------------------------------------------------------
    // Fee Calculation
    // -----------------------------------------------------------------------

    function test_feeCalculation_isCorrect() public {
        // 0.1% = 10 bps
        assertEq(provider.calculateFee(10_000e18), 10e18);       // 10,000 * 0.001 = 10
        assertEq(provider.calculateFee(1e18), 1e15);              // 1 * 0.001 = 0.001
        assertEq(provider.calculateFee(0), 0);                    // 0 * 0.001 = 0
        assertEq(provider.calculateFee(100_000e18), 100e18);      // 100,000 * 0.001 = 100
        assertEq(provider.calculateFee(1), 0);                    // rounds down
        assertEq(provider.calculateFee(10_000), 1);               // exactly 1 wei fee
    }

    // -----------------------------------------------------------------------
    // Multiple Flash Loans in Sequence
    // -----------------------------------------------------------------------

    function test_flashLoan_multipleInSequence() public {
        uint256 fee1 = provider.calculateFee(LOAN_AMOUNT);
        uint256 fee2 = provider.calculateFee(LOAN_AMOUNT);
        uint256 fee3 = provider.calculateFee(30_000e18);

        // Mint fee tokens for each loan
        token.mint(address(borrower), fee1 + fee2 + fee3);

        uint256 poolBalanceBefore = provider.poolBalance();

        // Flash loan 1
        vm.prank(user);
        provider.flashLoan(address(borrower), LOAN_AMOUNT, "");

        // Flash loan 2 (same amount)
        vm.prank(user);
        provider.flashLoan(address(borrower), LOAN_AMOUNT, "");

        // Flash loan 3 (different amount)
        vm.prank(user);
        provider.flashLoan(address(borrower), 30_000e18, "");

        // Verify cumulative fees
        uint256 totalFees = fee1 + fee2 + fee3;
        assertEq(provider.totalFeesCollected(), totalFees);
        assertEq(provider.poolBalance(), poolBalanceBefore + totalFees);
    }

    // -----------------------------------------------------------------------
    // Flash Loan: Zero Amount
    // -----------------------------------------------------------------------

    function test_flashLoan_revertsOnZeroAmount() public {
        vm.prank(user);
        vm.expectRevert(FlashLoanProvider.ZeroAmount.selector);
        provider.flashLoan(address(borrower), 0, "");
    }

    // -----------------------------------------------------------------------
    // Flash Loan via Borrower Convenience Function
    // -----------------------------------------------------------------------

    function test_flashLoan_viaBorrowerExecuteFunction() public {
        uint256 fee = provider.calculateFee(LOAN_AMOUNT);
        token.mint(address(borrower), fee);

        vm.prank(user);
        borrower.executeFlashLoan(LOAN_AMOUNT, "");

        assertEq(provider.totalFeesCollected(), fee);
    }
}
