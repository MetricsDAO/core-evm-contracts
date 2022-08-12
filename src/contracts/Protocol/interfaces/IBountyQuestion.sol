// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../Structs/QuestionData.sol";

interface IBountyQuestion {
    function getQuestionData(uint256 questionId) external view returns (QuestionData memory);

    function getMostRecentQuestion() external view returns (uint256);
}
