// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/MultiSigWallet.sol";

/// @notice Contrato auxiliar que acepta ETH (para testear ejecucion)
contract Receiver {
    uint256 public receivedAmount;
    bytes public receivedData;

    receive() external payable {
        receivedAmount = msg.value;
    }

    fallback() external payable {
        receivedAmount = msg.value;
        receivedData = msg.data;
    }
}

/// @notice Contrato que rechaza ETH (para testear fallo de ejecucion)
contract Rejector {
    receive() external payable {
        revert("I reject ETH");
    }
}

contract MultiSigWalletTest is Test {
    MultiSigWallet public wallet;
    Receiver public receiver;
    Rejector public rejector;

    address public owner1 = address(0x1);
    address public owner2 = address(0x2);
    address public owner3 = address(0x3);
    address public nonOwner = address(0x99);

    address[] public owners;
    uint256 public constant REQUIRED = 2;

    function setUp() public {
        owners.push(owner1);
        owners.push(owner2);
        owners.push(owner3);

        wallet = new MultiSigWallet(owners, REQUIRED);
        receiver = new Receiver();
        rejector = new Rejector();

        // Fondear la wallet con 10 ETH
        vm.deal(address(wallet), 10 ether);
    }

    // -------------------------------------------------------
    // Constructor tests
    // -------------------------------------------------------

    function test_constructor_setsOwnersCorrectly() public view {
        address[] memory result = wallet.getOwners();
        assertEq(result.length, 3);
        assertEq(result[0], owner1);
        assertEq(result[1], owner2);
        assertEq(result[2], owner3);
    }

    function test_constructor_setsRequiredCorrectly() public view {
        assertEq(wallet.required(), REQUIRED);
    }

    function test_constructor_marksOwnersInMapping() public view {
        assertTrue(wallet.isOwner(owner1));
        assertTrue(wallet.isOwner(owner2));
        assertTrue(wallet.isOwner(owner3));
        assertFalse(wallet.isOwner(nonOwner));
    }

    function test_constructor_revertsWithNoOwners() public {
        address[] memory empty = new address[](0);
        vm.expectRevert(MultiSigWallet.NoOwners.selector);
        new MultiSigWallet(empty, 1);
    }

    function test_constructor_revertsWithZeroRequired() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                MultiSigWallet.InvalidRequiredCount.selector,
                0,
                3
            )
        );
        new MultiSigWallet(owners, 0);
    }

    function test_constructor_revertsWhenRequiredExceedsOwners() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                MultiSigWallet.InvalidRequiredCount.selector,
                4,
                3
            )
        );
        new MultiSigWallet(owners, 4);
    }

    function test_constructor_revertsWithDuplicateOwner() public {
        address[] memory dupes = new address[](3);
        dupes[0] = owner1;
        dupes[1] = owner2;
        dupes[2] = owner1; // duplicado
        vm.expectRevert(
            abi.encodeWithSelector(MultiSigWallet.DuplicateOwner.selector, owner1)
        );
        new MultiSigWallet(dupes, 2);
    }

    function test_constructor_revertsWithZeroAddress() public {
        address[] memory withZero = new address[](2);
        withZero[0] = owner1;
        withZero[1] = address(0);
        vm.expectRevert(MultiSigWallet.InvalidOwnerAddress.selector);
        new MultiSigWallet(withZero, 1);
    }

    // -------------------------------------------------------
    // Deposit tests
    // -------------------------------------------------------

    function test_receive_acceptsETH() public {
        uint256 balanceBefore = address(wallet).balance;

        vm.deal(nonOwner, 1 ether);
        vm.prank(nonOwner);
        (bool success, ) = address(wallet).call{value: 1 ether}("");
        assertTrue(success);

        assertEq(address(wallet).balance, balanceBefore + 1 ether);
    }

    function test_receive_emitsDepositEvent() public {
        vm.deal(nonOwner, 1 ether);
        vm.prank(nonOwner);

        vm.expectEmit(true, false, false, true, address(wallet));
        emit MultiSigWallet.Deposit(nonOwner, 1 ether);

        (bool success, ) = address(wallet).call{value: 1 ether}("");
        assertTrue(success);
    }

    // -------------------------------------------------------
    // Submit tests
    // -------------------------------------------------------

    function test_submit_createsTransaction() public {
        vm.prank(owner1);
        wallet.submit(address(receiver), 1 ether, "");

        assertEq(wallet.getTransactionCount(), 1);

        (address to, uint256 value, , bool executed, uint256 confirmations) =
            wallet.getTransaction(0);

        assertEq(to, address(receiver));
        assertEq(value, 1 ether);
        assertFalse(executed);
        assertEq(confirmations, 0);
    }

    function test_submit_emitsEvent() public {
        vm.prank(owner1);

        vm.expectEmit(true, true, false, true, address(wallet));
        emit MultiSigWallet.TransactionSubmitted(0, address(receiver), 1 ether, "");

        wallet.submit(address(receiver), 1 ether, "");
    }

    function test_submit_revertsForNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(
            abi.encodeWithSelector(MultiSigWallet.NotOwner.selector, nonOwner)
        );
        wallet.submit(address(receiver), 1 ether, "");
    }

    // -------------------------------------------------------
    // Confirm tests
    // -------------------------------------------------------

    function _submitTx() internal returns (uint256) {
        vm.prank(owner1);
        wallet.submit(address(receiver), 1 ether, "");
        return 0;
    }

    function test_confirm_incrementsConfirmations() public {
        uint256 txId = _submitTx();

        vm.prank(owner1);
        wallet.confirm(txId);

        (, , , , uint256 confirmations) = wallet.getTransaction(txId);
        assertEq(confirmations, 1);
        assertTrue(wallet.confirmed(txId, owner1));
    }

    function test_confirm_emitsEvent() public {
        uint256 txId = _submitTx();

        vm.prank(owner1);
        vm.expectEmit(true, true, false, true, address(wallet));
        emit MultiSigWallet.TransactionConfirmed(txId, owner1);

        wallet.confirm(txId);
    }

    function test_confirm_revertsForNonOwner() public {
        uint256 txId = _submitTx();

        vm.prank(nonOwner);
        vm.expectRevert(
            abi.encodeWithSelector(MultiSigWallet.NotOwner.selector, nonOwner)
        );
        wallet.confirm(txId);
    }

    function test_confirm_revertsIfAlreadyConfirmed() public {
        uint256 txId = _submitTx();

        vm.prank(owner1);
        wallet.confirm(txId);

        vm.prank(owner1);
        vm.expectRevert(
            abi.encodeWithSelector(
                MultiSigWallet.TxAlreadyConfirmed.selector,
                txId,
                owner1
            )
        );
        wallet.confirm(txId);
    }

    function test_confirm_revertsForNonExistentTx() public {
        vm.prank(owner1);
        vm.expectRevert(
            abi.encodeWithSelector(MultiSigWallet.TxDoesNotExist.selector, 999)
        );
        wallet.confirm(999);
    }

    // -------------------------------------------------------
    // Execute tests
    // -------------------------------------------------------

    function _submitAndConfirm() internal returns (uint256) {
        uint256 txId = _submitTx();

        vm.prank(owner1);
        wallet.confirm(txId);

        vm.prank(owner2);
        wallet.confirm(txId);

        return txId;
    }

    function test_execute_transfersETH() public {
        uint256 txId = _submitAndConfirm();
        uint256 receiverBalBefore = address(receiver).balance;

        vm.prank(owner1);
        wallet.execute(txId);

        assertEq(address(receiver).balance, receiverBalBefore + 1 ether);
    }

    function test_execute_marksTxAsExecuted() public {
        uint256 txId = _submitAndConfirm();

        vm.prank(owner1);
        wallet.execute(txId);

        (, , , bool executed, ) = wallet.getTransaction(txId);
        assertTrue(executed);
    }

    function test_execute_emitsEvent() public {
        uint256 txId = _submitAndConfirm();

        vm.prank(owner1);
        vm.expectEmit(true, false, false, true, address(wallet));
        emit MultiSigWallet.TransactionExecuted(txId);

        wallet.execute(txId);
    }

    function test_execute_revertsWithoutEnoughConfirmations() public {
        uint256 txId = _submitTx();

        vm.prank(owner1);
        wallet.confirm(txId); // solo 1 de 2 requeridas

        vm.prank(owner1);
        vm.expectRevert(
            abi.encodeWithSelector(
                MultiSigWallet.NotEnoughConfirmations.selector,
                txId,
                1,
                REQUIRED
            )
        );
        wallet.execute(txId);
    }

    function test_execute_revertsIfAlreadyExecuted() public {
        uint256 txId = _submitAndConfirm();

        vm.prank(owner1);
        wallet.execute(txId);

        vm.prank(owner1);
        vm.expectRevert(
            abi.encodeWithSelector(MultiSigWallet.TxAlreadyExecuted.selector, txId)
        );
        wallet.execute(txId);
    }

    function test_execute_revertsIfCallFails() public {
        // Proponer enviar ETH al contrato que rechaza
        vm.prank(owner1);
        wallet.submit(address(rejector), 1 ether, "");

        uint256 txId = wallet.getTransactionCount() - 1;

        vm.prank(owner1);
        wallet.confirm(txId);
        vm.prank(owner2);
        wallet.confirm(txId);

        vm.prank(owner1);
        vm.expectRevert(
            abi.encodeWithSelector(MultiSigWallet.TxExecutionFailed.selector, txId)
        );
        wallet.execute(txId);
    }

    function test_execute_withCalldata() public {
        // Enviar ETH con calldata al receiver
        bytes memory data = abi.encodeWithSignature("nonExistentFunc()");

        vm.prank(owner1);
        wallet.submit(address(receiver), 0.5 ether, data);

        uint256 txId = wallet.getTransactionCount() - 1;

        vm.prank(owner1);
        wallet.confirm(txId);
        vm.prank(owner2);
        wallet.confirm(txId);

        vm.prank(owner1);
        wallet.execute(txId);

        assertEq(receiver.receivedAmount(), 0.5 ether);
    }

    // -------------------------------------------------------
    // Revoke tests
    // -------------------------------------------------------

    function test_revoke_decrementsConfirmations() public {
        uint256 txId = _submitTx();

        vm.prank(owner1);
        wallet.confirm(txId);

        vm.prank(owner1);
        wallet.revoke(txId);

        (, , , , uint256 confirmations) = wallet.getTransaction(txId);
        assertEq(confirmations, 0);
        assertFalse(wallet.confirmed(txId, owner1));
    }

    function test_revoke_emitsEvent() public {
        uint256 txId = _submitTx();

        vm.prank(owner1);
        wallet.confirm(txId);

        vm.prank(owner1);
        vm.expectEmit(true, true, false, true, address(wallet));
        emit MultiSigWallet.TransactionRevoked(txId, owner1);

        wallet.revoke(txId);
    }

    function test_revoke_revertsIfNotConfirmed() public {
        uint256 txId = _submitTx();

        vm.prank(owner1);
        vm.expectRevert(
            abi.encodeWithSelector(
                MultiSigWallet.TxNotConfirmed.selector,
                txId,
                owner1
            )
        );
        wallet.revoke(txId);
    }

    function test_revoke_preventsExecution() public {
        uint256 txId = _submitTx();

        // Dos owners confirman
        vm.prank(owner1);
        wallet.confirm(txId);
        vm.prank(owner2);
        wallet.confirm(txId);

        // Owner1 revoca
        vm.prank(owner1);
        wallet.revoke(txId);

        // Solo queda 1 confirmacion, no deberia ejecutarse
        vm.prank(owner2);
        vm.expectRevert(
            abi.encodeWithSelector(
                MultiSigWallet.NotEnoughConfirmations.selector,
                txId,
                1,
                REQUIRED
            )
        );
        wallet.execute(txId);
    }

    // -------------------------------------------------------
    // Integration: flujo completo
    // -------------------------------------------------------

    function test_fullFlow_submitConfirmExecute() public {
        // Owner1 propone enviar 2 ETH
        vm.prank(owner1);
        wallet.submit(address(receiver), 2 ether, "");

        uint256 txId = 0;

        // Owner1 y Owner3 confirman
        vm.prank(owner1);
        wallet.confirm(txId);
        vm.prank(owner3);
        wallet.confirm(txId);

        // Owner2 ejecuta
        uint256 receiverBefore = address(receiver).balance;
        vm.prank(owner2);
        wallet.execute(txId);

        assertEq(address(receiver).balance, receiverBefore + 2 ether);

        (, , , bool executed, ) = wallet.getTransaction(txId);
        assertTrue(executed);
    }

    function test_multipleTransactions() public {
        // Transaccion 0
        vm.prank(owner1);
        wallet.submit(address(receiver), 1 ether, "");

        // Transaccion 1
        vm.prank(owner2);
        wallet.submit(address(receiver), 2 ether, "");

        assertEq(wallet.getTransactionCount(), 2);

        // Confirmar y ejecutar tx 1 (la segunda)
        vm.prank(owner1);
        wallet.confirm(1);
        vm.prank(owner2);
        wallet.confirm(1);
        vm.prank(owner3);
        wallet.execute(1);

        (, , , bool executed0, ) = wallet.getTransaction(0);
        (, , , bool executed1, ) = wallet.getTransaction(1);

        assertFalse(executed0); // la primera no se ejecuto
        assertTrue(executed1);  // la segunda si
    }
}
