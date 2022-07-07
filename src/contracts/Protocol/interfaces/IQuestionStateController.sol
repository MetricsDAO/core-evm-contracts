// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IQuestionStateController {
    function initializeQuestion(uint256 questionId) external;

    function voteFor(uint256 questionId, uint256 amount) external;

    function readyForVotes(uint256 questionId) external;

    // TODO currentState can probably be like a uint8, it depends on how many states we have
    function getState(uint256 quesitonId) external view returns (uint256 currentState);

    enum STATE {
        UNINIT,
        DRAFT,
        VOTING,
        PUBLISHED, // TODO this where it becomes a challenge, can be claimed and answered
        IN_GRADING,
        COMPLETED,
        CANCELLED
    }
}
