pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../contracts/utils/RedBlack.sol";

contract RedBlackTest is Test {
    address owner = address(0x152314518);

    RedBlack redblack;

    function setUp() public {
        // Label addresses
        vm.label(owner, "Owner");

        vm.startPrank(owner);

        redblack = new RedBlack();
        vm.label(address(redblack), "redblack");

        vm.stopPrank();
    }

    function test_InsertAndRetrieve() public {
        console.log("Should be able to add and retrieve");

        uint256 first = 10;
        uint256 second = 20;
        uint256 third = 30;

        redblack.insert(first);
        redblack.insert(second);
        redblack.insert(third);

        assertEq(balanceChef, totalSupply);
    }
}
