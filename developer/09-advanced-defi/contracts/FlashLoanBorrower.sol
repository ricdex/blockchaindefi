// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "./interfaces/IERC20.sol";
import {IFlashLoanReceiver} from "./interfaces/IFlashLoanReceiver.sol";

/**
 * @title FlashLoanBorrower
 * @notice Example borrower contract that takes a flash loan and simulates
 *         an arbitrage operation for testing purposes.
 *
 * @dev In a real arbitrage scenario the onFlashLoan callback would:
 *   1. Receive the borrowed tokens
 *   2. Swap tokens on DEX A at a lower price (buy cheap)
 *   3. Swap the result on DEX B at a higher price (sell expensive)
 *   4. Approve the provider to pull back (amount + fee)
 *
 *   Profit = sellPrice - buyPrice - fee - gasCost
 *
 *   Because on-chain arbitrage must be atomic, a flash loan is ideal:
 *   if the price difference doesn't cover the fee + gas, the transaction
 *   simply reverts and the borrower loses nothing except gas.
 *
 *   This test implementation receives extra tokens (simulating profit)
 *   via a pre-funded balance or mint, then repays the loan + fee.
 */
contract FlashLoanBorrower is IFlashLoanReceiver {
    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------

    error UnauthorizedCaller(address caller);

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------

    /// @notice The flash loan provider this borrower interacts with.
    address public immutable provider;

    /// @notice The ERC-20 token used for the flash loan.
    IERC20 public immutable token;

    /// @notice When true, the borrower will intentionally NOT repay (for testing reverts).
    bool public shouldRepay;

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    constructor(address _provider, address _token) {
        provider = _provider;
        token = IERC20(_token);
        shouldRepay = true;
    }

    // -----------------------------------------------------------------------
    // Configuration (for testing)
    // -----------------------------------------------------------------------

    /**
     * @notice Toggle whether the borrower will repay the flash loan.
     * @param _shouldRepay If false, the borrower skips repayment (triggers revert in provider).
     */
    function setShouldRepay(bool _shouldRepay) external {
        shouldRepay = _shouldRepay;
    }

    // -----------------------------------------------------------------------
    // Flash Loan Callback
    // -----------------------------------------------------------------------

    /**
     * @notice Callback invoked by the FlashLoanProvider after transferring
     *         the loan amount to this contract.
     * @param initiator The address that called flashLoan on the provider.
     * @param amount    The borrowed amount.
     * @param fee       The fee to be repaid on top of the principal.
     * @param data      Arbitrary data (unused in this example).
     */
    function onFlashLoan(
        address initiator,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override {
        if (msg.sender != provider) revert UnauthorizedCaller(msg.sender);

        // Suppress unused variable warnings
        (initiator, data);

        // -----------------------------------------------------------------
        // Simulated arbitrage logic
        // -----------------------------------------------------------------
        // In a real scenario, this is where you would:
        //   - Swap on DEX A (buy low)
        //   - Swap on DEX B (sell high)
        //   - The profit covers the fee
        //
        // For testing, this contract must already hold enough extra tokens
        // to cover the fee. The test setup mints (amount + fee) to this
        // contract or ensures a surplus exists.
        // -----------------------------------------------------------------

        if (shouldRepay) {
            // Repay principal + fee to the provider
            uint256 repaymentAmount = amount + fee;
            token.transfer(provider, repaymentAmount);
        }
        // If shouldRepay is false, we intentionally do not repay,
        // which will cause the provider to revert the entire transaction.
    }

    // -----------------------------------------------------------------------
    // Initiate Flash Loan
    // -----------------------------------------------------------------------

    /**
     * @notice Convenience function to request a flash loan from the provider.
     * @param amount The number of tokens to borrow.
     * @param data   Arbitrary data forwarded to onFlashLoan.
     */
    function executeFlashLoan(uint256 amount, bytes calldata data) external {
        // We use a low-level call to the provider because we only have the
        // interface via the provider address. In production you'd use a
        // typed interface.
        (bool success, bytes memory returnData) = provider.call(
            abi.encodeWithSignature(
                "flashLoan(address,uint256,bytes)",
                address(this),
                amount,
                data
            )
        );
        if (!success) {
            // Bubble up the revert reason
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }
    }
}
