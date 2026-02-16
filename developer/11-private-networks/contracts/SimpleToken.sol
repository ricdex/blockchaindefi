// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SimpleToken - ERC-20 basico para redes privadas
/// @notice Token ERC-20 minimo con mint y burn, pensado para demostrar deploy en Besu
/// @dev Implementacion manual sin dependencias externas, con fines educativos
contract SimpleToken {
    // -------------------------------------------------------
    // State
    // -------------------------------------------------------
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    address public owner;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // -------------------------------------------------------
    // Events
    // -------------------------------------------------------
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed to, uint256 value);
    event Burn(address indexed from, uint256 value);

    // -------------------------------------------------------
    // Errors
    // -------------------------------------------------------
    error InsufficientBalance(uint256 available, uint256 required);
    error InsufficientAllowance(uint256 available, uint256 required);
    error Unauthorized(address caller);
    error ZeroAddress();

    // -------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized(msg.sender);
        _;
    }

    // -------------------------------------------------------
    // Constructor
    // -------------------------------------------------------
    /// @param _name Token name
    /// @param _symbol Token symbol
    /// @param _initialSupply Initial supply minted to deployer (in wei)
    constructor(string memory _name, string memory _symbol, uint256 _initialSupply) {
        name = _name;
        symbol = _symbol;
        owner = msg.sender;

        if (_initialSupply > 0) {
            _mint(msg.sender, _initialSupply);
        }
    }

    // -------------------------------------------------------
    // ERC-20 Functions
    // -------------------------------------------------------
    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance < value) {
            revert InsufficientAllowance(currentAllowance, value);
        }
        allowance[from][msg.sender] = currentAllowance - value;
        _transfer(from, to, value);
        return true;
    }

    // -------------------------------------------------------
    // Mint / Burn (owner only)
    // -------------------------------------------------------
    /// @notice Mint new tokens to an address
    function mint(address to, uint256 value) external onlyOwner {
        _mint(to, value);
    }

    /// @notice Burn tokens from caller's balance
    function burn(uint256 value) external {
        _burn(msg.sender, value);
    }

    // -------------------------------------------------------
    // Internal Functions
    // -------------------------------------------------------
    function _transfer(address from, address to, uint256 value) internal {
        if (to == address(0)) revert ZeroAddress();
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < value) {
            revert InsufficientBalance(fromBalance, value);
        }
        balanceOf[from] = fromBalance - value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }

    function _approve(address _owner, address spender, uint256 value) internal {
        if (spender == address(0)) revert ZeroAddress();
        allowance[_owner][spender] = value;
        emit Approval(_owner, spender, value);
    }

    function _mint(address to, uint256 value) internal {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
        emit Mint(to, value);
    }

    function _burn(address from, uint256 value) internal {
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < value) {
            revert InsufficientBalance(fromBalance, value);
        }
        balanceOf[from] = fromBalance - value;
        totalSupply -= value;
        emit Transfer(from, address(0), value);
        emit Burn(from, value);
    }
}
