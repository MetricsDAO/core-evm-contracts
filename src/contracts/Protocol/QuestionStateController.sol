//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

// Interfaces
import {IBountyQuestion} from "./interfaces/IBountyQuestion.sol";
import {IQuestionAPI} from "./interfaces/IQuestionAPI.sol";

// Enums
import {STATE} from "./Enums/QuestionStateEnum.sol";

// Structs
import {QuestionData} from "./Structs/QuestionData.sol";

// Errors
import {StateEventsAndErrors} from "./EventsAndErrors/StateEventsAndErrors.sol";

// Modifiers
import "./modifiers/OnlyAPI.sol";

contract QuestionStateController is Ownable, OnlyApi, StateEventsAndErrors {
    IBountyQuestion private _bountyQuestion;

    mapping(address => mapping(uint256 => bool)) public hasVoted;

    /// @notice For a given address and a given question, tracks the index of their vote in the votes[]
    mapping(address => mapping(uint256 => uint256)) public questionIndex;
    mapping(uint256 => address[]) public votes;

    //------------------------------------------------------ CONSTRUCTOR
    constructor() {}

    //------------------------------------------------------ FUNCTIONS

    /**
     * @notice Initializes a question to draft.
     * @param questionId The id of the question
     */
    function initializeQuestion(uint256 questionId) public onlyApi {
        _bountyQuestion.updateState(questionId, STATE.VOTING);
        _bountyQuestion.updateVotes(questionId, 1);
    }

    function initializeChallenge(uint256 questionId) public onlyApi {
        _bountyQuestion.updateState(questionId, STATE.PENDING);
    }

    function publishFromQuestion(uint256 questionId) public onlyApi onlyState(STATE.VOTING, questionId) {
        _bountyQuestion.updateState(questionId, STATE.PUBLISHED);
    }

    function publishFromChallenge(uint256 questionId) public onlyApi onlyState(STATE.PENDING, questionId) {
        _bountyQuestion.updateState(questionId, STATE.PUBLISHED);
    }

    function markComplete(uint256 questionId) public onlyApi onlyState(STATE.PUBLISHED, questionId) {
        _bountyQuestion.updateState(questionId, STATE.COMPLETED);
    }

    function voteFor(address _user, uint256 questionId) public onlyApi onlyState(STATE.VOTING, questionId) {
        // Checks
        if (hasVoted[_user][questionId]) revert HasAlreadyVotedForQuestion();

        // Effects
        hasVoted[_user][questionId] = true;

        _bountyQuestion.updateVotes(questionId, (getTotalVotes(questionId) + 1));
        votes[questionId].push(_user);

        questionIndex[_user][questionId] = votes[questionId].length - 1;

        // Interactions
    }

    function unvoteFor(address _user, uint256 questionId) public onlyApi onlyState(STATE.VOTING, questionId) {
        // Checks
        if (!hasVoted[_user][questionId]) revert HasNotVotedForQuestion();

        // Effects
        _bountyQuestion.updateVotes(questionId, (getTotalVotes(questionId) - 1));

        uint256 index = questionIndex[_user][questionId];
        delete votes[questionId][index];

        hasVoted[_user][questionId] = false;

        // Interactions
    }

    function setDisqualifiedState(uint256 questionId) public onlyApi {
        _bountyQuestion.updateState(questionId, STATE.DISQUALIFIED);
    }

    function updateBountyQuestion() public {
        _bountyQuestion = IBountyQuestion(IQuestionAPI(questionApi).getBountyQuestion());
    }

    // ------------------------------------------------------ VIEW FUNCTIONS

    function getState(uint256 questionId) public view returns (STATE currentState) {
        return _bountyQuestion.getQuestionData(questionId).questionState;
    }

    function getVoters(uint256 questionId) public view returns (address[] memory) {
        return votes[questionId];
    }

    function getTotalVotes(uint256 questionId) public view returns (uint256) {
        return _bountyQuestion.getQuestionData(questionId).totalVotes;
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

        questions = new QuestionData[](limit);

        uint256 found = 0;
        QuestionData memory cur;

        for (uint256 i = 0; i < highestQuestion; i++) {
            cur = _bountyQuestion.getQuestionData(i);
            if (cur.questionState == state) {
                questions[found] = cur;
                found++;
                if (found == limit) break;
            }
        }

        return questions;
    }

    function getQuestionsByState(
        STATE currentState,
        uint256 currentQuestionId,
        uint256 offset
    ) public view returns (QuestionData[] memory found) {
        uint256 j = 0;
        uint256 limit;
        uint256 sizeOfArray;
        currentQuestionId;
        if (currentQuestionId > offset) {
            limit = currentQuestionId - offset;
            sizeOfArray = (currentQuestionId - offset) + 1;
        } else {
            limit = 1;
            sizeOfArray = currentQuestionId;
        }
        found = new QuestionData[](sizeOfArray);
        for (uint256 i = currentQuestionId; i >= limit; i--) {
            if (_bountyQuestion.getQuestionData(i).questionState == currentState) {
                found[j] = _bountyQuestion.getQuestionData(i);
                found[j].totalVotes = _bountyQuestion.getQuestionData(i).totalVotes;
                j++;
            }
        }
        return found;
    }

    // Modifier
    modifier onlyState(STATE required, uint256 questionId) {
        if (required != getState(questionId)) revert InvalidStateTransition();
        _;
    }
}
