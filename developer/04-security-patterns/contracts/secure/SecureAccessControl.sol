// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SecureAccessControl - Access control seguro con msg.sender + Ownable
/// @notice Implementa el patron Ownable desde cero (sin OpenZeppelin)
///         usando msg.sender en lugar de tx.origin para autorizacion.
///
/// @dev En produccion se recomienda usar OpenZeppelin Ownable o
///      AccessControl para roles mas granulares.
contract SecureAccessControl {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Withdrawal(address indexed to, uint256 amount);

    /// @dev Modifier que restringe el acceso al owner actual.
    ///      Usa msg.sender (el llamador directo) en vez de tx.origin.
    ///      Esto previene ataques de phishing via contratos intermediarios.
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /// @notice Retira todos los fondos del contrato
    /// @param _to Direccion destino
    /// @dev SEGURO: usa msg.sender via onlyOwner modifier.
    ///      Un contrato intermediario no puede engasar al owner porque
    ///      msg.sender seria la direccion del contrato intermediario, no el owner.
    function withdraw(address payable _to) external onlyOwner {
        require(_to != address(0), "Invalid address");
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance");
        (bool success, ) = _to.call{value: balance}("");
        require(success, "Transfer failed");
        emit Withdrawal(_to, balance);
    }

    /// @notice Transfiere la propiedad a una nueva direccion
    /// @param _newOwner Nueva direccion del owner
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid new owner");
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    receive() external payable {}
}
