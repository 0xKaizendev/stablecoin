// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {NexusCoin} from "../../src/NexusCoin.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract NexusCoinTest is Test {
    NexusCoin public nexusCoin;
    address public owner;
    address public user = address(0x123);

    function setUp() public {
        nexusCoin = new NexusCoin();
        owner = nexusCoin.owner();
    }

    // Initial state tests
    function testInitialState() public view {
        assertEq(nexusCoin.name(), "NexusCoin");
        assertEq(nexusCoin.symbol(), "NEX");
        assertEq(nexusCoin.decimals(), 18);
        assertEq(nexusCoin.totalSupply(), 0);
        assertEq(nexusCoin.owner(), address(this));
    }

    // Mint tests
    function testNonOwnerCannotMint() public {
        address nonOwner = address(0x123);
        vm.prank(nonOwner);
        vm.expectRevert();
        nexusCoin.mint(address(this), 100);
    }

    function testMustMintMoreThanZero() public {
        vm.prank(nexusCoin.owner());
        vm.expectRevert();
        nexusCoin.mint(address(this), 0);
    }

    function testCanMintToAZeroddress() public {
        vm.prank(nexusCoin.owner());
        vm.expectRevert();
        nexusCoin.mint(address(0), 100);
    }

    function testCanMintToValidAddress() public {
        vm.prank(nexusCoin.owner());
        nexusCoin.mint(address(this), 100);
        assertEq(nexusCoin.balanceOf(address(this)), 100);
        assertEq(nexusCoin.totalSupply(), 100);
    }

    function testMintEmitsTransferEvent() public {
        vm.prank(nexusCoin.owner());
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), user, 100);
        nexusCoin.mint(user, 100);
    }

    function testMultipleMints() public {
        vm.startPrank(nexusCoin.owner());
        nexusCoin.mint(user, 100);
        nexusCoin.mint(address(this), 200);
        vm.stopPrank();

        assertEq(nexusCoin.balanceOf(user), 100);
        assertEq(nexusCoin.balanceOf(address(this)), 200);
        assertEq(nexusCoin.totalSupply(), 300);
    }

    // Burn tests
    function testNonOwnerCannotBurn() public {
        // First mint some tokens to the owner
        vm.prank(nexusCoin.owner());
        nexusCoin.mint(nexusCoin.owner(), 100);

        // Try to burn as non-owner
        vm.prank(user);
        vm.expectRevert();
        nexusCoin.burn(50);
    }

    function testMustBurnMoreThanZero() public {
        vm.prank(nexusCoin.owner());
        vm.expectRevert();
        nexusCoin.burn(0);
    }

    function testBurnMoreThanBalance() public {
        vm.prank(nexusCoin.owner());
        nexusCoin.mint(nexusCoin.owner(), 100);
        vm.expectRevert();
        nexusCoin.burn(101);
    }

    function testCanBurnValidAmount() public {
        vm.startPrank(nexusCoin.owner());
        nexusCoin.mint(nexusCoin.owner(), 100);

        uint256 balanceBefore = nexusCoin.balanceOf(nexusCoin.owner());
        uint256 totalSupplyBefore = nexusCoin.totalSupply();

        nexusCoin.burn(50);

        assertEq(nexusCoin.balanceOf(nexusCoin.owner()), balanceBefore - 50);
        assertEq(nexusCoin.totalSupply(), totalSupplyBefore - 50);
        vm.stopPrank();
    }

    function testBurnExactBalance() public {
        vm.startPrank(nexusCoin.owner());
        nexusCoin.mint(nexusCoin.owner(), 100);
        nexusCoin.burn(100);

        assertEq(nexusCoin.balanceOf(nexusCoin.owner()), 0);
        assertEq(nexusCoin.totalSupply(), 0);
        vm.stopPrank();
    }

    function testBurnEmitsTransferEvent() public {
        vm.startPrank(nexusCoin.owner());
        nexusCoin.mint(nexusCoin.owner(), 100);

        vm.expectEmit(true, true, false, true);
        emit Transfer(nexusCoin.owner(), address(0), 50);
        nexusCoin.burn(50);
        vm.stopPrank();
    }

    function testMultipleBurns() public {
        vm.startPrank(nexusCoin.owner());
        nexusCoin.mint(nexusCoin.owner(), 300);

        nexusCoin.burn(100);
        assertEq(nexusCoin.balanceOf(nexusCoin.owner()), 200);
        assertEq(nexusCoin.totalSupply(), 200);

        nexusCoin.burn(50);
        assertEq(nexusCoin.balanceOf(nexusCoin.owner()), 150);
        assertEq(nexusCoin.totalSupply(), 150);
        vm.stopPrank();
    }

    // Combined mint and burn tests
    function testMintAndBurnCycle() public {
        vm.startPrank(nexusCoin.owner());

        // Mint tokens
        nexusCoin.mint(nexusCoin.owner(), 1000);
        assertEq(nexusCoin.totalSupply(), 1000);

        // Burn some tokens
        nexusCoin.burn(300);
        assertEq(nexusCoin.totalSupply(), 700);

        // Mint more tokens
        nexusCoin.mint(user, 200);
        assertEq(nexusCoin.totalSupply(), 900);
        assertEq(nexusCoin.balanceOf(user), 200);

        vm.stopPrank();
    }

    // Custom error tests with specific error matching
    function testBurnAmountMustBeGreaterThanZeroError() public {
        vm.prank(nexusCoin.owner());
        vm.expectRevert(
            NexusCoin.NexusCoin__BurnAmountMustBeGreaterThanZero.selector
        );
        nexusCoin.burn(0);
    }

    function testBurnAmountExceedsBalanceError() public {
        vm.startPrank(nexusCoin.owner());
        nexusCoin.mint(nexusCoin.owner(), 100);
        vm.expectRevert(NexusCoin.NexusCoin__BurnAmountExceedsBalance.selector);
        nexusCoin.burn(101);
        vm.stopPrank();
    }

    function testMintToZeroAddressError() public {
        vm.prank(nexusCoin.owner());
        vm.expectRevert(NexusCoin.NexusCoin__MintToZeroAddress.selector);
        nexusCoin.mint(address(0), 100);
    }

    function testMintAmountMustBeGreaterThanZeroError() public {
        vm.prank(nexusCoin.owner());
        vm.expectRevert(
            NexusCoin.NexusCoin__MintAmountMustBeGreaterThanZero.selector
        );
        nexusCoin.mint(address(this), 0);
    }

    // Events (need to declare them for expectEmit)
    event Transfer(address indexed from, address indexed to, uint256 value);
}
