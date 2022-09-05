// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../Helpers/QuickSetup.sol";

contract CostControllerTest is QuickSetup {
    function setUp() public {
        quickSetup();
    }

    // ---------------------- General tests ----------------------

    // ---------------------- Access control tests ----------------------
    function test_OnlyApiCanInteractWithPublicFunctions() public {
        console.log("Should only allow the API to interact with the public functions of the contract.");

        vm.prank(other);
        vm.expectRevert(OnlyApi.NotTheApi.selector);
        _questionStateController.initializeQuestion(1);

        vm.prank(other);
        vm.expectRevert(OnlyApi.NotTheApi.selector);
        _questionStateController.publishFromQuestion(1);

        vm.prank(other);
        vm.expectRevert(OnlyApi.NotTheApi.selector);
        _questionStateController.voteFor(address(0), 1);

        vm.prank(other);
        vm.expectRevert(OnlyApi.NotTheApi.selector);
        _questionStateController.unvoteFor(address(0), 1);

        vm.prank(other);
        vm.expectRevert(OnlyApi.NotTheApi.selector);
        _questionStateController.setDisqualifiedState(1);
    }
}
