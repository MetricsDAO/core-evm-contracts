//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

// Interfaces
import "./interfaces/IQuestionStateController.sol";
import "./interfaces/IBountyQuestion.sol";

// Enums
import "./Enums/QuestionStateEnum.sol";

// Structs
import "./Structs/QuestionData.sol";

// Modifiers
import "./modifiers/OnlyAPI.sol";

contract QuestionStateController is IQuestionStateController, Ownable, OnlyApi {
    // Mapping for all questions that are upvoted by the user?
    mapping(address => mapping(uint256 => bool)) public hasVoted;
    // TODO rename this to be more clear
    mapping(address => mapping(uint256 => uint256)) public questionIndex;
    mapping(uint256 => QuestionStats) public questionByState;

    mapping(STATE => uint256[]) public questionIDByState;
    mapping(STATE => mapping(uint256 => uint256)) public questionIndexgsByIDByState;

    IBountyQuestion private _bountyQuestion;

    // TODO do we want user to lose their metric if a question is closed? they voted on somethjing bad

    constructor(address bountyQuestion) {
        _bountyQuestion = IBountyQuestion(bountyQuestion);
    }

    /**
     * @notice Initializes a question to draft.
     * @param questionId The id of the question
     */
    function initializeQuestion(uint256 questionId, string calldata uri) public onlyApi {
        QuestionStats memory question;

        question.questionId = questionId;
        question.uri = uri;
        question.totalVotes = 1;
        question.questionState = STATE.VOTING;

        questionByState[questionId] = question;
    }

    function publish(uint256 questionId) public onlyApi onlyState(STATE.VOTING, questionId) {
        // if some voting barrier is passed, we can publish the question
        QuestionStats storage _question = questionByState[questionId];
        _question.questionState = STATE.PUBLISHED;
    }

    function voteFor(address _user, uint256 questionId) public onlyApi onlyState(STATE.VOTING, questionId) {
        // Checks
        if (hasVoted[_user][questionId]) revert HasAlreadyVotedForQuestion();

        // Effects
        QuestionStats storage _question = questionByState[questionId];
        _question.totalVotes += 1;

        hasVoted[_user][questionId] = true;
        _question.voters.push(_user);
        questionIndex[_user][questionId] = _question.voters.length - 1;

        // Interactions
    }

    function unvoteFor(address _user, uint256 questionId) public onlyApi onlyState(STATE.VOTING, questionId) {
        // Checks
        if (!hasVoted[_user][questionId]) revert HasNotVotedForQuestion();

        // Effects
        QuestionStats storage _question = questionByState[questionId];
        _question.totalVotes -= 1;

        uint256 index = questionIndex[_user][questionId];
        delete _question.voters[index];

        hasVoted[_user][questionId] = false;

        // Interactions
    }

    function setDisqualifiedState(uint256 questionId) public onlyApi {
        QuestionStats storage _question = questionByState[questionId];
        _question.questionState = STATE.DISQUALIFIED;
    }

    // TODO batch voting and batch operations and look into arrays as parameters security risk

    //------------------------------------------------------ View Functions

    function getState(uint256 questionId) public view returns (STATE currentState) {
        // return _bountyQuestion.getQuestionData(questionId).questionState;
        QuestionStats memory _question = questionByState[questionId];
        return _question.questionState;
    }

    function getVoters(uint256 questionId) public view returns (address[] memory voters) {
        QuestionStats memory _question = questionByState[questionId];
        return _question.voters;
    }

    function getTotalVotes(uint256 questionId) public view returns (uint256) {
        QuestionStats memory _question = questionByState[questionId];
        return _question.totalVotes;
    }

    function getHasUserVoted(address user, uint256 questionId) external view returns (bool) {
        return hasVoted[user][questionId];
    }

    function getQuestions(
        STATE state,
        uint256 offset,
        uint256 limit
    ) public view returns (QuestionData[] memory questions) {
        uint256 highestQuestion = _bountyQuestion.getMostRecentQuestion();
        if (limit > highestQuestion) limit = highestQuestion;
        if (offset > highestQuestion) offset = highestQuestion;

        uint256[] storage stateIds = questionIDByState[state];
        questions = new QuestionData[](limit);

        for (uint256 i = 0; i < limit; i++) {
            questions[i] = _bountyQuestion.getQuestionData(stateIds[offset + i]);
        }

        return questions;
    }

    function getQuestionsByState(
        STATE currentState,
        uint256 currentQuestionId,
        uint256 offset
    ) public view returns (QuestionStats[] memory) {
        uint256 j = 0;
        uint256 limit;
        uint256 sizeOfArray;
        currentQuestionId -= 1;
        if (currentQuestionId > offset) {
            limit = currentQuestionId - offset;
            sizeOfArray = (currentQuestionId - offset) + 1;
        } else {
            limit = 1;
            sizeOfArray = currentQuestionId;
        }
        QuestionStats[] memory arr = new QuestionStats[](sizeOfArray);
        for (uint256 i = currentQuestionId; i >= limit; i--) {
            if (questionByState[i].questionState == currentState) {
                arr[j] = questionByState[i];
                j++;
            }
        }
        return arr;
    }

    //------------------------------------------------------ OWNER FUNCTIONS

    /**
     * @notice Allows the owner to set the BountyQuestion contract address.
     * @param newQuestion The address of the new BountyQuestion contract.
     */
    function setQuestionProxy(address newQuestion) public onlyOwner {
        if (newQuestion == address(0)) revert InvalidAddress();
        _bountyQuestion = IBountyQuestion(newQuestion);
    }

    //------------------------------------------------------ Errors
    error HasNotVotedForQuestion();
    error HasAlreadyVotedForQuestion();
    error InvalidStateTransition();
    error InvalidAddress();

    //------------------------------------------------------ Structs
    modifier onlyState(STATE required, uint256 questionId) {
        if (required != getState(questionId)) revert InvalidStateTransition();
        _;
    }

    struct QuestionStats {
        uint256 questionId;
        string uri;
        address[] voters;
        uint256 totalVotes;
        STATE questionState;
    }
}
