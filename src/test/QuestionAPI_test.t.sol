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
        //Deploy Metric
        _metricToken = new MetricToken();
        vm.label(address(_metricToken), "METRIC");
        //Fund Accounts
        _metricToken.transfer(owner, 10000e18);

        //Approve Metric Transfer
        _metricToken.approve(address(_actionCostController), _metricToken.balanceOf(owner));

        _actionCostController = new ActionCostController(address(_metricToken));
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
        vm.stopPrank();
    }

    function testInitialMint() public {
        // assertTrue(_metricToken.balanceOf(address(_vestingContract)) == 1000000000 * 10**18);
    }

    function testdisqualifyQuestion() public {
        vm.startPrank(owner);
        _actionCostController.payForCreateQuestion();
        badQuestion = _questionAPI.createQuestion("Bad question", 1);
        _questionAPI.disqualifyQuestion(badQuestion);
        questionState = _questionStateController.getState(badQuestion);
        //assert badQuestion state is BAD not sure what the value for question state should be yet
        assertEq(questionState, 5);
        vm.stopPrank();
    }
}
