// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/vulnerable/VulnerableDOS.sol";
import "../contracts/secure/SecurePullPayment.sol";

/// @title RevertingReceiver - Contrato que revierte al recibir ETH
/// @notice Simula un contrato malicioso que bloquea la funcion refundAll()
contract RevertingReceiver {
    // Siempre revierte al recibir ETH
    receive() external payable {
        revert("I refuse ETH");
    }
}

/// @title DOSAttackTest
/// @notice Tests que demuestran:
///         1. DoS en VulnerableDOS cuando un receptor revierte
///         2. SecurePullPayment funciona correctamente aunque un receptor sea malicioso
contract DOSAttackTest is Test {
    VulnerableDOS public vulnerableDOS;
    SecurePullPayment public securePull;
    RevertingReceiver public blocker;

    address public user1;
    address public user2;
    address public admin;

    uint256 constant REFUND_AMOUNT = 1 ether;

    function setUp() public {
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        admin = makeAddr("admin");

        vm.deal(admin, 10 ether);

        vulnerableDOS = new VulnerableDOS();
        securePull = new SecurePullPayment();
        blocker = new RevertingReceiver();

        // Registrar refunds en VulnerableDOS:
        // user1, blocker (malicioso), user2
        vm.startPrank(admin);
        vulnerableDOS.addRefund{value: REFUND_AMOUNT}(user1);
        vulnerableDOS.addRefund{value: REFUND_AMOUNT}(address(blocker));
        vulnerableDOS.addRefund{value: REFUND_AMOUNT}(user2);

        // Registrar refunds en SecurePullPayment
        securePull.addRefund{value: REFUND_AMOUNT}(user1);
        securePull.addRefund{value: REFUND_AMOUNT}(address(blocker));
        securePull.addRefund{value: REFUND_AMOUNT}(user2);
        vm.stopPrank();
    }

    // =========================================================================
    // Tests contra VulnerableDOS
    // =========================================================================

    function test_VulnerableDOS_RefundsRegistered() public view {
        assertEq(vulnerableDOS.refundAmounts(user1), REFUND_AMOUNT);
        assertEq(vulnerableDOS.refundAmounts(address(blocker)), REFUND_AMOUNT);
        assertEq(vulnerableDOS.refundAmounts(user2), REFUND_AMOUNT);
        assertEq(address(vulnerableDOS).balance, 3 * REFUND_AMOUNT);
    }

    function test_VulnerableDOS_RefundAllBlocked() public {
        // refundAll() falla porque el RevertingReceiver bloquea todo
        vm.expectRevert("Refund failed");
        vulnerableDOS.refundAll();

        // NADIE recibe su refund - los fondos quedan atrapados
        assertEq(user1.balance, 0, "User1 should not have received refund");
        assertEq(user2.balance, 0, "User2 should not have received refund");
        assertEq(
            address(vulnerableDOS).balance,
            3 * REFUND_AMOUNT,
            "All funds should still be in contract"
        );
    }

    function test_VulnerableDOS_FundsTrappedForever() public {
        // Intentar refundAll multiples veces - siempre falla
        vm.expectRevert("Refund failed");
        vulnerableDOS.refundAll();

        vm.expectRevert("Refund failed");
        vulnerableDOS.refundAll();

        // Los fondos de user1 y user2 estan atrapados permanentemente
        // porque no hay otra forma de retirarlos
        assertEq(address(vulnerableDOS).balance, 3 * REFUND_AMOUNT);
    }

    // =========================================================================
    // Tests contra SecurePullPayment
    // =========================================================================

    function test_SecurePull_RefundsRegistered() public view {
        assertEq(securePull.pendingWithdrawals(user1), REFUND_AMOUNT);
        assertEq(securePull.pendingWithdrawals(address(blocker)), REFUND_AMOUNT);
        assertEq(securePull.pendingWithdrawals(user2), REFUND_AMOUNT);
    }

    function test_SecurePull_User1CanWithdraw() public {
        vm.prank(user1);
        securePull.withdrawRefund();

        assertEq(user1.balance, REFUND_AMOUNT, "User1 should receive refund");
        assertEq(securePull.pendingWithdrawals(user1), 0);
    }

    function test_SecurePull_User2CanWithdrawDespiteBlocker() public {
        // Incluso si el blocker no puede retirar, user2 puede
        vm.prank(user2);
        securePull.withdrawRefund();

        assertEq(user2.balance, REFUND_AMOUNT, "User2 should receive refund");
    }

    function test_SecurePull_BlockerCannotWithdrawButDoesNotAffectOthers() public {
        // El blocker no puede retirar (su receive revierte)
        vm.prank(address(blocker));
        vm.expectRevert("Withdraw failed");
        securePull.withdrawRefund();

        // Pero user1 y user2 SI pueden retirar sin problemas
        vm.prank(user1);
        securePull.withdrawRefund();
        assertEq(user1.balance, REFUND_AMOUNT);

        vm.prank(user2);
        securePull.withdrawRefund();
        assertEq(user2.balance, REFUND_AMOUNT);
    }

    function test_SecurePull_CannotWithdrawTwice() public {
        vm.startPrank(user1);
        securePull.withdrawRefund();

        vm.expectRevert("No pending refund");
        securePull.withdrawRefund();
        vm.stopPrank();
    }

    function test_SecurePull_CannotWithdrawWithNoPending() public {
        address nobody = makeAddr("nobody");
        vm.prank(nobody);
        vm.expectRevert("No pending refund");
        securePull.withdrawRefund();
    }
}
