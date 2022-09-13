// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../Structs/QuestionData.sol";

interface IBountyQuestion {
    function mintQuestion(address author, string calldata uri) external returns (uint256);

    function getQuestionData(uint256 questionId) external view returns (QuestionData memory);

    function getMostRecentQuestion() external view returns (uint256);

    function updateState(uint256 questionId, STATE newState) external;

    function updateVotes(uint256 questionId, uint256 newVotes) external;

    function getAuthorOfQuestion(uint256 questionId) external view returns (address);
}
