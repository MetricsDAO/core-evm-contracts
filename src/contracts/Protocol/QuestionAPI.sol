//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./BountyQuestion.sol";
import "./interfaces/IClaimController.sol";
import "./interfaces/IQuestionStateController.sol";
import "../MetricToken.sol";

// TODO a lot of talk about "admins" -> solve that
contract QuestionAPI is Ownable {
    BountyQuestion private _question;
    IQuestionStateController private _questionStateController;
    IClaimController private _claimController;
    MetricToken private _metricToken;

    constructor(
        address metric,
        address bountyQuestion,
        address questionStateController,
        address claimController
    ) {
        _metricToken = MetricToken(metric);
        _question = BountyQuestion(bountyQuestion);
        _questionStateController = IQuestionStateController(questionStateController);
        _claimController = IClaimController(claimController);
        // TODO we probably want a CostController or something to ensure user locks enough metric
        // ^^ price per action, each one is editable
        // room for v2 CostController
        // room for v2 Questions (pre-Challenge)
    }

    // TODO admin-only quesiton state "BAD" which basically ends the lifecycle
    // TODO add "unvote"

    // TODO lock metric
    function createQuestion(string memory uri, uint256 claimLimit) public {
        uint256 newTokenId = _question.safeMint(_msgSender(), uri);
        _questionStateController.initializeQuestion(newTokenId);
        _claimController.initializeQuestion(newTokenId, claimLimit);
    }

    // TODO lock metric
    function upvoteQuestion(uint256 questionId, uint256 amount) public {
        _questionStateController.voteFor(questionId, amount);
    }

    error ClaimsNotOpen();

    // TODO lock metric
    function claimQuestion(uint256 questionId) public {
        // TODO it sucks to do an int state check here, and I don't want a getter for every state
        if (_questionStateController.getState(questionId) != 3) revert ClaimsNotOpen();

        _claimController.claim(questionId);
    }

    // TODO lock metric
    function answerQuestion(uint256 questionId, string calldata answerURL) public {
        _claimController.answer(questionId, answerURL);
    }

    //------------------------------------------------------ Proxy

    function setQuestionProxy(address newQuestion) public onlyOwner {
        _question = BountyQuestion(newQuestion);
    }

    function setQuestionStateController(address newQuestion) public onlyOwner {
        _questionStateController = IQuestionStateController(newQuestion);
    }

    function setClaimController(address newQuestion) public onlyOwner {
        _claimController = IClaimController(newQuestion);
    }

    function setMetricToken(address newMetric) public onlyOwner {
        _metricToken = MetricToken(newMetric);
    }
}
