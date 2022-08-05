// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IQuestionStateController {
    function initializeQuestion(uint256 questionId, string calldata uri) external;

    function voteFor(address _user, uint256 questionId) external;

    function unvoteFor(address _user, uint256 questionId) external;

    function publish(uint256 questionId) external;

    // TODO currentState can probably be like a uint8, it depends on how many states we have
    function getState(uint256 quesitonId) external view returns (uint256 currentState);

    function setDisqualifiedState(uint256 questionId) external;
}
