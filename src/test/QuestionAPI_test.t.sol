// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Vm.sol";
import "forge-std/Test.sol";
import "@contracts/MetricToken.sol";
import "@contracts/Protocol/QuestionAPI.sol";
import "@contracts/Protocol/ClaimController.sol";
import "@contracts/Protocol/QuestionStateController.sol";
import "@contracts/Protocol/BountyQuestion.sol";
import "@contracts/Protocol/ActionCostController.sol";

contract QuestionAPITest is Test {
    // Accounts
    address owner = address(0x152314518);
    address alice = address(0xa);

    uint256 badQuestion;
    uint256 questionState;

    MetricToken _metricToken;
    QuestionAPI _questionAPI;
    BountyQuestion _bountyQuestion;
    ClaimController _claimController;
    QuestionStateController _questionStateController;
    ActionCostController _actionCostController;

    function setUp() public {
        // Label addresses
        vm.label(owner, "Owner");
        vm.label(alice, "Alice");

        vm.startPrank(owner);
        //Deploy Metric and controllers
        _metricToken = new MetricToken();
        vm.label(address(_metricToken), "METRIC");
        _actionCostController = new ActionCostController(address(_metricToken));
        _metricToken.approve(address(_actionCostController), _metricToken.balanceOf(owner));
        _bountyQuestion = new BountyQuestion();
        _claimController = new ClaimController();
        _questionStateController = new QuestionStateController();
        _questionAPI = new QuestionAPI(
            address(_metricToken),
            address(_bountyQuestion),
            address(_questionStateController),
            address(_claimController),
            address(_actionCostController)
        );
        //fund questionApi so it can pay for question creation TODO: this needs to change
        _metricToken.transfer(address(_questionAPI), 100e18);
        vm.stopPrank();

        vm.startPrank(address(_questionAPI));
        _metricToken.approve(address(_actionCostController), _metricToken.balanceOf(address(_questionAPI)));
        vm.stopPrank();

        vm.startPrank(owner);
        //transfer ownership so that onlyowner functions can be called
        _actionCostController.transferOwnership(address(_questionAPI));
        _questionStateController.transferOwnership(address(_questionAPI));
        _claimController.transferOwnership(address(_questionAPI));
        _bountyQuestion.transferOwnership(address(_questionAPI));
        vm.stopPrank();
    }

    function testInitialMint() public {
        //     // assertTrue(_metricToken.balanceOf(address(_vestingContract)) == 1000000000 * 10**18);
    }

    //TODO change the caller for payForCreation from questionAPI

    function testdisqualifyQuestion() public {
        vm.startPrank(owner);
        badQuestion = _questionAPI.createQuestion("Bad question", 1);
        _questionAPI.disqualifyQuestion(badQuestion);
        questionState = _questionStateController.getState(badQuestion);
        assertEq(questionState, 7);
        vm.stopPrank();
    }
}
