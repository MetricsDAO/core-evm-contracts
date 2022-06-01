// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "@contracts/MetricToken.sol";
import "@contracts/Question/QuestionFactory.sol";
import "@contracts/Question/ClaimController.sol";
import "@contracts/Question/QuestionStateController.sol";
import "@contracts/Question/BountyQuestion.sol";

contract QuestionFactoryTest is DSTest {
    QuestionFactory _questionFactory;
    BountyQuestion _bountyQuestion;
    ClaimController _claimController;
    QuestionStateController _questionStateController;

    function setUp() public {
        _bountyQuestion = new BountyQuestion();
        _claimController = new ClaimController();
        _questionStateController = new QuestionStateController();
        _questionFactory = new QuestionFactory(address(_bountyQuestion), address(_questionStateController), address(_claimController));
    }

    function testInitialMint() public {
        // assertTrue(_metricToken.balanceOf(address(_vestingContract)) == 1000000000 * 10**18);
    }
}
