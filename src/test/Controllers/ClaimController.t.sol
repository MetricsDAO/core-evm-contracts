// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../Helpers/QuickSetup.sol";

contract ClaimControllerTest is QuickSetup {
    function setUp() public {
        quickSetup();
    }

    // ---------------------- General tests ----------------------

    // ---------------------- Access control tests ----------------------

    function test_OnlyApiCanInteract() public {
        console.log("Should only allow the API to interact with the contract.");

        vm.prank(other);
        vm.expectRevert(OnlyApi.NotTheApi.selector);
        _claimController.initializeQuestion(1, 10, 10e18);

        vm.prank(other);
        vm.expectRevert(OnlyApi.NotTheApi.selector);
        _claimController.releaseClaim(address(0x0), 1);

        vm.prank(other);
        vm.expectRevert(OnlyApi.NotTheApi.selector);
        _claimController.claim(address(0x0), 1);
    }
}
