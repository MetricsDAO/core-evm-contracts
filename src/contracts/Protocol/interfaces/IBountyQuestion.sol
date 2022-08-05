// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IBountyQuestion {
    function getById(uint256 questionId) external returns (IBountyQuestion);

    enum STATE {
        UNINIT,
        VOTING,
        PUBLISHED, // TODO this where it becomes a challenge, can be claimed and answered
        DISQUALIFIED,
        COMPLETED
    }

    struct QuestionStats {
        address author;
        uint256 questionId;
        string uri;
        address[] voters;
        uint256 totalVotes;
        STATE questionState;
    }
}
