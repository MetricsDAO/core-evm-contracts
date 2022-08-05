//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

// Interfaces
import "./interfaces/IQuestionStateController.sol";
import "./interfaces/IBountyQuestion.sol";

// Modifiers
import "./modifiers/OnlyAPI.sol";

contract QuestionStateController is IQuestionStateController, Ownable, OnlyApi {
    // Mapping for all questions that are upvoted by the user?
    mapping(address => mapping(uint256 => bool)) public hasVoted;
    mapping(address => mapping(uint256 => uint256)) public questionIndex;

    mapping(uint256 => IBountyQuestion.QuestionStats) public questionByState;

    /**
     * @notice Initializes a question to draft.
     * @param questionId The id of the question
     */
    function initializeQuestion(uint256 questionId, string calldata uri) public onlyApi {
        IBountyQuestion.QuestionStats memory question;

        question.questionId = questionId;
        question.uri = uri;
        question.totalVotes = 1;
        question.questionState = IBountyQuestion.STATE.VOTING;

        questionByState[questionId] = question;
    }

    function publish(uint256 questionId) public onlyApi onlyState(IBountyQuestion.STATE.VOTING, questionId) {
        // if some voting barrier is passed, we can publish the question
        IBountyQuestion.QuestionStats storage _question = questionByState[questionId];
        _question.questionState = IBountyQuestion.STATE.PUBLISHED;
    }

    function voteFor(address _user, uint256 questionId) public onlyApi onlyState(IBountyQuestion.STATE.VOTING, questionId) {
        // Checks
        if (hasVoted[_user][questionId]) revert HasAlreadyVotedForQuestion();

        // Effects
        IBountyQuestion.QuestionStats storage _question = questionByState[questionId];
        _question.totalVotes += 1;

        hasVoted[_user][questionId] = true;
        _question.voters.push(_user);
        questionIndex[_user][questionId] = _question.voters.length - 1;

        // Interactions
    }

    function unvoteFor(address _user, uint256 questionId) public onlyApi onlyState(IBountyQuestion.STATE.VOTING, questionId) {
        // Checks
        if (!hasVoted[_user][questionId]) revert HasNotVotedForQuestion();

        // Effects
        IBountyQuestion.QuestionStats storage _question = questionByState[questionId];
        _question.totalVotes -= 1;

        uint256 index = questionIndex[_user][questionId];
        delete _question.voters[index];

        hasVoted[_user][questionId] = false;

        // Interactions
    }

    function setDisqualifiedState(uint256 questionId) public onlyApi {
        IBountyQuestion.QuestionStats storage _question = questionByState[questionId];
        _question.questionState = IBountyQuestion.STATE.DISQUALIFIED;
    }

    // TODO batch voting and batch operations and look into arrays as parameters security risk

    //------------------------------------------------------ View Functions

    function getState(uint256 questionId) public view returns (uint256 currentState) {
        IBountyQuestion.QuestionStats memory _question = questionByState[questionId];
        return uint256(_question.questionState);
    }

    function getVoters(uint256 questionId) public view returns (address[] memory voters) {
        IBountyQuestion.QuestionStats memory _question = questionByState[questionId];
        return _question.voters;
    }

    function getTotalVotes(uint256 questionId) public view returns (uint256) {
        IBountyQuestion.QuestionStats memory _question = questionByState[questionId];
        return _question.totalVotes;
    }

    function getQuestionsByState(
        IBountyQuestion.STATE currentState,
        uint256 currentQuestionId,
        uint256 offset
    ) public view returns (IBountyQuestion.QuestionStats[] memory) {
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
        IBountyQuestion.QuestionStats[] memory arr = new IBountyQuestion.QuestionStats[](sizeOfArray);
        for (uint256 i = currentQuestionId; i >= limit; i--) {
            if (questionByState[i].questionState == currentState) {
                arr[j] = questionByState[i];
                j++;
            }
        }
        return arr;
    }

    //------------------------------------------------------ Errors
    error HasNotVotedForQuestion();
    error HasAlreadyVotedForQuestion();
    error InvalidStateTransition();

    //------------------------------------------------------ Structs
    modifier onlyState(IBountyQuestion.STATE required, uint256 questionId) {
        if (uint256(required) != getState(questionId)) revert InvalidStateTransition();
        _;
    }
}
