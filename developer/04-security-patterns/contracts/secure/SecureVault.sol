// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SecureVault - Vault seguro con CEI pattern y ReentrancyGuard
/// @notice Implementa dos capas de proteccion contra reentrancy:
///         1. Patron CEI (Checks-Effects-Interactions)
///         2. ReentrancyGuard modifier (mutex lock)
///
/// @dev El ReentrancyGuard esta implementado inline (sin OpenZeppelin)
///      para fines educativos. En produccion se recomienda usar
///      la implementacion de OpenZeppelin que esta auditada.
contract SecureVault {
    // =========================================================================
    // ReentrancyGuard implementado desde cero
    // =========================================================================

    /// @dev Usamos uint256 en vez de bool porque cambiar de 1->2 es mas barato
    ///      en gas que cambiar de 0->1 (EIP-2200: SSTORE de nonzero a nonzero).
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    /// @dev Modifier que previene reentrancy.
    ///      Si _status es ENTERED, significa que ya estamos dentro de una
    ///      funcion protegida, y cualquier re-entrada sera revertida.
    modifier nonReentrant() {
        // CHECK: verificar que no estamos en una llamada reentrante
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");

        // EFFECT: marcar como entered ANTES de ejecutar el cuerpo
        _status = ENTERED;

        // Ejecutar el cuerpo de la funcion
        _;

        // CLEANUP: restaurar el estado despues de la ejecucion
        _status = NOT_ENTERED;
    }

    // =========================================================================
    // Logica del Vault
    // =========================================================================

    mapping(address => uint256) public balances;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor() {
        _status = NOT_ENTERED;
    }

    /// @notice Deposita ETH en el vault
    function deposit() external payable {
        require(msg.value > 0, "Must send ETH");
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice Retira todo el ETH depositado de forma segura
    /// @dev Usa el patron CEI (Checks-Effects-Interactions):
    ///      1. CHECK: verifica que el usuario tiene balance
    ///      2. EFFECT: pone el balance a cero ANTES de enviar ETH
    ///      3. INTERACTION: envia ETH al final
    ///      Ademas usa nonReentrant como segunda capa de proteccion.
    function withdraw() external nonReentrant {
        // 1. CHECKS: validar precondiciones
        uint256 balance = balances[msg.sender];
        require(balance > 0, "No balance");

        // 2. EFFECTS: actualizar estado ANTES de la llamada externa
        //    Incluso si un atacante logra re-entrar (imposible con nonReentrant),
        //    el balance ya es 0, asi que no podria retirar nada.
        balances[msg.sender] = 0;

        // 3. INTERACTIONS: llamada externa al final
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Transfer failed");

        emit Withdraw(msg.sender, balance);
    }

    /// @notice Retorna el balance total del vault
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
