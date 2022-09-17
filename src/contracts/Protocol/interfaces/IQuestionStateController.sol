// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../Enums/QuestionStateEnum.sol";

interface IQuestionStateController {
    function initializeQuestion(uint256 questionId) external;

    function initializeChallenge(uint256 questionId) external;

    function voteFor(address _user, uint256 questionId) external;

    function unvoteFor(address _user, uint256 questionId) external;

    function publishFromQuestion(uint256 question) external;

    function publishFromChallenge(uint256 question) external;

    function getState(uint256 quesitonId) external view returns (STATE currentState);

    function getHasUserVoted(address user, uint256 questionId) external view returns (bool);

    function setDisqualifiedState(uint256 questionId) external;

    function markComplete(uint256 questionId) external;
}
