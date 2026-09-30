// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/ChainProbe.sol";
import "../contracts/MockArbSys.sol";

/// @dev Precompile que revierte: sirve para probar que ChainProbe no asume Arbitrum
contract RevertingArbSys {
    fallback() external {
        revert("no arbsys");
    }
}

/// @dev Receptor que rechaza ETH: sirve para probar el error SweepFailed
contract RejectingDeployer {
    function deploy() external returns (ChainProbe) {
        return new ChainProbe("rechazo ETH");
    }
}

contract ChainProbeTest is Test {
    uint256 constant ARBITRUM_SEPOLIA = 421614;
    uint256 constant SEPOLIA = 11155111;

    ChainProbe probe;
    address alice = makeAddr("alice");

    event NoteWritten(address indexed writer, string note, uint256 chainId);
    event NativeReceived(address indexed from, uint256 amount);
    event NativeSwept(address indexed to, uint256 amount);

    function setUp() public {
        vm.chainId(ARBITRUM_SEPOLIA);
        probe = new ChainProbe("hola desde L2");
    }

    // -------------------------------------------------------------------------
    // Constructor: el contrato recuerda en que red nacio
    // -------------------------------------------------------------------------

    function test_constructor_recordsChainAndDeployer() public view {
        assertEq(probe.deployedOnChainId(), ARBITRUM_SEPOLIA);
        assertEq(probe.deployer(), address(this));
        assertEq(probe.note(), "hola desde L2");
        assertEq(probe.lastWriter(), address(this));
    }

    function test_constructor_chainIdDependsOnNetwork() public {
        vm.chainId(SEPOLIA);
        ChainProbe onL1 = new ChainProbe("hola desde L1");
        assertEq(onL1.deployedOnChainId(), SEPOLIA);
        assertTrue(onL1.deployedOnChainId() != probe.deployedOnChainId());
    }

    // -------------------------------------------------------------------------
    // whereAmI: fuera de Arbitrum
    // -------------------------------------------------------------------------

    function test_whereAmI_withoutArbSys_isNotArbitrum() public {
        vm.chainId(SEPOLIA);
        vm.roll(9_000_000);
        (uint256 chainId, uint256 evmBlock, uint256 l2Block, bool isArbitrum) = probe.whereAmI();
        assertEq(chainId, SEPOLIA);
        assertEq(evmBlock, 9_000_000);
        assertEq(l2Block, 0);
        assertFalse(isArbitrum);
    }

    function test_whereAmI_revertingArbSys_isNotArbitrum() public {
        vm.etch(address(0x64), address(new RevertingArbSys()).code);
        (,, uint256 l2Block, bool isArbitrum) = probe.whereAmI();
        assertEq(l2Block, 0);
        assertFalse(isArbitrum);
    }

    // -------------------------------------------------------------------------
    // whereAmI: dentro de Arbitrum (ArbSys simulado)
    // -------------------------------------------------------------------------

    function test_whereAmI_withArbSys_separatesL1AndL2Blocks() public {
        vm.etch(address(0x64), address(new MockArbSys()).code);
        vm.roll(9_000_000); // en Arbitrum, block.number ~ bloque de L1

        (uint256 chainId, uint256 evmBlock, uint256 l2Block, bool isArbitrum) = probe.whereAmI();

        assertEq(chainId, ARBITRUM_SEPOLIA);
        assertTrue(isArbitrum);
        assertEq(evmBlock, 9_000_000);
        assertEq(l2Block, 123_456_789);
        assertTrue(l2Block != evmBlock, "L2 block and block.number are different clocks");
    }

    // -------------------------------------------------------------------------
    // Estado propio: writeNote
    // -------------------------------------------------------------------------

    function test_writeNote_updatesStateAndEmits() public {
        vm.expectEmit(true, false, false, true);
        emit NoteWritten(alice, "nuevo estado", ARBITRUM_SEPOLIA);

        vm.prank(alice);
        probe.writeNote("nuevo estado");

        assertEq(probe.note(), "nuevo estado");
        assertEq(probe.lastWriter(), alice);
    }

    // -------------------------------------------------------------------------
    // Activo nativo: receive, nativeBalance, sweep
    // -------------------------------------------------------------------------

    function test_receive_nativeBalanceIsProtocolBalance() public {
        vm.deal(alice, 1 ether);

        vm.expectEmit(true, false, false, true);
        emit NativeReceived(alice, 0.25 ether);

        vm.prank(alice);
        (bool ok,) = address(probe).call{value: 0.25 ether}("");
        assertTrue(ok);

        assertEq(probe.nativeBalance(), 0.25 ether);
        assertEq(address(probe).balance, probe.nativeBalance());
    }

    function test_sweep_returnsEverythingToDeployer() public {
        vm.deal(address(probe), 1 ether);
        uint256 before = address(this).balance;

        vm.expectEmit(true, false, false, true);
        emit NativeSwept(address(this), 1 ether);
        probe.sweep();

        assertEq(address(probe).balance, 0);
        assertEq(address(this).balance, before + 1 ether);
    }

    function test_sweep_revertsForNonDeployer() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ChainProbe.NotDeployer.selector, alice));
        probe.sweep();
    }

    function test_sweep_revertsWhenDeployerRejectsEth() public {
        RejectingDeployer rejecting = new RejectingDeployer();
        ChainProbe p = rejecting.deploy();
        vm.deal(address(p), 1 ether);

        vm.prank(address(rejecting));
        vm.expectRevert(ChainProbe.SweepFailed.selector);
        p.sweep();
    }

    receive() external payable {}
}
