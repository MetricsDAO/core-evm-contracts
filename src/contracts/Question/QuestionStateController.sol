//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IQuestionStateController.sol";

contract QuestionStateController is IQuestionStateController, Ownable {
    mapping(uint256 => Vote[]) private _votes;
    mapping(uint256 => STATE) public state;

    function initializeQuestion(uint256 questionId) public onlyOwner {
        state[questionId] = STATE.DRAFT;
    }

    //------------------------------------------------------ View Functions

    function getVotes(uint256 questionId) public view returns (Vote[] memory votes) {
        return _votes[questionId];
    }

    //------------------------------------------------------ Structs

    struct Vote {
        address _voter;
        uint256 _amount;
        uint256 _weightedVote;
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
