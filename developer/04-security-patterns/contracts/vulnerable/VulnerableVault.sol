// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title VulnerableVault - INSEGURO - Solo para aprendizaje
/// @notice Este contrato tiene una vulnerabilidad de reentrancy intencional.
///         El ETH se envia al usuario ANTES de actualizar su balance,
///         permitiendo que un contrato atacante re-entre en withdraw()
///         multiples veces antes de que el balance sea puesto a cero.
contract VulnerableVault {
    mapping(address => uint256) public balances;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    /// @notice Deposita ETH en el vault
    function deposit() external payable {
        require(msg.value > 0, "Must send ETH");
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice Retira todo el ETH depositado
    /// @dev VULNERABLE: envia ETH antes de actualizar el balance (viola CEI)
    function withdraw() external {
        uint256 balance = balances[msg.sender];
        require(balance > 0, "No balance");

        // INTERACCION ANTES DE EFECTO -- esta es la vulnerabilidad
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Transfer failed");

        // EFECTO DESPUES DE INTERACCION -- demasiado tarde si hay reentrancy
        balances[msg.sender] = 0;

        emit Withdraw(msg.sender, balance);
    }

    /// @notice Retorna el balance total del vault
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
