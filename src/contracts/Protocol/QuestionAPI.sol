//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./BountyQuestion.sol";

// Interfaces
import "./interfaces/IClaimController.sol";
import "./interfaces/IQuestionStateController.sol";
import "./interfaces/IActionCostController.sol";

// Enums
import "./Enums/ActionEnum.sol";
import "./Enums/QuestionStateEnum.sol";

// Modifiers
import "./modifiers/NFTLocked.sol";
import "./modifiers/FunctionLocked.sol";

/**
 * @title MetricsDAO question API
 * @author MetricsDAO team
 * @notice This contract is an API for MetricsDAO that allows for interacting with questions & challenges.
 */

contract QuestionAPI is Ownable, NFTLocked, FunctionLocked {
    BountyQuestion private _question;
    IQuestionStateController private _questionStateController;
    IClaimController private _claimController;
    IActionCostController private _costController;

    //------------------------------------------------------ ERRORS

    /// @notice Throw if analysts tries to claim a question that is not published.
    error ClaimsNotOpen();
    /// @notice Throw if a question has not reached the benchmark for being published (yet).
    error NotAtBenchmark();
    /// @notice Throw if address is equal to address(0).
    error InvalidAddress();
    /// @notice Throw if user tries to vote for own question
    error CannotVoteForOwnQuestion();

    //------------------------------------------------------ EVENTS

    /// @notice Emitted when a question is created.
    event QuestionCreated(uint256 indexed questionId, address indexed creator);

    /// @notice Emitted when a challenge is created.
    event ChallengeCreated(uint256 indexed questionId, address indexed challengeCreator);

    /// @notice Emitted when a question is published.
    event QuestionPublished(uint256 indexed questionId, address indexed publisher);

    /// @notice Emitted when a question is claimed.
    event QuestionClaimed(uint256 indexed questionId, address indexed claimant);

    /// @notice Emitted when a question is answered.
    event QuestionAnswered(uint256 indexed questionId, address indexed answerer);

    /// @notice Emitted when a question is disqualified.
    event QuestionDisqualified(uint256 indexed questionId, address indexed disqualifier);

    /// @notice Emitted when a question is upvoted.
    event QuestionUpvoted(uint256 indexed questionId, address indexed voter);

    /// @notice Emitted when a question is unvoted.
    event QuestionUnvoted(uint256 indexed questionId, address indexed voter);

    //------------------------------------------------------ CONSTRUCTOR

    /**
     * @notice Constructor sets the question state controller, claim controller, and action cost controller.
     * @param bountyQuestion BountyQuestion contract instance.
     * @param questionStateController The question state controller address.
     * @param claimController The claim controller address.
     * @param costController The action cost controller address.
     */
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

    //------------------------------------------------------ FUNCTIONS

    /**
     * @notice Creates a question.
     * @param uri The IPFS hash of the question.
     * @param claimLimit The limit for the amount of people that can claim the question.
     * @return The question id
     */
    function createQuestion(string calldata uri, uint256 claimLimit) public returns (uint256) {
        // Mint a new question
        uint256 questionId = _question.mintQuestion(_msgSender(), uri);

        // Pay to create a question
        _costController.payForAction(_msgSender(), questionId, ACTION.CREATE);

        // Initialize the question
        _questionStateController.initializeQuestion(questionId, uri);
        _claimController.initializeQuestion(questionId, claimLimit);

        emit QuestionCreated(questionId, _msgSender());

        return questionId;
    }

    /**
     * @notice Directly creates a challenge, this is an optional feature for program managers that would like to create challenges directly (skipping the voting stage).
     * @param uri The IPFS hash of the challenge
     * @param claimLimit The limit for the amount of people that can claim the challenge
     * @return questionId The question id
     */
    function createChallenge(string calldata uri, uint256 claimLimit) public onlyHolder(PROGRAM_MANAGER_ROLE) returns (uint256) {
        // Mint a new question
        uint256 questionId = _question.mintQuestion(_msgSender(), uri);

        // Initialize the question
        _questionStateController.initializeQuestion(questionId, uri);
        _claimController.initializeQuestion(questionId, claimLimit);

        // Publish the question
        _questionStateController.publish(questionId);

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

        emit QuestionUnvoted(questionId, _msgSender());
    }

    /**
     * @notice Publishes a question and allows it to be claimed and receive answers.
     * @param questionId The questionId of the question to publish
     */

    function publishQuestion(uint256 questionId) public onlyHolder(ADMIN_ROLE) functionLocked {
        // Publish the question
        _questionStateController.publish(questionId);

        emit QuestionPublished(questionId, _msgSender());
    }

    /**
     * @notice Allows anm analyst to claim a question and submit an answer before the dealine.
     * @param questionId The questionId of the question to disqualify
     */
    function claimQuestion(uint256 questionId) public functionLocked {
        // Check if the question is published and is therefore claimable
        if (_questionStateController.getState(questionId) != STATE.PUBLISHED) revert ClaimsNotOpen();

        // Claim the question
        _claimController.claim(_msgSender(), questionId);

        emit QuestionClaimed(questionId, _msgSender());
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
        _questionStateController.setDisqualifiedState(questionId);

        emit QuestionDisqualified(questionId, _msgSender());
    }

    //------------------------------------------------------ OWNER FUNCTIONS

    /**
     * @notice Allows the owner to set the BountyQuestion contract address.
     * @param newQuestion The address of the new BountyQuestion contract.
     */
    function setQuestionProxy(address newQuestion) public onlyOwner {
        if (newQuestion == address(0)) revert InvalidAddress();
        _question = BountyQuestion(newQuestion);
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
}
