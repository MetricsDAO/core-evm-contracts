//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IQuestionStateController.sol";
import "./modifiers/OnlyAPI.sol";

contract QuestionStateController is IQuestionStateController, Ownable, OnlyApi {
    mapping(uint256 => QuestionVote) public votes;
    mapping(uint256 => STATE) public state;

    // Mapping for all questions that are upvoted by the user?
    mapping(address => mapping(uint256 => bool)) public hasVoted;
    mapping(address => mapping(uint256 => uint256)) public questionIndex;

    mapping(uint256 => QuestionData) public questionByState;

    //TODO mapping     mapping(STATE => uint256[]) public questionState;

    // TODO do we want user to lose their metric if a question is closed? they voted on somethjing bad

    /**
     * @notice Initializes a question to draft.
     * @param questionId The id of the question
     */
    function initializeQuestion(uint256 questionId, string calldata uri) public onlyApi {
        state[questionId] = STATE.VOTING;
        QuestionData memory _question = QuestionData({url: uri, totalVotes: 0, questionId: questionId, questionState: STATE.VOTING});
        questionByState[questionId] = _question;
    }

    function publish(uint256 questionId) public onlyApi onlyState(STATE.VOTING, questionId) {
        // if some voting barrier is passed, we can publish the question
        state[questionId] = STATE.PUBLISHED;
    }

    function voteFor(
        address _user,
        uint256 questionId,
        uint256 amount
    ) public onlyApi onlyState(STATE.VOTING, questionId) {
        // Checks
        // TODO check if creator can upvote their own ?
        // TODO limit the max amount of token they can use?
        if (hasVoted[_user][questionId]) revert HasAlreadyVotedForQuestion();

        // Effects
        Vote memory _vote = Vote({voter: _user, amount: amount});
        votes[questionId].votes.push(_vote);

        hasVoted[_user][questionId] = true;
        questionIndex[_user][questionId] = votes[questionId].votes.length - 1;

        votes[questionId].totalVoteCount += amount; // TODO Lock tokens for voting include safeTransferFrom

        QuestionData storage question = questionByState[questionId];
        question.totalVotes += amount;
        // Interactions
    }

    function unvoteFor(address _user, uint256 questionId) public onlyApi onlyState(STATE.VOTING, questionId) {
        // Checks
        if (!hasVoted[_user][questionId]) revert HasNotVotedForQuestion();

        // Effects
        uint256 index = questionIndex[_user][questionId];
        uint256 amount = votes[questionId].votes[index].amount;

        votes[questionId].votes[index].amount = 0;
        votes[questionId].totalVoteCount -= amount; // TODO Unlock tokens for voting
        // Interactions
    }

    function setDisqualifiedState(uint256 questionId) public onlyApi {
        state[questionId] = STATE.DISQUALIFIED;
        QuestionData storage question = questionByState[questionId];
        question.questionState = STATE.DISQUALIFIED;
    }

    // TODO batch voting and batch operations and look into arrays as parameters security risk

    //------------------------------------------------------ View Functions

    function getState(uint256 quesitonId) public view returns (uint256 currentState) {
        return uint256(state[quesitonId]);
    }

    function getVotes(uint256 questionId) public view returns (Vote[] memory _votes) {
        return votes[questionId].votes;
    }

    function getTotalVotes(uint256 questionId) public view returns (uint256) {
        return votes[questionId].totalVoteCount;
    }

    function getQuestionsByState(
        STATE currentState,
        uint256 currentQuestionId,
        uint256 offset
    ) public view returns (QuestionData[] memory) {
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
        QuestionData[] memory arr = new QuestionData[](sizeOfArray);
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
    modifier onlyState(STATE required, uint256 questionId) {
        if (required != state[questionId]) revert InvalidStateTransition();
        _;
    }

    struct QuestionVote {
        Vote[] votes;
        uint256 totalVoteCount;
    }

    struct Vote {
        address voter;
        uint256 amount;
    }

    struct QuestionData {
        string url;
        uint256 totalVotes;
        uint256 questionId;
        STATE questionState;
    }
}
