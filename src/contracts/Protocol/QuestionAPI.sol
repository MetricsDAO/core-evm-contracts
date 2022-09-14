//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

// Interfaces
import {IClaimController} from "./interfaces/IClaimController.sol";
import {IQuestionStateController} from "./interfaces/IQuestionStateController.sol";
import {IActionCostController} from "./interfaces/IActionCostController.sol";
import {IBountyQuestion} from "./interfaces/IBountyQuestion.sol";
import {IVault} from "./interfaces/IVault.sol";

// Enums
import {ACTION} from "./Enums/ActionEnum.sol";
import {STATE} from "./Enums/QuestionStateEnum.sol";
import {STAGE} from "./Enums/VaultEnum.sol";

// Events & Errors
import {ApiEventsAndErrors} from "./EventsAndErrors/ApiEventsAndErrors.sol";

// Modifiers
import "./modifiers/NFTLocked.sol";
import "./modifiers/FunctionLocked.sol";

/**
 * @title MetricsDAO question API
 * @author MetricsDAO team
 * @notice This contract is an API for MetricsDAO that allows for interacting with questions & challenges.
 */

contract QuestionAPI is Ownable, NFTLocked, FunctionLocked, ApiEventsAndErrors {
    IBountyQuestion private _question;
    IQuestionStateController private _questionStateController;
    IClaimController private _claimController;
    IActionCostController private _costController;
    IVault private _vault;
    address private _metricToken;

    //------------------------------------------------------ CONSTRUCTOR

    /**
     * @notice Constructor sets the question state controller, claim controller, and action cost controller.
     * @param bountyQuestion BountyQuestion contract instance.
     * @param questionStateController The question state controller address.
     * @param claimController The claim controller address.
     * @param costController The action cost controller address.
     * @param metricToken The address of the METRIC token.
     */
    constructor(
        address bountyQuestion,
        address questionStateController,
        address claimController,
        address costController,
        address metricToken,
        address vault
    ) {
        _question = IBountyQuestion(bountyQuestion);
        _questionStateController = IQuestionStateController(questionStateController);
        _claimController = IClaimController(claimController);
        _costController = IActionCostController(costController);
        _metricToken = metricToken;
        _vault = IVault(vault);
    }

    //------------------------------------------------------ FUNCTIONS

    /**
     * @notice Creates a question.
     * @param uri The IPFS hash of the question.
     * @return The question id
     */
    function createQuestion(string calldata uri) public returns (uint256) {
        // Mint a new question
        uint256 questionId = _question.mintQuestion(_msgSender(), uri);

        // Initialize the question
        _questionStateController.initializeQuestion(questionId);

        // Pay to create a question
        _costController.payForAction(_msgSender(), questionId, ACTION.CREATE);

        emit QuestionCreated(questionId, _msgSender());

        return questionId;
    }

    /**
     * @notice Creates a challenge.
     * @param uri The IPFS hash of the challenge.
     * @return The challenge id
     */
    function proposeChallenge(string calldata uri) public returns (uint256) {
        // Mint a new question
        uint256 questionId = _question.mintQuestion(_msgSender(), uri);

        // Initialize the question
        _questionStateController.initializeChallenge(questionId);

        // Burn METRIC
        _costController.burnForAction(_msgSender(), ACTION.CHALLENGE_BURN);

        emit ChallengeProposed(questionId, _msgSender());

        return questionId;
    }

    /**
     * @notice Directly creates a challenge, this is an optional feature for program managers that would like to create challenges directly (skipping the voting stage).
     * @param uri The IPFS hash of the challenge
     * @param claimLimit The limit for the amount of people that can claim the challenge
     * @param threshold The METRIC holding threshold required to claim the question.
     * @return questionId The question id
     */
    function createChallenge(
        string calldata uri,
        uint256 claimLimit,
        uint256 threshold
    ) public onlyHolder(PROGRAM_MANAGER_ROLE) returns (uint256) {
        // Mint a new question
        uint256 questionId = _question.mintQuestion(_msgSender(), uri);

        // Initialize the question
        _questionStateController.initializeQuestion(questionId);
        _claimController.initializeQuestion(questionId, claimLimit, threshold);

        // Publish the question
        _questionStateController.publishFromQuestion(questionId);

        emit ChallengeCreated(questionId, _msgSender());

        return questionId;
    }

    /**
     * @notice Upvotes a question.
     * @param questionId The questionId of the question to upvote.
     */
    function upvoteQuestion(uint256 questionId) public {
        if (_question.getAuthorOfQuestion(questionId) == _msgSender()) revert CannotVoteForOwnQuestion();

        // Vote for a question
        _questionStateController.voteFor(_msgSender(), questionId);

        // Pay to upvote a question
        _costController.payForAction(_msgSender(), questionId, ACTION.VOTE);

        emit QuestionUpvoted(questionId, _msgSender());
    }

    /**
     * @notice Unvotes a question.
     * @param questionId The questionId of the question to upvote.
     */
    function unvoteQuestion(uint256 questionId) public {
        _questionStateController.unvoteFor(_msgSender(), questionId);

        _vault.withdrawMetric(_msgSender(), questionId, STAGE.UNVOTE);

        emit QuestionUnvoted(questionId, _msgSender());
    }

    /**
     * @notice Publishes a question and allows it to be claimed and receive answers.
     * @param questionId The questionId of the question to publish
     * @param claimLimit The amount of claims per question.
     * @param threshold The METRIC holding threshold required to claim the question.
     */

    function publishQuestion(
        uint256 questionId,
        uint256 claimLimit,
        uint256 threshold
    ) public onlyHolder(ADMIN_ROLE) {
        // Publish the question
        _questionStateController.publishFromQuestion(questionId);
        _claimController.initializeQuestion(questionId, claimLimit, threshold);

        emit QuestionPublished(questionId, _msgSender());
    }

    function publishChallenge(
        uint256 questionId,
        uint256 claimLimit,
        uint256 threshold
    ) public onlyHolder(ADMIN_ROLE) {
        // Publish the question
        _questionStateController.publishFromChallenge(questionId);
        _claimController.initializeQuestion(questionId, claimLimit, threshold);

        emit QuestionPublished(questionId, _msgSender());
    }

    /**
     * @notice Allows anm analyst to claim a question and submit an answer before the dealine.
     * @param questionId The questionId of the question to disqualify
     */
    function claimQuestion(uint256 questionId) public {
        // Check if the question is published and is therefore claimable
        if (_questionStateController.getState(questionId) != STATE.PUBLISHED) revert ClaimsNotOpen();

        // Claim the question
        _claimController.claim(_msgSender(), questionId);

        // Pay for claiming a question
        _costController.payForAction(_msgSender(), questionId, ACTION.CLAIM);

        emit QuestionClaimed(questionId, _msgSender());
    }

    function releaseClaim(uint256 questionId) public {
        _claimController.releaseClaim(_msgSender(), questionId);

        _vault.withdrawMetric(_msgSender(), questionId, STAGE.RELEASE_CLAIM);
    }

    /**
     * @notice Allows a claimed question to be answered by an analyst.
     * @param questionId The questionId of the question to answer.
     * @param answerURL THE IPFS hash of the answer.
     */
    function answerQuestion(uint256 questionId, string calldata answerURL) public functionLocked {
        _claimController.answer(_msgSender(), questionId, answerURL);

        emit QuestionAnswered(questionId, _msgSender());
    }

    /**
     * @notice Allows the owner to disqualify a question.
     * @param questionId The questionId of the question to disqualify.
     */
    function disqualifyQuestion(uint256 questionId) public onlyOwner functionLocked {
        if (questionId > _question.getMostRecentQuestion()) revert QuestionDoesNotExist();
        _questionStateController.setDisqualifiedState(questionId);

        emit QuestionDisqualified(questionId, _msgSender());
    }

    function withdrawFromVault(uint256 questionId, STAGE stage) public {
        _vault.withdrawMetric(_msgSender(), questionId, stage);
    }

    // ------------------------------------------------------ VIEW FUNCTIONS

    function getMetricToken() public view returns (address) {
        return _metricToken;
    }

    function getQuestionStateController() public view returns (address) {
        return address(_questionStateController);
    }

    function getClaimController() public view returns (address) {
        return address(_claimController);
    }

    function getCostController() public view returns (address) {
        return address(_costController);
    }

    function getBountyQuestion() public view returns (address) {
        return address(_question);
    }

    //------------------------------------------------------ OWNER FUNCTIONS

    /**
     * @notice Allows the owner to set the BountyQuestion contract address.
     * @param newQuestion The address of the new BountyQuestion contract.
     */
    function setQuestionProxy(address newQuestion) public onlyOwner {
        if (newQuestion == address(0)) revert InvalidAddress();
        _question = IBountyQuestion(newQuestion);
    }

    /**
     * @notice Allows the owner to set the QuestionStateController contract address.
     * @param newQuestion The address of the new BountyQuestion contract.
     */
    function setQuestionStateController(address newQuestion) public onlyOwner {
        if (newQuestion == address(0)) revert InvalidAddress();
        _questionStateController = IQuestionStateController(newQuestion);
    }

    /**
     * @notice Allows the owner to set the ClaimController contract address.
     * @param newQuestion The address of the new ClaimController contract.
     */
    function setClaimController(address newQuestion) public onlyOwner {
        if (newQuestion == address(0)) revert InvalidAddress();
        _claimController = IClaimController(newQuestion);
    }

    /**
     * @notice Allows the owner to set the CostController contract address.
     * @param newCost The address of the new CostController contract.
     */
    function setCostController(address newCost) public onlyOwner {
        if (newCost == address(0)) revert InvalidAddress();
        _costController = IActionCostController(newCost);
    }

    function setMetrictoken(address newMetric) public onlyOwner {
        if (newMetric == address(0)) revert InvalidAddress();
        _metricToken = newMetric;
    }
}
