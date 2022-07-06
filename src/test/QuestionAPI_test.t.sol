// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "@contracts/MetricToken.sol";
import "@contracts/Protocol/QuestionAPI.sol";
import "@contracts/Protocol/ClaimController.sol";
import "@contracts/Protocol/QuestionStateController.sol";
import "@contracts/Protocol/BountyQuestion.sol";
import "@contracts/Protocol/ActionCostController.sol";

contract QuestionAPITest is DSTest {
    MetricToken _metricToken;
    QuestionAPI _questionAPI;
    BountyQuestion _bountyQuestion;
    ClaimController _claimController;
    QuestionStateController _questionStateController;
    ActionCostController _actionCostController;

    function setUp() public {
        _metricToken = new MetricToken();
        _bountyQuestion = new BountyQuestion();
        _claimController = new ClaimController();
        _questionStateController = new QuestionStateController();
        _actionCostController = new ActionCostController(address(_metricToken));
        _questionAPI = new QuestionAPI(
            address(_metricToken),
            address(_bountyQuestion),
            address(_questionStateController),
            address(_claimController),
            address(_actionCostController)
        );
    }

    function testInitialMint() public {
        // assertTrue(_metricToken.balanceOf(address(_vestingContract)) == 1000000000 * 10**18);
    }

    function testdisqualifyQuestion(uint256 questionId) public onlyOwner {}
}
