// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IERC20.sol";

/// @title SimpleAMM - Automated Market Maker de producto constante (x*y=k)
/// @notice AMM minimo con dos tokens, LP tokens internos y fee de 0.3%
/// @dev El contrato es el propio LP token (implementa ERC-20 para los LP tokens)
contract SimpleAMM {
    // -------------------------------------------------------
    // LP Token State (ERC-20 simplificado)
    // -------------------------------------------------------
    string public constant name = "SimpleAMM LP Token";
    string public constant symbol = "SAMLP";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // -------------------------------------------------------
    // LP Token Events
    // -------------------------------------------------------
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // -------------------------------------------------------
    // AMM State
    // -------------------------------------------------------
    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;

    uint256 public reserveA;
    uint256 public reserveB;

    /// @dev Liquidez minima que se quema en el primer deposito para evitar ataques
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    // -------------------------------------------------------
    // AMM Events
    // -------------------------------------------------------
    event AddLiquidity(
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 lpTokensMinted
    );
    event RemoveLiquidity(
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 lpTokensBurned
    );
    event Swap(
        address indexed user,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 amountOut
    );

    // -------------------------------------------------------
    // Custom Errors
    // -------------------------------------------------------
    error ZeroAmount();
    error InvalidToken();
    error InsufficientLiquidity();
    error InsufficientLPTokens();
    error SlippageTooHigh();
    error TransferFailed();
    error InsufficientBalance();
    error InsufficientAllowance();

    // -------------------------------------------------------
    // Constructor
    // -------------------------------------------------------
    /// @param _tokenA Direccion del primer token
    /// @param _tokenB Direccion del segundo token
    constructor(address _tokenA, address _tokenB) {
        require(_tokenA != _tokenB, "Identical tokens");
        require(_tokenA != address(0) && _tokenB != address(0), "Zero address");

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    // -------------------------------------------------------
    // LP Token: funciones ERC-20 basicas
    // -------------------------------------------------------

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transferLP(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance < amount) revert InsufficientAllowance();

        if (currentAllowance != type(uint256).max) {
            allowance[from][msg.sender] = currentAllowance - amount;
        }
        _transferLP(from, to, amount);
        return true;
    }

    function _transferLP(address from, address to, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mintLP(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burnLP(address from, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InsufficientLPTokens();
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    // -------------------------------------------------------
    // AMM: Core functions
    // -------------------------------------------------------

    /// @notice Agrega liquidez al pool depositando ambos tokens
    /// @param amountA Cantidad de TokenA a depositar
    /// @param amountB Cantidad de TokenB a depositar
    /// @return lpTokens Cantidad de LP tokens recibidos
    function addLiquidity(
        uint256 amountA,
        uint256 amountB
    ) external returns (uint256 lpTokens) {
        if (amountA == 0 || amountB == 0) revert ZeroAmount();

        // Transferir tokens al contrato
        _safeTransferFrom(tokenA, msg.sender, address(this), amountA);
        _safeTransferFrom(tokenB, msg.sender, address(this), amountB);

        if (totalSupply == 0) {
            // Primer deposito: LP tokens = sqrt(amountA * amountB)
            lpTokens = _sqrt(amountA * amountB);

            // Quemar MINIMUM_LIQUIDITY para evitar first depositor attack
            if (lpTokens <= MINIMUM_LIQUIDITY) revert InsufficientLiquidity();
            _mintLP(address(1), MINIMUM_LIQUIDITY); // dead shares
            lpTokens -= MINIMUM_LIQUIDITY;
        } else {
            // Depositos subsiguientes: proporcional a reservas
            uint256 lpFromA = (amountA * totalSupply) / reserveA;
            uint256 lpFromB = (amountB * totalSupply) / reserveB;

            // Usar el minimo para no sobre-emitir LP tokens
            lpTokens = lpFromA < lpFromB ? lpFromA : lpFromB;
        }

        if (lpTokens == 0) revert InsufficientLiquidity();

        _mintLP(msg.sender, lpTokens);

        // Actualizar reservas
        reserveA += amountA;
        reserveB += amountB;

        emit AddLiquidity(msg.sender, amountA, amountB, lpTokens);
    }

    /// @notice Retira liquidez quemando LP tokens
    /// @param lpAmount Cantidad de LP tokens a quemar
    /// @return amountA Cantidad de TokenA recibida
    /// @return amountB Cantidad de TokenB recibida
    function removeLiquidity(
        uint256 lpAmount
    ) external returns (uint256 amountA, uint256 amountB) {
        if (lpAmount == 0) revert ZeroAmount();

        // Calcular proporcion del pool
        amountA = (lpAmount * reserveA) / totalSupply;
        amountB = (lpAmount * reserveB) / totalSupply;

        if (amountA == 0 || amountB == 0) revert InsufficientLiquidity();

        // Quemar LP tokens
        _burnLP(msg.sender, lpAmount);

        // Actualizar reservas
        reserveA -= amountA;
        reserveB -= amountB;

        // Transferir tokens al LP
        _safeTransfer(tokenA, msg.sender, amountA);
        _safeTransfer(tokenB, msg.sender, amountB);

        emit RemoveLiquidity(msg.sender, amountA, amountB, lpAmount);
    }

    /// @notice Intercambia un token por otro
    /// @param tokenIn Direccion del token que se deposita
    /// @param amountIn Cantidad del token a depositar
    /// @return amountOut Cantidad del token recibido
    function swap(
        address tokenIn,
        uint256 amountIn
    ) external returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();

        bool isTokenA = tokenIn == address(tokenA);
        bool isTokenB = tokenIn == address(tokenB);
        if (!isTokenA && !isTokenB) revert InvalidToken();

        // Determinar direccion del swap
        (
            IERC20 inputToken,
            IERC20 outputToken,
            uint256 reserveIn,
            uint256 reserveOut
        ) = isTokenA
            ? (tokenA, tokenB, reserveA, reserveB)
            : (tokenB, tokenA, reserveB, reserveA);

        // Transferir token de entrada
        _safeTransferFrom(inputToken, msg.sender, address(this), amountIn);

        // Calcular amountOut con fee de 0.3%
        // amountInWithFee = amountIn * 997 / 1000
        // amountOut = (reserveOut * amountInWithFee) / (reserveIn + amountInWithFee)
        uint256 amountInWithFee = amountIn * 997;
        amountOut = (reserveOut * amountInWithFee) / (reserveIn * 1000 + amountInWithFee);

        if (amountOut == 0) revert InsufficientLiquidity();

        // Transferir token de salida
        _safeTransfer(outputToken, msg.sender, amountOut);

        // Actualizar reservas
        if (isTokenA) {
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        emit Swap(msg.sender, tokenIn, amountIn, amountOut);
    }

    // -------------------------------------------------------
    // AMM: View functions
    // -------------------------------------------------------

    /// @notice Retorna las reservas actuales del pool
    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    /// @notice Calcula cuanto recibirias por un swap (sin ejecutarlo)
    /// @param tokenIn Direccion del token de entrada
    /// @param amountIn Cantidad a intercambiar
    /// @return amountOut Cantidad estimada de salida
    function getAmountOut(
        address tokenIn,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();

        bool isTokenA = tokenIn == address(tokenA);
        bool isTokenB = tokenIn == address(tokenB);
        if (!isTokenA && !isTokenB) revert InvalidToken();

        uint256 reserveIn = isTokenA ? reserveA : reserveB;
        uint256 reserveOut = isTokenA ? reserveB : reserveA;

        uint256 amountInWithFee = amountIn * 997;
        amountOut = (reserveOut * amountInWithFee) / (reserveIn * 1000 + amountInWithFee);
    }

    /// @notice Retorna el precio spot de tokenA en terminos de tokenB
    /// @return price Precio con 18 decimales de precision
    function getPrice() external view returns (uint256 price) {
        if (reserveA == 0) return 0;
        // Precio de 1 TokenA en TokenB, escalado a 18 decimales
        price = (reserveB * 1e18) / reserveA;
    }

    // -------------------------------------------------------
    // Internal helpers
    // -------------------------------------------------------

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        bool success = token.transferFrom(from, to, amount);
        if (!success) revert TransferFailed();
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        bool success = token.transfer(to, amount);
        if (!success) revert TransferFailed();
    }

    /// @dev Calculo de raiz cuadrada (Babylonian method)
    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;

        uint256 z = (x + 1) / 2;
        y = x;

        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
