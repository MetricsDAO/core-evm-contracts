//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IQuestionStateController.sol";

contract QuestionStateController is IQuestionStateController, Ownable {
    mapping(uint256 => QuestionVote) public votes;
    mapping(uint256 => STATE) public state;

    function initializeQuestion(uint256 questionId) public onlyOwner {
        state[questionId] = STATE.DRAFT;
    }

    function voteFor(uint256 questionId, uint256 amount) public onlyOwner {
        Vote memory _vote = Vote({voter: _msgSender(), amount: amount, weightedVote: amount});
        votes[questionId].votes.push(_vote);
        votes[questionId].totalVoteCount = votes[questionId].totalVoteCount + amount;
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

    //UNINIT is the default state, and must be first in the enum set
    enum STATE {
        UNINIT,
        DRAFT,
        PUBLISHED,
        IN_GRADING,
        COMPLETED,
        CANCELLED
    }
}
