// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MockArbSys - Simula el precompile ArbSys (0x64) de Arbitrum en tests locales
/// @dev Se instala con `vm.etch(address(0x64), address(new MockArbSys()).code)`.
///      Como `vm.etch` copia solo el bytecode (no el storage), el valor es una constante.
contract MockArbSys {
    uint256 public constant FAKE_L2_BLOCK = 123_456_789;

    function arbBlockNumber() external pure returns (uint256) {
        return FAKE_L2_BLOCK;
    }
}
