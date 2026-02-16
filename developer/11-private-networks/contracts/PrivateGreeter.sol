// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title PrivateGreeter - Demo de transacciones privadas
/// @notice Contrato simple que almacena un saludo. Ilustra el concepto de datos
///         que solo deben ser visibles para participantes de un privacy group.
/// @dev En una red Besu con Tessera, este contrato se desplegaria como
///      transaccion privada. Solo los miembros del privacy group podrian
///      leer o modificar el greeting. Los demas nodos veran el hash de la tx
///      pero no podran acceder al estado del contrato.
contract PrivateGreeter {
    // -------------------------------------------------------
    // State
    // -------------------------------------------------------
    string public greeting;
    address public owner;
    uint256 public updateCount;

    // -------------------------------------------------------
    // Events
    // -------------------------------------------------------
    event GreetingUpdated(address indexed updater, string newGreeting, uint256 count);

    // -------------------------------------------------------
    // Errors
    // -------------------------------------------------------
    error Unauthorized(address caller);
    error EmptyGreeting();

    // -------------------------------------------------------
    // Constructor
    // -------------------------------------------------------
    /// @param _initialGreeting The initial greeting message
    constructor(string memory _initialGreeting) {
        if (bytes(_initialGreeting).length == 0) revert EmptyGreeting();
        greeting = _initialGreeting;
        owner = msg.sender;
        updateCount = 0;
    }

    // -------------------------------------------------------
    // Functions
    // -------------------------------------------------------

    /// @notice Update the greeting (only owner in this simple version)
    /// @dev In a privacy group context, access is already restricted
    ///      at the network level. The onlyOwner here is defense in depth.
    function setGreeting(string calldata _newGreeting) external {
        if (msg.sender != owner) revert Unauthorized(msg.sender);
        if (bytes(_newGreeting).length == 0) revert EmptyGreeting();

        greeting = _newGreeting;
        updateCount++;
        emit GreetingUpdated(msg.sender, _newGreeting, updateCount);
    }

    /// @notice Read the current greeting
    /// @dev In a private transaction context, only privacy group members
    ///      can call this function. Other nodes will get an error.
    function getGreeting() external view returns (string memory) {
        return greeting;
    }
}
