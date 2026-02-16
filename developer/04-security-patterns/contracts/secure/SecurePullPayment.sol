// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SecurePullPayment - Patron pull payment seguro contra DoS
/// @notice En vez de enviar ETH a todos los usuarios en un loop (push),
///         cada usuario retira su propio ETH individualmente (pull).
///
///         Esto previene DoS porque:
///         - Si un usuario es un contrato que revierte, solo se afecta a si mismo
///         - Los demas usuarios pueden retirar sin problemas
///         - No hay loops que puedan fallar parcialmente
contract SecurePullPayment {
    mapping(address => uint256) public pendingWithdrawals;

    event RefundAdded(address indexed addr, uint256 amount);
    event RefundWithdrawn(address indexed addr, uint256 amount);

    /// @notice Registra un refund pendiente para una direccion
    /// @param _addr Direccion que podra retirar el refund
    /// @dev Solo registra el monto; NO envia ETH (patron pull)
    function addRefund(address _addr) external payable {
        require(msg.value > 0, "Must send ETH");
        require(_addr != address(0), "Invalid address");
        pendingWithdrawals[_addr] += msg.value;
        emit RefundAdded(_addr, msg.value);
    }

    /// @notice Permite a un usuario retirar su refund pendiente
    /// @dev Cada usuario retira individualmente. Si el retiro falla
    ///      (p.ej. el receptor revierte), solo afecta a ese usuario.
    ///      Sigue el patron CEI para prevenir reentrancy adicional.
    function withdrawRefund() external {
        // CHECKS
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No pending refund");

        // EFFECTS: actualizar estado antes de la interaccion
        pendingWithdrawals[msg.sender] = 0;

        // INTERACTIONS
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdraw failed");

        emit RefundWithdrawn(msg.sender, amount);
    }

    /// @notice Retorna el balance total del contrato
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
