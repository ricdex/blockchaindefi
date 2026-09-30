// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ChainProbe - "Donde estoy?" visto desde dentro de la EVM
/// @notice Contrato didactico del laboratorio L1 -> L2 (Sepolia -> Arbitrum Sepolia).
///         Lo despliegas en Arbitrum y te deja observar, desde el propio contrato:
///         - en que red se ejecuta (block.chainid)
///         - que numero de bloque ve (block.number) vs el bloque real de L2 (ArbSys)
///         - cuanto activo nativo (ETH) tiene su cuenta EN ESA RED
///         - un estado propio (note) que solo existe en la red donde se desplego
///
/// @dev En cadenas Arbitrum, `block.number` devuelve una aproximacion del bloque de
///      L1 en que el sequencer recibio la transaccion. El bloque de L2 se obtiene del
///      precompile ArbSys (direccion fija 0x64). En cualquier otra red esa direccion
///      no tiene codigo, la llamada no devuelve datos y el contrato lo detecta.
contract ChainProbe {
    // =========================================================================
    // Constantes
    // =========================================================================

    /// @notice Precompile ArbSys: presente en todas las cadenas Arbitrum
    address public constant ARB_SYS = address(0x64);

    // =========================================================================
    // Estado
    // =========================================================================

    /// @notice Chain ID de la red donde se ejecuto el constructor
    uint256 public immutable deployedOnChainId;

    /// @notice Cuenta que desplego el contrato
    address public immutable deployer;

    /// @notice Estado de ejemplo: vive solo en el storage de la red donde se desplego
    string public note;

    /// @notice Ultima cuenta que escribio la nota
    address public lastWriter;

    // =========================================================================
    // Events y errores
    // =========================================================================

    event NoteWritten(address indexed writer, string note, uint256 chainId);
    event NativeReceived(address indexed from, uint256 amount);
    event NativeSwept(address indexed to, uint256 amount);

    error NotDeployer(address caller);
    error SweepFailed();

    // =========================================================================
    // Constructor
    // =========================================================================

    constructor(string memory initialNote) {
        deployedOnChainId = block.chainid;
        deployer = msg.sender;
        note = initialNote;
        lastWriter = msg.sender;
    }

    // =========================================================================
    // Lectura: donde estoy?
    // =========================================================================

    /// @notice Describe la red en la que se esta ejecutando la llamada
    /// @return chainId        Chain ID de la red actual
    /// @return evmBlockNumber `block.number` (en Arbitrum: aproximacion del bloque de L1)
    /// @return l2BlockNumber  Bloque de L2 segun ArbSys (0 si no es una cadena Arbitrum)
    /// @return isArbitrum     true si el precompile ArbSys respondio
    function whereAmI()
        external
        view
        returns (uint256 chainId, uint256 evmBlockNumber, uint256 l2BlockNumber, bool isArbitrum)
    {
        chainId = block.chainid;
        evmBlockNumber = block.number;
        (isArbitrum, l2BlockNumber) = _arbBlockNumber();
    }

    /// @notice Balance de activo nativo (ETH) de este contrato en la red actual
    function nativeBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // =========================================================================
    // Escritura
    // =========================================================================

    /// @notice Cambia la nota. El cambio queda en el estado de ESTA red, no en otras.
    function writeNote(string calldata newNote) external {
        note = newNote;
        lastWriter = msg.sender;
        emit NoteWritten(msg.sender, newNote, block.chainid);
    }

    /// @notice Recibe activo nativo: el balance lo lleva el protocolo, no un mapping
    receive() external payable {
        emit NativeReceived(msg.sender, msg.value);
    }

    /// @notice Devuelve todo el activo nativo al deployer (para no dejar fondos atrapados)
    function sweep() external {
        if (msg.sender != deployer) revert NotDeployer(msg.sender);
        uint256 amount = address(this).balance;
        (bool success,) = deployer.call{value: amount}("");
        if (!success) revert SweepFailed();
        emit NativeSwept(deployer, amount);
    }

    // =========================================================================
    // Internas
    // =========================================================================

    /// @dev staticcall a una direccion sin codigo "tiene exito" pero no devuelve datos,
    ///      por eso se valida el largo de la respuesta ademas del flag de exito.
    function _arbBlockNumber() internal view returns (bool ok, uint256 blockNumber) {
        (bool success, bytes memory ret) = ARB_SYS.staticcall(abi.encodeWithSignature("arbBlockNumber()"));
        if (success && ret.length == 32) {
            return (true, abi.decode(ret, (uint256)));
        }
        return (false, 0);
    }
}
