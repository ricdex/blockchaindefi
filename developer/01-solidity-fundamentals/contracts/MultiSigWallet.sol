// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MultiSigWallet - Billetera multifirma simplificada
/// @notice Requiere M de N confirmaciones para ejecutar transacciones
contract MultiSigWallet {
    // -------------------------------------------------------
    // Events
    // -------------------------------------------------------
    event Deposit(address indexed sender, uint256 amount);
    event TransactionSubmitted(uint256 indexed txId, address indexed to, uint256 value, bytes data);
    event TransactionConfirmed(uint256 indexed txId, address indexed owner);
    event TransactionRevoked(uint256 indexed txId, address indexed owner);
    event TransactionExecuted(uint256 indexed txId);

    // -------------------------------------------------------
    // Custom Errors (mas eficientes en gas que strings)
    // -------------------------------------------------------
    error NotOwner(address caller);
    error TxDoesNotExist(uint256 txId);
    error TxAlreadyExecuted(uint256 txId);
    error TxAlreadyConfirmed(uint256 txId, address owner);
    error TxNotConfirmed(uint256 txId, address owner);
    error NotEnoughConfirmations(uint256 txId, uint256 current, uint256 required);
    error TxExecutionFailed(uint256 txId);
    error NoOwners();
    error InvalidRequiredCount(uint256 required, uint256 ownerCount);
    error InvalidOwnerAddress();
    error DuplicateOwner(address owner);

    // -------------------------------------------------------
    // State
    // -------------------------------------------------------
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public required;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
    }

    Transaction[] public transactions;
    /// @dev txId => owner => ha confirmado?
    mapping(uint256 => mapping(address => bool)) public confirmed;

    // -------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------
    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert NotOwner(msg.sender);
        _;
    }

    modifier txExists(uint256 _txId) {
        if (_txId >= transactions.length) revert TxDoesNotExist(_txId);
        _;
    }

    modifier notExecuted(uint256 _txId) {
        if (transactions[_txId].executed) revert TxAlreadyExecuted(_txId);
        _;
    }

    modifier notConfirmed(uint256 _txId) {
        if (confirmed[_txId][msg.sender]) revert TxAlreadyConfirmed(_txId, msg.sender);
        _;
    }

    // -------------------------------------------------------
    // Constructor
    // -------------------------------------------------------
    /// @param _owners Lista de direcciones que seran owners
    /// @param _required Numero minimo de confirmaciones para ejecutar una tx
    constructor(address[] memory _owners, uint256 _required) {
        if (_owners.length == 0) revert NoOwners();
        if (_required == 0 || _required > _owners.length) {
            revert InvalidRequiredCount(_required, _owners.length);
        }

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            if (owner == address(0)) revert InvalidOwnerAddress();
            if (isOwner[owner]) revert DuplicateOwner(owner);

            isOwner[owner] = true;
            owners.push(owner);
        }

        required = _required;
    }

    // -------------------------------------------------------
    // Recibir ETH
    // -------------------------------------------------------
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    // -------------------------------------------------------
    // Funciones principales
    // -------------------------------------------------------

    /// @notice Propone una nueva transaccion
    /// @param _to Direccion destino
    /// @param _value Cantidad de ETH (en wei)
    /// @param _data Calldata para la llamada
    function submit(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external onlyOwner {
        uint256 txId = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                confirmations: 0
            })
        );

        emit TransactionSubmitted(txId, _to, _value, _data);
    }

    /// @notice Confirma una transaccion pendiente
    /// @param _txId ID de la transaccion
    function confirm(
        uint256 _txId
    ) external onlyOwner txExists(_txId) notExecuted(_txId) notConfirmed(_txId) {
        Transaction storage txn = transactions[_txId];
        txn.confirmations += 1;
        confirmed[_txId][msg.sender] = true;

        emit TransactionConfirmed(_txId, msg.sender);
    }

    /// @notice Ejecuta una transaccion con suficientes confirmaciones
    /// @param _txId ID de la transaccion
    function execute(
        uint256 _txId
    ) external onlyOwner txExists(_txId) notExecuted(_txId) {
        Transaction storage txn = transactions[_txId];

        if (txn.confirmations < required) {
            revert NotEnoughConfirmations(_txId, txn.confirmations, required);
        }

        txn.executed = true;

        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        if (!success) revert TxExecutionFailed(_txId);

        emit TransactionExecuted(_txId);
    }

    /// @notice Revoca la confirmacion de una transaccion
    /// @param _txId ID de la transaccion
    function revoke(
        uint256 _txId
    ) external onlyOwner txExists(_txId) notExecuted(_txId) {
        if (!confirmed[_txId][msg.sender]) revert TxNotConfirmed(_txId, msg.sender);

        Transaction storage txn = transactions[_txId];
        txn.confirmations -= 1;
        confirmed[_txId][msg.sender] = false;

        emit TransactionRevoked(_txId, msg.sender);
    }

    // -------------------------------------------------------
    // View functions
    // -------------------------------------------------------

    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }

    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    function getTransaction(
        uint256 _txId
    )
        external
        view
        returns (address to, uint256 value, bytes memory data, bool executed, uint256 confirmations)
    {
        Transaction storage txn = transactions[_txId];
        return (txn.to, txn.value, txn.data, txn.executed, txn.confirmations);
    }
}
