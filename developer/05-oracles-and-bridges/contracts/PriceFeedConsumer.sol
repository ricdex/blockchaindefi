// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IAggregatorV3 - Interface minima compatible con Chainlink AggregatorV3
/// @dev Definida inline para no depender de imports externos en el modulo educativo
interface IAggregatorV3 {
    function decimals() external view returns (uint8);

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

/// @title PriceFeedConsumer - Sistema de collateral con liquidacion
/// @notice Los usuarios depositan ETH como collateral y pueden borrowear USD
///         basado en el precio ETH/USD de un oracle Chainlink.
///
///         Reglas:
///         - LTV (Loan-to-Value) maximo: 75% del valor del collateral
///         - Liquidation threshold: si el collateral cae por debajo del 110%
///           del borrow, la posicion es liquidatable
///         - Stale price check: revierte si el precio tiene mas de 1 hora
///
/// @dev Este contrato usa un "synthetic USD" interno para simplificar.
///      En produccion se usaria un stablecoin real (DAI, USDC, etc).
contract PriceFeedConsumer {
    // =========================================================================
    // Constantes
    // =========================================================================

    /// @notice Porcentaje maximo de LTV (75%) expresado en basis points
    uint256 public constant MAX_LTV_BPS = 7500;

    /// @notice Liquidation threshold (110%) expresado en basis points
    /// @dev Si collateralValue < borrowAmount * LIQUIDATION_THRESHOLD / 10000,
    ///      la posicion es liquidatable
    uint256 public constant LIQUIDATION_THRESHOLD_BPS = 11000;

    /// @notice Basis points base (100%)
    uint256 public constant BPS_BASE = 10000;

    /// @notice Maximo tiempo permitido desde la ultima actualizacion del oracle
    uint256 public constant MAX_STALENESS = 1 hours;

    /// @notice Precision para calculos internos en USD (18 decimales)
    uint256 public constant USD_PRECISION = 1e18;

    // =========================================================================
    // Estado
    // =========================================================================

    /// @notice Referencia al price feed (Chainlink o mock)
    IAggregatorV3 public immutable priceFeed;

    /// @notice Decimales del price feed
    uint8 public immutable feedDecimals;

    /// @notice Posicion de un usuario
    struct Position {
        uint256 collateralETH; // ETH depositado (en wei)
        uint256 borrowedUSD;   // USD borroweado (18 decimales)
    }

    /// @notice Mapping de posiciones por usuario
    mapping(address => Position) public positions;

    // =========================================================================
    // Events
    // =========================================================================

    event Deposit(address indexed user, uint256 ethAmount);
    event Withdraw(address indexed user, uint256 ethAmount);
    event Borrow(address indexed user, uint256 usdAmount);
    event Repay(address indexed user, uint256 usdAmount);
    event Liquidate(
        address indexed liquidator,
        address indexed user,
        uint256 collateralSeized,
        uint256 debtRepaid
    );

    // =========================================================================
    // Constructor
    // =========================================================================

    /// @param _priceFeed Direccion del price feed (Chainlink AggregatorV3 o mock)
    constructor(address _priceFeed) {
        require(_priceFeed != address(0), "Invalid price feed");
        priceFeed = IAggregatorV3(_priceFeed);
        feedDecimals = IAggregatorV3(_priceFeed).decimals();
    }

    // =========================================================================
    // Funciones principales
    // =========================================================================

    /// @notice Deposita ETH como collateral
    function deposit() external payable {
        require(msg.value > 0, "Must send ETH");
        positions[msg.sender].collateralETH += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice Retira ETH del collateral (si la posicion sigue sana)
    /// @param _amount Cantidad de ETH a retirar (en wei)
    function withdraw(uint256 _amount) external {
        Position storage pos = positions[msg.sender];
        require(pos.collateralETH >= _amount, "Insufficient collateral");

        // Calcular el collateral restante despues del retiro
        uint256 remainingCollateral = pos.collateralETH - _amount;

        // Si tiene borrow activo, verificar que la posicion siga sana
        if (pos.borrowedUSD > 0) {
            uint256 ethPrice = _getETHPrice();
            uint256 remainingValue = _ethToUSD(remainingCollateral, ethPrice);
            uint256 maxBorrow = (remainingValue * MAX_LTV_BPS) / BPS_BASE;
            require(pos.borrowedUSD <= maxBorrow, "Would exceed LTV");
        }

        pos.collateralETH = remainingCollateral;

        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "Transfer failed");

        emit Withdraw(msg.sender, _amount);
    }

    /// @notice Borrowea USD usando el collateral ETH
    /// @param _usdAmount Cantidad de USD a borrowear (18 decimales)
    function borrow(uint256 _usdAmount) external {
        require(_usdAmount > 0, "Must borrow something");

        Position storage pos = positions[msg.sender];
        require(pos.collateralETH > 0, "No collateral");

        uint256 ethPrice = _getETHPrice();
        uint256 collateralValueUSD = _ethToUSD(pos.collateralETH, ethPrice);

        uint256 maxBorrow = (collateralValueUSD * MAX_LTV_BPS) / BPS_BASE;
        uint256 newTotalBorrow = pos.borrowedUSD + _usdAmount;

        require(newTotalBorrow <= maxBorrow, "Exceeds max LTV");

        pos.borrowedUSD = newTotalBorrow;

        emit Borrow(msg.sender, _usdAmount);
    }

    /// @notice Repaga parte o todo el borrow
    /// @param _usdAmount Cantidad de USD a repagar (18 decimales)
    function repay(uint256 _usdAmount) external {
        Position storage pos = positions[msg.sender];
        require(pos.borrowedUSD > 0, "No debt");
        require(_usdAmount <= pos.borrowedUSD, "Repay exceeds debt");

        pos.borrowedUSD -= _usdAmount;

        emit Repay(msg.sender, _usdAmount);
    }

    /// @notice Liquida una posicion sub-collateralizada
    /// @param _user Direccion del usuario a liquidar
    /// @dev Cualquiera puede llamar esta funcion. El liquidador recibe
    ///      todo el collateral del usuario liquidado.
    ///      En produccion habria incentivos mas sofisticados (descuento, partial liquidation).
    function liquidate(address _user) external {
        Position storage pos = positions[_user];
        require(pos.borrowedUSD > 0, "No debt to liquidate");
        require(pos.collateralETH > 0, "No collateral");

        uint256 ethPrice = _getETHPrice();
        require(_isLiquidatable(_user, ethPrice), "Position is healthy");

        // Seize todo el collateral y cancelar la deuda
        uint256 collateralSeized = pos.collateralETH;
        uint256 debtRepaid = pos.borrowedUSD;

        pos.collateralETH = 0;
        pos.borrowedUSD = 0;

        // Enviar collateral al liquidador
        (bool success, ) = msg.sender.call{value: collateralSeized}("");
        require(success, "Transfer failed");

        emit Liquidate(msg.sender, _user, collateralSeized, debtRepaid);
    }

    // =========================================================================
    // View functions
    // =========================================================================

    /// @notice Retorna el precio actual de ETH en USD
    /// @return Precio con 18 decimales de precision
    function getETHPrice() external view returns (uint256) {
        return _getETHPrice();
    }

    /// @notice Verifica si una posicion es liquidatable
    /// @param _user Direccion del usuario
    /// @return true si la posicion es liquidatable
    function isLiquidatable(address _user) external view returns (bool) {
        uint256 ethPrice = _getETHPrice();
        return _isLiquidatable(_user, ethPrice);
    }

    /// @notice Retorna el valor del collateral en USD
    /// @param _user Direccion del usuario
    /// @return Valor en USD con 18 decimales
    function getCollateralValueUSD(address _user) external view returns (uint256) {
        uint256 ethPrice = _getETHPrice();
        return _ethToUSD(positions[_user].collateralETH, ethPrice);
    }

    /// @notice Retorna el monto maximo que un usuario puede borrowear
    /// @param _user Direccion del usuario
    /// @return Monto maximo en USD con 18 decimales
    function getMaxBorrow(address _user) external view returns (uint256) {
        uint256 ethPrice = _getETHPrice();
        uint256 collateralValueUSD = _ethToUSD(positions[_user].collateralETH, ethPrice);
        uint256 maxBorrow = (collateralValueUSD * MAX_LTV_BPS) / BPS_BASE;
        if (maxBorrow <= positions[_user].borrowedUSD) return 0;
        return maxBorrow - positions[_user].borrowedUSD;
    }

    // =========================================================================
    // Internal functions
    // =========================================================================

    /// @notice Lee el precio ETH/USD del oracle con validaciones de seguridad
    /// @return Precio normalizado a 18 decimales
    /// @dev Validaciones:
    ///      1. El precio debe ser > 0
    ///      2. El round debe estar completo (updatedAt > 0)
    ///      3. answeredInRound >= roundId (no stale round)
    ///      4. El timestamp no debe ser mas viejo que MAX_STALENESS
    function _getETHPrice() internal view returns (uint256) {
        (
            uint80 roundId,
            int256 answer,
            ,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();

        // Validacion 1: precio positivo
        require(answer > 0, "Invalid price: non-positive");

        // Validacion 2: round completo
        require(updatedAt > 0, "Round not complete");

        // Validacion 3: no es un round stale
        require(answeredInRound >= roundId, "Stale round");

        // Validacion 4: datos no son demasiado viejos
        require(
            block.timestamp - updatedAt <= MAX_STALENESS,
            "Stale price data"
        );

        // Normalizar a 18 decimales
        // Si el feed tiene 8 decimales, multiplicar por 10^(18-8) = 10^10
        return uint256(answer) * (10 ** (18 - feedDecimals));
    }

    /// @notice Convierte una cantidad de ETH (wei) a USD
    /// @param _ethAmount Cantidad en wei
    /// @param _ethPrice Precio ETH/USD con 18 decimales
    /// @return Valor en USD con 18 decimales
    function _ethToUSD(uint256 _ethAmount, uint256 _ethPrice) internal pure returns (uint256) {
        // _ethAmount esta en wei (18 decimales)
        // _ethPrice esta en USD con 18 decimales
        // Resultado: (_ethAmount * _ethPrice) / 1e18 -> USD con 18 decimales
        return (_ethAmount * _ethPrice) / 1e18;
    }

    /// @notice Verifica si una posicion esta sub-collateralizada
    /// @param _user Direccion del usuario
    /// @param _ethPrice Precio ETH/USD actual
    /// @return true si la posicion debe ser liquidada
    function _isLiquidatable(address _user, uint256 _ethPrice) internal view returns (bool) {
        Position storage pos = positions[_user];
        if (pos.borrowedUSD == 0) return false;

        uint256 collateralValueUSD = _ethToUSD(pos.collateralETH, _ethPrice);

        // Liquidatable si: collateralValue < borrowedUSD * 110%
        // Es decir: collateralValue * 10000 < borrowedUSD * 11000
        return (collateralValueUSD * BPS_BASE) < (pos.borrowedUSD * LIQUIDATION_THRESHOLD_BPS);
    }
}
