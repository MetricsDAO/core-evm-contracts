// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "@contracts/MetricToken.sol";
import "@contracts/Xmetric.sol";
import "@contracts/Protocol/QuestionAPI.sol";
import "@contracts/Protocol/ClaimController.sol";
import "@contracts/Protocol/QuestionStateController.sol";
import "@contracts/Protocol/BountyQuestion.sol";
import "@contracts/Protocol/ActionCostController.sol";

contract XProtocolTest is Test {
    // Accounts
    address owner = address(0x0a);
    address other = address(0x0b);

    MetricToken _metricToken;
    Xmetric _xMetric;

    QuestionAPI _questionAPI;
    BountyQuestion _bountyQuestion;
    ClaimController _claimController;
    ActionCostController _costController;
    QuestionStateController _questionStateController;

    function setUp() public {
        // Labeling
        vm.label(owner, "Owner");
        vm.label(other, "User");
    }

    function setUpXMetric() public {
        vm.startPrank(owner);
        _xMetric = new Xmetric();
        _bountyQuestion = new BountyQuestion();
        _claimController = new ClaimController();
        _questionStateController = new QuestionStateController();
        _costController = new ActionCostController(address(_xMetric));
        _questionAPI = new QuestionAPI(
            address(_bountyQuestion),
            address(_questionStateController),
            address(_claimController),
            address(_costController)
        );

        _claimController.setQuestionApi(address(_questionAPI));
        _costController.setQuestionApi(address(_questionAPI));
        _questionStateController.setQuestionApi(address(_questionAPI));
        _bountyQuestion.setQuestionApi(address(_questionAPI));

        _xMetric.setTransactor(address(_costController), true);
        _xMetric.transfer(other, 100e18);

        vm.stopPrank();
    }

    function setupMetric() public {
        vm.startPrank(owner);
        _metricToken = new MetricToken();
        _bountyQuestion = new BountyQuestion();
        _claimController = new ClaimController();
        _questionStateController = new QuestionStateController();
        _costController = new ActionCostController(address(_metricToken));
        _questionAPI = new QuestionAPI(
            address(_bountyQuestion),
            address(_questionStateController),
            address(_claimController),
            address(_costController)
        );

        _claimController.setQuestionApi(address(_questionAPI));
        _costController.setQuestionApi(address(_questionAPI));
        _questionStateController.setQuestionApi(address(_questionAPI));
        _bountyQuestion.setQuestionApi(address(_questionAPI));

        _metricToken.transfer(other, 100e18);
        vm.stopPrank();
    }

    // ---------------------- General functionality testing

    function test_CreateMetricQuestion() public {
        console.log("Should correctly create a question using METRIC");
        setupMetric();

        vm.startPrank(other);
        // Create a question and see that it is created and balance is updated.
        assertEq(_metricToken.balanceOf(other), 100e18);
        _metricToken.approve(address(_costController), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ", 25);
        assertEq(_metricToken.balanceOf(other), 99e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(_questionStateController.getState(questionId), uint256(IQuestionStateController.STATE.VOTING));
        assertEq(_claimController.getClaimLimit(questionId), 25);

        // Other cannot directly call onlyApi functions
        vm.expectRevert(OnlyApi.NotTheApi.selector);
        _costController.payForCreateQuestion(other);

        vm.stopPrank();
    }

    function test_CreateXMetricQuestion() public {
        console.log("Should correctly create a question using XMetric");
        setUpXMetric();

        vm.startPrank(other);
        // Create a question and see that it is created and balance is updated.
        assertEq(_xMetric.balanceOf(other), 100e18);
        _xMetric.approve(address(_costController), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ", 25);
        assertEq(_xMetric.balanceOf(other), 99e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(_questionStateController.getState(questionId), uint256(IQuestionStateController.STATE.VOTING));
        assertEq(_claimController.getClaimLimit(questionId), 25);

        // Other cannot directly call onlyApi functions
        vm.expectRevert(OnlyApi.NotTheApi.selector);
        _costController.payForCreateQuestion(other);

        vm.stopPrank();
    }

    // --------------------- Testing for access controlls
}
