//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IQuestionStateController.sol";

contract QuestionStateController is IQuestionStateController, Ownable {
    address public questionApi;
    mapping(uint256 => QuestionVote) public votes;
    mapping(uint256 => STATE) public state;
    mapping(address => mapping(uint256 => uint256)) public questionIndex;

    // TODO ? map a user's address to their votes
    // TODO do we want user to lose their metric if a question is closed? they voted on somethjing bad

    /**
     * @notice Initializes a question to draft.
     * @param questionId The id of the question
     */
    function initializeQuestion(uint256 questionId) public onlyApi {
        state[questionId] = STATE.DRAFT;
    }

    function readyForVotes(uint256 questionId) public onlyApi onlyState(STATE.DRAFT, questionId) {
        state[questionId] = STATE.VOTING;
    }

    function publish(uint256 questionId) public onlyApi onlyState(STATE.VOTING, questionId) {
        // if some voting barrier is passed, we can publish the question
        state[questionId] = STATE.PUBLISHED;
    }

    // Cannot for for yourself
    // Can only vote once? Shouldnt matter
    function voteFor(
        address _user,
        uint256 questionId,
        uint256 amount
    ) public onlyApi onlyState(STATE.VOTING, questionId) {
        Vote memory _vote = Vote({voter: _user, amount: amount, weightedVote: amount});
        votes[questionId].votes.push(_vote);
        questionIndex[_user][questionId] = votes[questionId].votes.length - 1;
        votes[questionId].totalVoteCount += amount;
        // Lock tokens for voting
    }

    function unvoteFor(address _user, uint256 questionId) public onlyApi onlyState(STATE.VOTING, questionId) {
        uint256 index = questionIndex[_user][questionId];
        uint256 amount = votes[questionId].votes[index].amount;

        votes[questionId].votes[index].amount = 0;
        votes[questionId].votes[index].weightedVote = 0;

        votes[questionId].totalVoteCount -= amount;

        // Unlock tokens for voting
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

    function setQuestionApi(address _questionApi) public onlyOwner {
        questionApi = _questionApi;
    }

    // ------------------------------- Modifier
    error NotTheApi();
    modifier onlyApi() {
        if (msg.sender != questionApi) revert NotTheApi();
        _;
    }

    //------------------------------------------------------ Structs

    error InvalidStateTransition();
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
        uint256 weightedVote;
    }

    //UNINIT is the default state, and must be first in the enum set
    // enum STATE {
    //     UNINIT,
    //     DRAFT,
    //     VOTING,
    //     PUBLISHED,
    //     IN_GRADING,
    //     COMPLETED,
    //     CANCELLED
    // }
}
