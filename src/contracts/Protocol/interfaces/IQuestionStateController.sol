// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../Enums/QuestionState.sol";

interface IQuestionStateController {
    function initializeQuestion(uint256 questionId, string calldata uri) external;

    function voteFor(address _user, uint256 questionId) external;

    function unvoteFor(address _user, uint256 questionId) external;

    function publish(uint256 questionId) external;

    function getState(uint256 quesitonId) external view returns (STATE currentState);

    function getHasUserVoted(address user, uint256 questionId) external view returns (bool);

    function setDisqualifiedState(uint256 questionId) external;
}
