// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./Helpers/QuickSetup.sol";

contract XProtocolTest is QuickSetup {
    function setUp() public {}

    // ---------------------- General functionality testing

    function test_CreateMetricQuestion() public {
        console.log("Should correctly create a question using METRIC");
        quickSetup();

        vm.startPrank(other);
        // Create a question and see that it is created and balance is updated.
        assertEq(_metricToken.balanceOf(other), 100e18);
        _metricToken.approve(address(_vault), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");
        assertEq(_metricToken.balanceOf(other), 99e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(uint256(_questionStateController.getState(questionId)), uint256(STATE.VOTING));

        // Other cannot directly call onlyApi functions
        vm.expectRevert(OnlyApi.NotTheApi.selector);
        _costController.payForAction(other, questionId, ACTION.CREATE);

        vm.stopPrank();
    }

    function test_CreateXMetricQuestion() public {
        console.log("Should correctly create a question using XMetric");
        quickSetupXmetric();

        vm.startPrank(other);
        // Create a question and see that it is created and balance is updated.
        assertEq(_xmetric.balanceOf(other), 100e18);
        _xmetric.approve(address(_vault), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");
        assertEq(_xmetric.balanceOf(other), 99e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(uint256(_questionStateController.getState(questionId)), uint256(STATE.VOTING));

        // Other cannot directly call onlyApi functions
        vm.expectRevert(OnlyApi.NotTheApi.selector);
        _costController.payForAction(other, questionId, ACTION.CREATE);

        vm.stopPrank();
    }
    // --------------------- Testing for access controlls
}
