// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../contracts/xMETRIC.sol";

/// @notice Throughout the contract we assume that Bob is the owner, Alice is any user
contract xMetricTest is Test {
    address alice = address(0xa);
    address bob = address(0xb);

    xMETRIC metricToken;

    function setUp() public {
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");

        vm.startPrank(bob);
        metricToken = new xMETRIC(1000000000 * 10**18);
        vm.stopPrank();
    }

    function testExample() public {
        assertTrue(true);
    }

    function test_GetTokenName() public {
        console.log("Test ERC20 initialization");
        assertEq(metricToken.symbol(), "xMETRIC");
    }

    function test_GetTokenSymbol() public {
        assertEq(metricToken.name(), "xMETRIC");
    }

    function test_GetTokenDecimals() public {
        assertEq(metricToken.decimals(), 18);
    }

    function test_CheckOwnerBalance() public {
        assertEq(metricToken.balanceOf(bob), 1000000000 * 10**18);
    }

    function test_BobIsOwnerAndAliceIsNot() public {
        vm.startPrank(bob);
        assertEq(metricToken.owner(), bob);
        vm.stopPrank();
    }

    function test_BobChangeOwner() public {
        vm.startPrank(bob);
        assertEq(metricToken.owner(), bob);

        metricToken.transferOwnership(alice);
        assertEq(metricToken.owner(), alice);
        vm.stopPrank();
    }

    function test_AliceChangeOwner() public {
        vm.startPrank(alice);
        assertEq(metricToken.owner(), bob);

        vm.expectRevert("Ownable: caller is not the owner");
        metricToken.transferOwnership(alice);
        vm.stopPrank();
    }

    function test_BobAddTransactor() public {
        // Bob should have permission to add a transactor
        vm.startPrank(bob);
        assertEq(metricToken.isTransactor(address(0x777)), false);
        metricToken.addTransactor(address(0x777));
        assertEq(metricToken.isTransactor(address(0x777)), true);
        vm.stopPrank();
    }

    function test_AliceCannotAddTransactor() public {
        // Alice should not have permission to add a transactor
        vm.startPrank(alice);
        assertEq(metricToken.isTransactor(address(0x777)), false);
        vm.expectRevert("Ownable: caller is not the owner");
        metricToken.addTransactor(address(0x777));
        assertEq(metricToken.isTransactor(address(0x777)), false);
        vm.stopPrank();
    }

    function test_BobCanTransact() public {
        // Bob sends money to alice
        vm.startPrank(bob);
        uint256 startBal = metricToken.balanceOf(bob);
        uint256 sendAmount = 10 * 10**18;
        metricToken.addTransactor(bob);
        metricToken.transfer(alice, sendAmount);
        assertEq(metricToken.balanceOf(alice), sendAmount);
        assertEq((startBal - sendAmount), metricToken.balanceOf(bob));
        vm.stopPrank();
    }

    function test_AliceCannotTransact() public {
        // Bob sends some money to alice
        vm.startPrank(bob);
        uint256 sendAmount = 10 * 10**18;
        metricToken.addTransactor(bob);
        metricToken.transfer(alice, sendAmount);
        vm.stopPrank();

        // Alice should not be able to transfer this out -- both through transfer and transferFrom
        vm.startPrank(alice);
        vm.expectRevert(xMETRIC.AddressCannotTransact.selector);

        // Through transfer
        metricToken.transfer(bob, sendAmount);

        // Through transferFrom
        metricToken.approve(address(0xa2), sendAmount);
        vm.stopPrank();

        vm.prank(address(0xa2));
        vm.expectRevert(xMETRIC.AddressCannotTransact.selector);
        metricToken.transferFrom(alice, bob, sendAmount);
    }

    function test_ChefCanTransact() public {
        // Bob send alice xMETRIC token. Alice cannot spend this. Bob adds chef contract as transactor. Alice approves chef contract as spender.
        // Chef contract is able to withdraw Alice's tokens (and for instance return token Y)
        vm.startPrank(bob);
        uint256 sendAmount = 10 * 10**18;
        metricToken.addTransactor(bob);
        metricToken.addTransactor(address(0xC));
        metricToken.transfer(alice, sendAmount);
        vm.stopPrank();

        // Approve chef contract
        vm.prank(alice);
        metricToken.approve(address(0xC), sendAmount);

        // Imitate the chef contract
        vm.prank(address(0xC));
        metricToken.transferFrom(alice, address(0xC), sendAmount);
        assertEq(metricToken.balanceOf(address(0xC)), sendAmount);
    }

    function test_mint() public {
        vm.startPrank(bob);
    }
}
