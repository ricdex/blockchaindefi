// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title IFlashLoanReceiver
 * @notice Interface that borrowers must implement to receive flash loans
 *         from the FlashLoanProvider.
 */
interface IFlashLoanReceiver {
    /**
     * @notice Called by the FlashLoanProvider after transferring the loan amount.
     * @param initiator The address that initiated the flash loan.
     * @param amount    The number of tokens borrowed.
     * @param fee       The fee that must be paid on top of the principal.
     * @param data      Arbitrary data forwarded from the flash loan call.
     */
    function onFlashLoan(
        address initiator,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external;
}
