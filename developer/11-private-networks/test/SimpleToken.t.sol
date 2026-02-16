// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {SimpleToken} from "../contracts/SimpleToken.sol";

contract SimpleTokenTest is Test {
    SimpleToken public token;

    address public deployer = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);

    uint256 public constant INITIAL_SUPPLY = 1_000_000 ether;
    string public constant NAME = "PrivateToken";
    string public constant SYMBOL = "PVTK";

    function setUp() public {
        vm.prank(deployer);
        token = new SimpleToken(NAME, SYMBOL, INITIAL_SUPPLY);
    }

    // -------------------------------------------------------
    // Constructor
    // -------------------------------------------------------

    function test_constructor_setsName() public view {
        assertEq(token.name(), NAME);
    }

    function test_constructor_setsSymbol() public view {
        assertEq(token.symbol(), SYMBOL);
    }

    function test_constructor_setsDecimals() public view {
        assertEq(token.decimals(), 18);
    }

    function test_constructor_setsOwner() public view {
        assertEq(token.owner(), deployer);
    }

    function test_constructor_mintsInitialSupply() public view {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY);
    }

    function test_constructor_zeroInitialSupply() public {
        SimpleToken zeroToken = new SimpleToken("Zero", "ZERO", 0);
        assertEq(zeroToken.totalSupply(), 0);
    }

    // -------------------------------------------------------
    // Transfer
    // -------------------------------------------------------

    function test_transfer_success() public {
        uint256 amount = 100 ether;
        vm.prank(deployer);
        bool success = token.transfer(alice, amount);

        assertTrue(success);
        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY - amount);
    }

    function test_transfer_emitsEvent() public {
        uint256 amount = 100 ether;
        vm.expectEmit(true, true, false, true);
        emit SimpleToken.Transfer(deployer, alice, amount);

        vm.prank(deployer);
        token.transfer(alice, amount);
    }

    function test_transfer_revertsOnInsufficientBalance() public {
        uint256 amount = INITIAL_SUPPLY + 1;
        vm.prank(deployer);
        vm.expectRevert(
            abi.encodeWithSelector(
                SimpleToken.InsufficientBalance.selector, INITIAL_SUPPLY, amount
            )
        );
        token.transfer(alice, amount);
    }

    function test_transfer_revertsOnZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert(SimpleToken.ZeroAddress.selector);
        token.transfer(address(0), 100);
    }

    function test_transfer_zeroAmount() public {
        vm.prank(deployer);
        bool success = token.transfer(alice, 0);
        assertTrue(success);
        assertEq(token.balanceOf(alice), 0);
    }

    // -------------------------------------------------------
    // Approve & TransferFrom
    // -------------------------------------------------------

    function test_approve_setsAllowance() public {
        uint256 amount = 500 ether;
        vm.prank(deployer);
        bool success = token.approve(alice, amount);

        assertTrue(success);
        assertEq(token.allowance(deployer, alice), amount);
    }

    function test_approve_emitsEvent() public {
        uint256 amount = 500 ether;
        vm.expectEmit(true, true, false, true);
        emit SimpleToken.Approval(deployer, alice, amount);

        vm.prank(deployer);
        token.approve(alice, amount);
    }

    function test_approve_revertsOnZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert(SimpleToken.ZeroAddress.selector);
        token.approve(address(0), 100);
    }

    function test_transferFrom_success() public {
        uint256 approveAmount = 500 ether;
        uint256 transferAmount = 200 ether;

        vm.prank(deployer);
        token.approve(alice, approveAmount);

        vm.prank(alice);
        bool success = token.transferFrom(deployer, bob, transferAmount);

        assertTrue(success);
        assertEq(token.balanceOf(bob), transferAmount);
        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY - transferAmount);
        assertEq(token.allowance(deployer, alice), approveAmount - transferAmount);
    }

    function test_transferFrom_revertsOnInsufficientAllowance() public {
        uint256 approveAmount = 100 ether;
        uint256 transferAmount = 200 ether;

        vm.prank(deployer);
        token.approve(alice, approveAmount);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                SimpleToken.InsufficientAllowance.selector, approveAmount, transferAmount
            )
        );
        token.transferFrom(deployer, bob, transferAmount);
    }

    // -------------------------------------------------------
    // Mint
    // -------------------------------------------------------

    function test_mint_success() public {
        uint256 amount = 500 ether;
        vm.prank(deployer);
        token.mint(alice, amount);

        assertEq(token.balanceOf(alice), amount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + amount);
    }

    function test_mint_emitsMintEvent() public {
        uint256 amount = 500 ether;
        vm.expectEmit(true, false, false, true);
        emit SimpleToken.Mint(alice, amount);

        vm.prank(deployer);
        token.mint(alice, amount);
    }

    function test_mint_revertsForNonOwner() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(SimpleToken.Unauthorized.selector, alice)
        );
        token.mint(alice, 100 ether);
    }

    function test_mint_revertsOnZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert(SimpleToken.ZeroAddress.selector);
        token.mint(address(0), 100 ether);
    }

    // -------------------------------------------------------
    // Burn
    // -------------------------------------------------------

    function test_burn_success() public {
        uint256 burnAmount = 100 ether;
        vm.prank(deployer);
        token.burn(burnAmount);

        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY - burnAmount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - burnAmount);
    }

    function test_burn_emitsBurnEvent() public {
        uint256 amount = 100 ether;
        vm.expectEmit(true, false, false, true);
        emit SimpleToken.Burn(deployer, amount);

        vm.prank(deployer);
        token.burn(amount);
    }

    function test_burn_revertsOnInsufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(SimpleToken.InsufficientBalance.selector, 0, 100)
        );
        token.burn(100);
    }

    // -------------------------------------------------------
    // Integration scenarios
    // -------------------------------------------------------

    function test_scenario_transferChain() public {
        uint256 amount = 100 ether;

        // deployer -> alice -> bob
        vm.prank(deployer);
        token.transfer(alice, amount);

        vm.prank(alice);
        token.transfer(bob, amount);

        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY - amount);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), amount);
    }

    function test_scenario_mintAndBurn() public {
        uint256 mintAmount = 500 ether;
        uint256 burnAmount = 200 ether;

        vm.startPrank(deployer);
        token.mint(alice, mintAmount);
        vm.stopPrank();

        vm.prank(alice);
        token.burn(burnAmount);

        assertEq(token.balanceOf(alice), mintAmount - burnAmount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + mintAmount - burnAmount);
    }
}
