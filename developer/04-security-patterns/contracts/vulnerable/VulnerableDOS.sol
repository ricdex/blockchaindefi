// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title VulnerableDOS - INSEGURO - Solo para aprendizaje
/// @notice Vulnerable a Denial of Service via push payment pattern.
///         Si una de las direcciones de refund es un contrato que revierte
///         al recibir ETH, la funcion refundAll() se bloquea para TODOS.
contract VulnerableDOS {
    address[] public refundAddresses;
    mapping(address => uint256) public refundAmounts;

    event RefundAdded(address indexed addr, uint256 amount);
    event RefundProcessed(address indexed addr, uint256 amount);

    /// @notice Agrega una direccion con un monto de refund
    /// @param _addr Direccion que recibira el refund
    function addRefund(address _addr) external payable {
        require(msg.value > 0, "Must send ETH");
        refundAddresses.push(_addr);
        refundAmounts[_addr] += msg.value;
        emit RefundAdded(_addr, msg.value);
    }

    /// @notice Procesa todos los refunds de una vez
    /// @dev VULNERABLE: si un address es un contrato que revierte en receive(),
    ///      el require(success) hace que TODA la funcion falle,
    ///      bloqueando los refunds de todos los usuarios.
    function refundAll() external {
        for (uint256 i = 0; i < refundAddresses.length; i++) {
            address addr = refundAddresses[i];
            uint256 amount = refundAmounts[addr];
            if (amount > 0) {
                refundAmounts[addr] = 0;
                (bool success, ) = addr.call{value: amount}("");
                require(success, "Refund failed"); // BUG: one failure blocks all
                emit RefundProcessed(addr, amount);
            }
        }
    }

    /// @notice Retorna el numero de direcciones registradas
    function getRefundCount() external view returns (uint256) {
        return refundAddresses.length;
    }
}
