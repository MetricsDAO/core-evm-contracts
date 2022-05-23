//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IQuestionStateController.sol";

contract QuestionStateController is IQuestionStateController, Ownable {
    mapping(uint256 => Vote[]) private _votes;
    mapping(uint256 => STATE) private _state;

    function initializeQuestion(uint256 questionId) public onlyOwner {
        _state[questionId] = STATE.DRAFT;
    }

    //------------------------------------------------------ Structs

    struct Vote {
        address _voter;
        uint256 _amount;
        uint256 _weightedVote;
    }

    //UNINIT is the default state, and must be first in the enum set.
    enum STATE {
        UNINIT,
        DRAFT,
        PUBLISHED,
        IN_GRADING,
        COMPLETED,
        CANCELLED
    }
}
