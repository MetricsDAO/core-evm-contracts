//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IQuestionStateController.sol";

contract QuestionStateController is IQuestionStateController, Ownable {
    mapping(uint256 => QuestionVote) public votes;
    mapping(uint256 => STATE) public state;

    // TODO ? map a user's address to their votes
    // TODO do we want user to lose their metric if a question is closed? they voted on somethjing bad

    error InvalidStateTransition();

    function initializeQuestion(uint256 questionId) public onlyOwner {
        state[questionId] = STATE.DRAFT;
    }

    function readyForVotes(uint256 questionId) public onlyOwner {
        if (state[questionId] != STATE.DRAFT) revert InvalidStateTransition();

        state[questionId] = STATE.VOTING;
    }

    function publish(uint256 questionId) public onlyOwner {
        if (state[questionId] != STATE.VOTING) revert InvalidStateTransition();

        state[questionId] = STATE.PUBLISHED;
    }

    error QuestionNotInVoting();

    function voteFor(uint256 questionId, uint256 amount) public onlyOwner {
        if (state[questionId] != STATE.VOTING) revert QuestionNotInVoting();

        Vote memory _vote = Vote({voter: _msgSender(), amount: amount, weightedVote: amount});
        votes[questionId].votes.push(_vote);
        votes[questionId].totalVoteCount = votes[questionId].totalVoteCount + amount;
    }

    // TODO batch voting and batch operations and look into arrays as parameters security risk

    //------------------------------------------------------ View Functions

    function getState(uint256 quesitonId) public view returns (uint256 currentState) {
        return uint256(state[quesitonId]);
    }

    function getVotes(uint256 questionId) public view returns (Vote[] memory _votes) {
        return votes[questionId].votes;
    }

    //------------------------------------------------------ Structs

    struct QuestionVote {
        Vote[] votes;
        uint256 totalVoteCount;
    }

    struct Vote {
        address voter;
        uint256 amount;
        uint256 weightedVote;
    }

    // TODO add modifier function to track required state (onlyState(x))
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
