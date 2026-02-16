// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MockAggregatorV3 - Mock de Chainlink AggregatorV3Interface para testing
/// @notice Permite simular un price feed de Chainlink en tests locales.
///         Soporta actualizacion de precio y timestamp para probar
///         escenarios como stale data, price drops, etc.
contract MockAggregatorV3 {
    int256 private _price;
    uint8 private _decimals;
    uint256 private _updatedAt;
    uint80 private _roundId;
    string private _description;

    /// @param initialPrice Precio inicial (con la cantidad de decimales especificada)
    /// @param decimals_ Numero de decimales (Chainlink ETH/USD usa 8)
    constructor(int256 initialPrice, uint8 decimals_) {
        _price = initialPrice;
        _decimals = decimals_;
        _updatedAt = block.timestamp;
        _roundId = 1;
        _description = "Mock Price Feed";
    }

    /// @notice Actualiza el precio del feed
    /// @param newPrice Nuevo precio
    function updatePrice(int256 newPrice) external {
        _price = newPrice;
        _updatedAt = block.timestamp;
        _roundId++;
    }

    /// @notice Actualiza el precio con un timestamp personalizado
    /// @param newPrice Nuevo precio
    /// @param timestamp Timestamp personalizado (para simular stale data)
    function updatePriceWithTimestamp(int256 newPrice, uint256 timestamp) external {
        _price = newPrice;
        _updatedAt = timestamp;
        _roundId++;
    }

    /// @notice Retorna el numero de decimales del price feed
    function decimals() external view returns (uint8) {
        return _decimals;
    }

    /// @notice Retorna la descripcion del price feed
    function description() external view returns (string memory) {
        return _description;
    }

    /// @notice Retorna la version del aggregator
    function version() external pure returns (uint256) {
        return 4;
    }

    /// @notice Retorna los datos del ultimo round (compatible con Chainlink)
    /// @return roundId ID del round actual
    /// @return answer Precio actual
    /// @return startedAt Timestamp de inicio del round
    /// @return updatedAt Timestamp de la ultima actualizacion
    /// @return answeredInRound ID del round en que se respondio
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (_roundId, _price, _updatedAt, _updatedAt, _roundId);
    }

    /// @notice Retorna datos de un round especifico (simplificado para mock)
    function getRoundData(uint80)
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (_roundId, _price, _updatedAt, _updatedAt, _roundId);
    }
}
