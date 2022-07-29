// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IClaimController {
    function initializeQuestion(uint256 questionId, uint256 claimLimit) external;

    function claim(address user, uint256 questionId) external;

    function answer(
        address user,
        uint256 questionId,
        string calldata answerURL
    ) external;
}
