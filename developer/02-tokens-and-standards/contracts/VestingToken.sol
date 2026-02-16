// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title VestingToken - ERC-20 implementado desde cero con vesting lineal
/// @notice Token ERC-20 con mecanismo de vesting (cliff + liberacion lineal)
/// @dev Implementacion manual sin dependencias externas, con fines educativos
contract VestingToken {
    // -------------------------------------------------------
    // ERC-20 State
    // -------------------------------------------------------
    string private _name;
    string private _symbol;
    uint8 private constant _decimals = 18;
    uint256 private _totalSupply;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // -------------------------------------------------------
    // ERC-20 Events
    // -------------------------------------------------------
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // -------------------------------------------------------
    // Vesting State
    // -------------------------------------------------------
    address public owner;

    struct VestingSchedule {
        uint256 totalAmount;    // cantidad total de tokens a vestear
        uint256 released;       // cantidad ya liberada
        uint256 startTime;      // timestamp de inicio
        uint256 duration;       // duracion total del vesting
        uint256 cliffDuration;  // duracion del cliff (desde startTime)
    }

    /// @dev beneficiary => VestingSchedule
    mapping(address => VestingSchedule) public vestingSchedules;

    // -------------------------------------------------------
    // Vesting Events
    // -------------------------------------------------------
    event VestingCreated(
        address indexed beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration
    );
    event TokensReleased(address indexed beneficiary, uint256 amount);

    // -------------------------------------------------------
    // Custom Errors
    // -------------------------------------------------------
    error NotOwner();
    error ZeroAddress();
    error InsufficientBalance(uint256 available, uint256 required);
    error InsufficientAllowance(uint256 available, uint256 required);
    error VestingAlreadyExists(address beneficiary);
    error NoVestingSchedule(address beneficiary);
    error NothingToRelease(address beneficiary);
    error InvalidVestingParams();

    // -------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    // -------------------------------------------------------
    // Constructor
    // -------------------------------------------------------
    /// @param name_ Nombre del token
    /// @param symbol_ Simbolo del token
    /// @param initialSupply Supply inicial (en unidades, se multiplica por 10^decimals)
    constructor(string memory name_, string memory symbol_, uint256 initialSupply) {
        _name = name_;
        _symbol = symbol_;
        owner = msg.sender;

        // Mintear supply inicial al deployer
        uint256 amount = initialSupply * 10 ** _decimals;
        _balances[msg.sender] = amount;
        _totalSupply = amount;
        emit Transfer(address(0), msg.sender, amount);
    }

    // -------------------------------------------------------
    // ERC-20: Metadata
    // -------------------------------------------------------

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external pure returns (uint8) {
        return _decimals;
    }

    // -------------------------------------------------------
    // ERC-20: Core
    // -------------------------------------------------------

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address tokenOwner, address spender) external view returns (uint256) {
        return _allowances[tokenOwner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance < amount) {
            revert InsufficientAllowance(currentAllowance, amount);
        }

        // Descontar allowance (si no es unlimited)
        if (currentAllowance != type(uint256).max) {
            _allowances[from][msg.sender] = currentAllowance - amount;
        }

        _transfer(from, to, amount);
        return true;
    }

    // -------------------------------------------------------
    // ERC-20: Internal
    // -------------------------------------------------------

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();

        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) {
            revert InsufficientBalance(fromBalance, amount);
        }

        _balances[from] = fromBalance - amount;
        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _approve(address tokenOwner, address spender, uint256 amount) internal {
        if (tokenOwner == address(0)) revert ZeroAddress();
        if (spender == address(0)) revert ZeroAddress();

        _allowances[tokenOwner][spender] = amount;
        emit Approval(tokenOwner, spender, amount);
    }

    /// @dev Mintea tokens a una direccion (solo uso interno)
    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();

        _totalSupply += amount;
        _balances[to] += amount;

        emit Transfer(address(0), to, amount);
    }

    // -------------------------------------------------------
    // Vesting
    // -------------------------------------------------------

    /// @notice Crea un schedule de vesting para un beneficiario
    /// @dev Los tokens se transfieren del owner al contrato y se liberan gradualmente
    /// @param beneficiary Direccion del beneficiario
    /// @param totalAmount Cantidad total de tokens (con decimales)
    /// @param startTime Timestamp de inicio del vesting
    /// @param duration Duracion total del vesting en segundos
    /// @param cliffDuration Duracion del cliff en segundos (desde startTime)
    function createVesting(
        address beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration
    ) external onlyOwner {
        if (beneficiary == address(0)) revert ZeroAddress();
        if (totalAmount == 0 || duration == 0) revert InvalidVestingParams();
        if (cliffDuration > duration) revert InvalidVestingParams();
        if (vestingSchedules[beneficiary].totalAmount != 0) {
            revert VestingAlreadyExists(beneficiary);
        }

        // Transferir tokens del owner al contrato (lock)
        _transfer(msg.sender, address(this), totalAmount);

        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: totalAmount,
            released: 0,
            startTime: startTime,
            duration: duration,
            cliffDuration: cliffDuration
        });

        emit VestingCreated(beneficiary, totalAmount, startTime, duration, cliffDuration);
    }

    /// @notice Calcula la cantidad total de tokens que han vesteado hasta ahora
    /// @param beneficiary Direccion del beneficiario
    /// @return Cantidad de tokens vesteados (incluyendo los ya liberados)
    function vestedAmount(address beneficiary) public view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];

        if (schedule.totalAmount == 0) return 0;

        uint256 cliffEnd = schedule.startTime + schedule.cliffDuration;

        // Antes del cliff: nada vesteado
        if (block.timestamp < cliffEnd) {
            return 0;
        }

        uint256 vestingEnd = schedule.startTime + schedule.duration;

        // Despues de la duracion total: todo vesteado
        if (block.timestamp >= vestingEnd) {
            return schedule.totalAmount;
        }

        // Vesting lineal: proporcional al tiempo transcurrido
        uint256 elapsed = block.timestamp - schedule.startTime;
        return (schedule.totalAmount * elapsed) / schedule.duration;
    }

    /// @notice Calcula cuanto puede reclamar el beneficiario ahora
    /// @param beneficiary Direccion del beneficiario
    /// @return Cantidad de tokens que se pueden liberar
    function releasableAmount(address beneficiary) public view returns (uint256) {
        return vestedAmount(beneficiary) - vestingSchedules[beneficiary].released;
    }

    /// @notice Libera los tokens vesteados al beneficiario
    /// @param beneficiary Direccion del beneficiario
    function release(address beneficiary) external {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        if (schedule.totalAmount == 0) revert NoVestingSchedule(beneficiary);

        uint256 amount = releasableAmount(beneficiary);
        if (amount == 0) revert NothingToRelease(beneficiary);

        schedule.released += amount;

        // Transferir desde el contrato al beneficiario
        _transfer(address(this), beneficiary, amount);

        emit TokensReleased(beneficiary, amount);
    }
}
