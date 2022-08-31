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

    /// @notice For a given address and a given question, tracks the index of their vote in the votes[]
    mapping(address => mapping(uint256 => uint256)) public questionIndex; // TODO userVoteIndex

    mapping(uint256 => Votes) public votes;

    IBountyQuestion private _bountyQuestion;

    // TODO do we want user to lose their metric if a question is closed? they voted on something bad

    constructor(address bountyQuestion) {
        _bountyQuestion = IBountyQuestion(bountyQuestion);
    }

    /**
     * @notice Initializes a question to draft.
     * @param questionId The id of the question
     */
    function initializeQuestion(uint256 questionId) public onlyApi {
        _bountyQuestion.updateState(questionId, STATE.VOTING);

        votes[questionId].totalVotes = 1;
    }

    function publish(uint256 questionId) public onlyApi onlyState(STATE.VOTING, questionId) {
        // if some voting barrier is passed, we can publish the question
        _bountyQuestion.updateState(questionId, STATE.PUBLISHED);
    }

    function voteFor(address _user, uint256 questionId) public onlyApi onlyState(STATE.VOTING, questionId) {
        // Checks
        if (hasVoted[_user][questionId]) revert HasAlreadyVotedForQuestion();

        // Effects
        hasVoted[_user][questionId] = true;

        votes[questionId].totalVotes++;
        votes[questionId].voters.push(_user);

        questionIndex[_user][questionId] = votes[questionId].voters.length - 1;

        // Interactions
    }

    function unvoteFor(address _user, uint256 questionId) public onlyApi onlyState(STATE.VOTING, questionId) {
        // Checks
        if (!hasVoted[_user][questionId]) revert HasNotVotedForQuestion();

        // Effects
        votes[questionId].totalVotes--;

        uint256 index = questionIndex[_user][questionId];
        delete votes[questionId].voters[index];

        hasVoted[_user][questionId] = false;

        // Interactions
    }

    function setDisqualifiedState(uint256 questionId) public onlyApi {
        _bountyQuestion.updateState(questionId, STATE.DISQUALIFIED);
    }

    // TODO batch voting and batch operations and look into arrays as parameters security risk

    //------------------------------------------------------ View Functions

    function getState(uint256 questionId) public view returns (STATE currentState) {
        return _bountyQuestion.getQuestionData(questionId).questionState;
    }

    function getVoters(uint256 questionId) public view returns (address[] memory voters) {
        return votes[questionId].voters;
    }

    function getTotalVotes(uint256 questionId) public view returns (uint256) {
        return votes[questionId].totalVotes;
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
        currentQuestionId -= 1;
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
                found[j].totalVotes = votes[i].totalVotes;
                j++;
            }
        }
        return found;
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

    struct Votes {
        address[] voters;
        uint256 totalVotes;
    }
}
