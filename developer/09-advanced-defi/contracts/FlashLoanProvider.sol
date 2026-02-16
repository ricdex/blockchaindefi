// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "./interfaces/IERC20.sol";
import {IFlashLoanReceiver} from "./interfaces/IFlashLoanReceiver.sol";

/**
 * @title FlashLoanProvider
 * @notice A simple flash loan pool that holds ERC-20 tokens deposited by
 *         liquidity providers and offers uncollateralized flash loans.
 * @dev The flash loan must be repaid (principal + fee) within the same
 *      transaction. Fee is 0.1% (10 basis points) of the borrowed amount.
 */
contract FlashLoanProvider {
    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------

    error InsufficientPoolLiquidity(uint256 available, uint256 requested);
    error FlashLoanNotRepaid(uint256 expectedBalance, uint256 actualBalance);
    error ZeroAmount();
    error InsufficientDeposit(uint256 available, uint256 requested);
    error ReentrantCall();

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event Deposit(address indexed provider, uint256 amount);
    event Withdrawal(address indexed provider, uint256 amount);
    event FlashLoan(
        address indexed borrower,
        uint256 amount,
        uint256 fee
    );

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------

    /// @notice Flash loan fee: 0.1% expressed as basis points (10 / 10_000).
    uint256 public constant FEE_BPS = 10;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------

    /// @notice The ERC-20 token managed by this pool.
    IERC20 public immutable token;

    /// @notice Tracks individual deposits from liquidity providers.
    mapping(address => uint256) public deposits;

    /// @notice Total fees collected and available for distribution.
    uint256 public totalFeesCollected;

    /// @dev Reentrancy guard flag.
    bool private _locked;

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------

    modifier nonReentrant() {
        if (_locked) revert ReentrantCall();
        _locked = true;
        _;
        _locked = false;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    constructor(address _token) {
        token = IERC20(_token);
    }

    // -----------------------------------------------------------------------
    // Liquidity Provider functions
    // -----------------------------------------------------------------------

    /**
     * @notice Deposit tokens into the flash loan pool.
     * @param amount The number of tokens to deposit.
     * @dev Caller must have previously approved this contract.
     */
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        deposits[msg.sender] += amount;
        token.transferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount);
    }

    /**
     * @notice Withdraw previously deposited tokens from the pool.
     * @param amount The number of tokens to withdraw.
     */
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (deposits[msg.sender] < amount) {
            revert InsufficientDeposit(deposits[msg.sender], amount);
        }

        deposits[msg.sender] -= amount;
        token.transfer(msg.sender, amount);

        emit Withdrawal(msg.sender, amount);
    }

    // -----------------------------------------------------------------------
    // Flash Loan
    // -----------------------------------------------------------------------

    /**
     * @notice Execute a flash loan. Transfers `amount` tokens to `borrower`,
     *         calls `borrower.onFlashLoan(...)`, then verifies repayment.
     * @param borrower Address of the contract implementing IFlashLoanReceiver.
     * @param amount   Number of tokens to lend.
     * @param data     Arbitrary data forwarded to the borrower callback.
     */
    function flashLoan(
        address borrower,
        uint256 amount,
        bytes calldata data
    ) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        uint256 poolBalance = token.balanceOf(address(this));
        if (poolBalance < amount) {
            revert InsufficientPoolLiquidity(poolBalance, amount);
        }

        uint256 fee = calculateFee(amount);
        uint256 expectedBalance = poolBalance + fee;

        // 1. Transfer tokens to the borrower
        token.transfer(borrower, amount);

        // 2. Invoke the borrower callback
        IFlashLoanReceiver(borrower).onFlashLoan(msg.sender, amount, fee, data);

        // 3. Verify that tokens + fee have been returned
        uint256 actualBalance = token.balanceOf(address(this));
        if (actualBalance < expectedBalance) {
            revert FlashLoanNotRepaid(expectedBalance, actualBalance);
        }

        totalFeesCollected += fee;

        emit FlashLoan(borrower, amount, fee);
    }

    // -----------------------------------------------------------------------
    // View helpers
    // -----------------------------------------------------------------------

    /**
     * @notice Calculate the fee for a given flash loan amount.
     * @param amount The loan principal.
     * @return The fee in token units.
     */
    function calculateFee(uint256 amount) public pure returns (uint256) {
        return (amount * FEE_BPS) / BPS_DENOMINATOR;
    }

    /**
     * @notice Returns the current token balance held by the pool.
     */
    function poolBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}
