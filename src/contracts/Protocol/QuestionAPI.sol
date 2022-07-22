//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./BountyQuestion.sol";
import "./interfaces/IClaimController.sol";
import "./interfaces/IQuestionStateController.sol";
import "./interfaces/IActionCostController.sol";
import "./modifiers/NFTLocked.sol";

// TODO a lot of talk about "admins" -> solve that
contract QuestionAPI is Ownable, NFTLocked {
    BountyQuestion private _question;
    IQuestionStateController private _questionStateController;
    IClaimController private _claimController;
    IActionCostController private _costController;

    uint256 public currentQuestionId;

    constructor(
        address bountyQuestion,
        address questionStateController,
        address claimController,
        address costController
    ) {
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
        _costController.payForCreateQuestion(_msgSender());

        // Mint a new question
        uint256 questionId = _question.mintQuestion(_msgSender(), uri);

        // Initialize the question
        _questionStateController.initializeQuestion(questionId, uri);
        _claimController.initializeQuestion(questionId, claimLimit);
        currentQuestionId = questionId;
        return questionId;
    }

    /**
     * @notice Directly creates a challenge, this is an optional feature for program managers that would like to create challenges directly (skipping the voting stage).
     * @param uri The IPFS hash of the challenge
     * @param claimLimit The limit for the amount of people that can claim the challenge
     * @return questionId The question id
     */
    function createChallenge(string calldata uri, uint256 claimLimit) public onlyHolder(PROGRAM_MANAGER_ROLE) returns (uint256) {
        // Pay to create a question
        // _costController.payForCreateChallenge(msg.sender); ? Not sure if we want this -- doubt it
        // keep as questionId or should be challengeId?

        // Mint a new question
        uint256 questionId = _question.mintQuestion(_msgSender(), uri);

        // Initialize the question
        _questionStateController.initializeQuestion(questionId, uri);
        _claimController.initializeQuestion(questionId, claimLimit);

        // Publish the question (make it a challenge)
        _questionStateController.publish(questionId);

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
        _questionStateController.voteFor(_msgSender(), questionId, amount);
    }

    /**
     * @notice Unvotes a question
     * @param questionId The questionId of the question to upvote
     */
    function unvoteQuestion(uint256 questionId) public {
        _questionStateController.unvoteFor(_msgSender(), questionId);
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

    function disqualifyQuestion(uint256 questionId) public onlyOwner {
        _questionStateController.setDisqualifiedState(questionId);
    }

    //------------------------------------------------------ Errors
    error ClaimsNotOpen();

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

    function setCostController(address newCost) public onlyOwner {
        _costController = IActionCostController(newCost);
    }
}
