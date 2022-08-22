// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../../contracts/Xmetric.sol";

/// @notice Throughout the contract we assume that Bob is the owner, Alice is any user
contract xMetricTest is Test {
    address alice = address(0xa);
    address bob = address(0xb);

    Xmetric metricToken;

    function setUp() public {
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");

        vm.startPrank(bob);
        metricToken = new Xmetric();
        metricToken.transfer(bob, 1000000000e18);
        vm.stopPrank();
    }

    // ---------------------- General tests ----------------------
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

    function test_BobSetTransactor() public {
        // Bob should have permission to add a transactor
        vm.startPrank(bob);
        assertEq(metricToken.isTransactor(address(0x777)), false);
        metricToken.setTransactor(address(0x777), true);
        assertEq(metricToken.isTransactor(address(0x777)), true);
        vm.stopPrank();
    }

    function test_BobCanTransact() public {
        // Bob sends money to alice
        vm.startPrank(bob);
        uint256 startBal = metricToken.balanceOf(bob);
        uint256 sendAmount = 10e18;
        metricToken.setTransactor(bob, true);
        metricToken.transfer(alice, sendAmount);
        assertEq(metricToken.balanceOf(alice), sendAmount);
        assertEq((startBal), metricToken.balanceOf(bob));
        vm.stopPrank();
    }

    function test_ChefCanTransact() public {
        // Bob send alice Xmetric token. Alice cannot spend this. Bob adds chef contract as transactor. Alice approves chef contract as spender.
        // Chef contract is able to withdraw Alice's tokens (and for instance return token Y)
        vm.startPrank(bob);
        uint256 sendAmount = 10 * 10**18;
        metricToken.setTransactor(bob, true);
        metricToken.setTransactor(address(0xC), true);
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

    function test_AnyoneCanBurnTheirOwnTokens() public {
        vm.prank(bob);
        metricToken.transfer(alice, 100e18);
        // Alice burns her own tokens
        vm.startPrank(alice);
        uint256 startBal = metricToken.balanceOf(alice);
        uint256 burnAmount = 10e18;
        metricToken.burn(burnAmount);
        assertEq(metricToken.balanceOf(alice), startBal - burnAmount);
        vm.stopPrank();
    }

    function test_OwnerCanBurnEveryonesTokens() public {
        vm.prank(bob);
        metricToken.transfer(alice, 100e18);

        // Bob burns Alice's tokens
        vm.startPrank(bob);
        uint256 startBal = metricToken.balanceOf(alice);
        uint256 burnAmount = 10e18;
        metricToken.burnFrom(alice, burnAmount);
        assertEq(metricToken.balanceOf(alice), startBal - burnAmount);
        vm.stopPrank();
    }

    function test_ToggleTransactor() public {
        vm.startPrank(bob);
        metricToken.setTransactor(address(0x777), true);
        assertEq(metricToken.isTransactor(address(0x777)), true);
        metricToken.setTransactor(address(0x777), false);
        assertEq(metricToken.isTransactor(address(0x777)), false);
    }

    // ---------------------- Access control tests ----------------------

    function test_AliceCannotBurnBobsTokens() public {
        vm.prank(bob);
        metricToken.transfer(alice, 100e18);

        // Alice burns Bob's tokens
        vm.startPrank(alice);
        uint256 startBal = metricToken.balanceOf(bob);
        uint256 burnAmount = 10e18;
        vm.expectRevert("Ownable: caller is not the owner");
        metricToken.burnFrom(bob, burnAmount);
        assertEq(metricToken.balanceOf(bob), startBal);
        vm.stopPrank();
    }

    function test_AliceCannotTransact() public {
        // Bob sends some money to alice
        vm.startPrank(bob);
        uint256 sendAmount = 10 * 10**18;
        metricToken.setTransactor(bob, true);
        metricToken.transfer(alice, sendAmount);
        vm.stopPrank();

        // Alice should not be able to transfer this out -- both through transfer and transferFrom
        vm.startPrank(alice);
        vm.expectRevert(Xmetric.AddressCannotTransact.selector);

        // Through transfer
        metricToken.transfer(bob, sendAmount);

        // Through transferFrom
        metricToken.approve(address(0xa2), sendAmount);
        vm.stopPrank();

        vm.prank(address(0xa2));
        vm.expectRevert(Xmetric.AddressCannotTransact.selector);
        metricToken.transferFrom(alice, bob, sendAmount);

        vm.prank(bob);
        vm.expectRevert("ERC20: insufficient allowance");
        metricToken.transferFrom(alice, bob, sendAmount);
    }

    function test_AliceCannotSetTransactor() public {
        // Alice should not have permission to add a transactor
        vm.startPrank(alice);
        assertEq(metricToken.isTransactor(address(0x777)), false);
        vm.expectRevert("Ownable: caller is not the owner");
        metricToken.setTransactor(address(0x777), true);
        assertEq(metricToken.isTransactor(address(0x777)), false);
        vm.stopPrank();
    }
}
