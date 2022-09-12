// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../Helpers/QuickSetup.sol";

contract CostControllerTest is QuickSetup {
    function setUp() public {
        quickSetup();
    }

    // ---------------------- General tests ----------------------

    function test_CreateTwoQuestionsWithChangingActionCost() public {
        console.log("Should correctly create 2 questions and do proper accounting.");

        vm.startPrank(other);
        // Create a question and see that it is created and balance is updated.
        assertEq(_metricToken.balanceOf(other), 100e18);
        uint256 questionIdOne = _questionAPI.createQuestion("ipfs://XYZ");
        assertEq(_metricToken.balanceOf(other), 99e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(uint256(_questionStateController.getState(questionIdOne)), uint256(STATE.VOTING));

        vm.stopPrank();

        // Update the costs of creating a question
        vm.prank(owner);
        _costController.setActionCost(ACTION.CREATE, 9e18);

        vm.startPrank(other);
        // Create a question and see that it is created and balance is updated.
        assertEq(_metricToken.balanceOf(other), 99e18);
        uint256 questionIdTwo = _questionAPI.createQuestion("ipfs://XYZ");
        assertEq(_metricToken.balanceOf(other), 90e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(uint256(_questionStateController.getState(questionIdTwo)), uint256(STATE.VOTING));

        // Assert that accounting has been done correctly
        assertEq(_vault.getLockedPerUser(other), 10e18);

        vm.stopPrank();
    }

    // ---------------------- Access control tests ----------------------

    function test_OnlyOwnerCanUpdateActionCosts() public {
        console.log("Should only allow the owner to update action costs.");

        vm.prank(other);
        vm.expectRevert("Ownable: caller is not the owner");
        _costController.setActionCost(ACTION.CREATE, 123e18);

        vm.prank(owner);
        _costController.setActionCost(ACTION.CREATE, 123e18);
    }

    function test_OnlyApiCanPay() public {
        console.log("Should only allow the API to interact with the contract.");

        vm.prank(other);
        vm.expectRevert(OnlyApi.NotTheApi.selector);
        _costController.payForAction(address(0), 1, ACTION.CREATE);
    }
}
