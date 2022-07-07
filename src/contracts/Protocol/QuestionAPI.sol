//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./BountyQuestion.sol";
import "./BountyChallenge.sol";
import "./interfaces/IClaimController.sol";
import "./interfaces/IQuestionStateController.sol";
import "./interfaces/IActionCostController.sol";
import "../MetricToken.sol";

// TODO a lot of talk about "admins" -> solve that
contract QuestionAPI is Ownable {
    BountyQuestion private _question;
    BountyChallenge private _challenge;
    IQuestionStateController private _questionStateController;
    IClaimController private _claimController;
    IActionCostController private _costController;
    MetricToken private _metricToken;

    constructor(
        address metric,
        address bountyQuestion,
        address questionStateController,
        address claimController,
        address costController
    ) {
        _metricToken = MetricToken(metric);
        _question = BountyQuestion(bountyQuestion);
        _questionStateController = IQuestionStateController(questionStateController);
        _claimController = IClaimController(claimController);
        _costController = IActionCostController(costController);
    }

    // TODO admin-only quesiton state "BAD" which basically ends the lifecycle
    // TODO add "unvote"

    // TODO lock metric
    // uint8?

    /**
     * @notice Creates a question
     * @param uri The IPFS hash of the question
     * @param claimLimit The limit for the amount of people that can claim the question
     * @return The question id
     */
    function createQuestion(string calldata uri, uint256 claimLimit) public returns (uint256) {
        // Pay to create a question
        _costController.payForCreateQuestion(msg.sender);

        // Mint a new question
        uint256 questionId = _question.safeMint(_msgSender(), uri);

        // Initialize the question
        _questionStateController.initializeQuestion(questionId);
        _claimController.initializeQuestion(questionId, claimLimit);

        return questionId;
    }

    // TODO lock metric
    /**
     * @notice Upvotes a question
     * @param questionId The questionId of the question to upvote
     * @param amount Metric amount to put behind the vote
     * We can manipulate this very easily -- think of a way to make it secure
     */
    function upvoteQuestion(uint256 questionId, uint256 amount) public {
        if (_questionStateController.getState(questionId) == uint256(IQuestionStateController.STATE.DRAFT)) {
            _questionStateController.readyForVotes(questionId);
        }
        _questionStateController.voteFor(questionId, amount);
    }

    // TODO lock metric
    function claimQuestion(uint256 questionId) public {
        // TODO it sucks to do an int state check here, and I don't want a getter for every state
        if (_questionStateController.getState(questionId) != uint256(IQuestionStateController.STATE.PUBLISHED)) revert ClaimsNotOpen();

        _claimController.claim(questionId);
    }

    // TODO lock metric
    function answerQuestion(uint256 questionId, string calldata answerURL) public {
        _claimController.answer(questionId, answerURL);
    }

    /**
     * @notice Changes the cost of creating a question
     * @param cost The new cost of creating a question
     */
    function setCreateCost(uint256 cost) public onlyOwner {
        _costController.setCreateCost(cost);
    }

    //------------------------------------------------------ Errors
    error ClaimsNotOpen();

    //------------------------------------------------------ Proxy

    function setQuestionProxy(address newQuestion) public onlyOwner {
        _question = BountyQuestion(newQuestion);
    }

    function setChallengeProxy(address newChallenge) public onlyOwner {
        _challenge = BountyChallenge(newChallenge);
    }

    function setQuestionStateController(address newQuestion) public onlyOwner {
        _questionStateController = IQuestionStateController(newQuestion);
    }

    function setClaimController(address newQuestion) public onlyOwner {
        _claimController = IClaimController(newQuestion);
    }

    function setCostController(address newCost) public onlyOwner {
        _costController = IActionCostController(newCost);
    }

    function setMetricToken(address newMetric) public onlyOwner {
        _metricToken = MetricToken(newMetric);
    }
}
