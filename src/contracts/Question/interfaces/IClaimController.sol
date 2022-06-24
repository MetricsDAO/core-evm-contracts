// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IClaimController {
    function initializeQuestion(uint256 questionId, uint256 claimLimit) external;

    function claim(uint256 questionId) external;

    function answer(uint256 questionId, string calldata answerURL) external;
}
