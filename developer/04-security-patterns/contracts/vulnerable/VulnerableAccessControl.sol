// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title VulnerableAccessControl - INSEGURO - Solo para aprendizaje
/// @notice Este contrato usa tx.origin para autorizacion, lo que permite
///         que un contrato intermediario (phishing) engane al owner para
///         ejecutar acciones no autorizadas.
contract VulnerableAccessControl {
    address public owner;

    event Withdrawal(address indexed to, uint256 amount);

    constructor() {
        owner = msg.sender;
    }

    /// @notice Retira todos los fondos del contrato
    /// @param _to Direccion destino
    /// @dev VULNERABLE: usa tx.origin en vez de msg.sender.
    ///      Si el owner interactua con un contrato malicioso,
    ///      ese contrato puede llamar withdraw() porque tx.origin == owner.
    function withdraw(address payable _to) external {
        require(tx.origin == owner, "Not owner");
        uint256 balance = address(this).balance;
        (bool success, ) = _to.call{value: balance}("");
        require(success, "Transfer failed");
        emit Withdrawal(_to, balance);
    }

    receive() external payable {}
}
