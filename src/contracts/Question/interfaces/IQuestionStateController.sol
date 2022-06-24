// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IQuestionStateController {
    function initializeQuestion(uint256 questionId) external;

    function voteFor(uint256 questionId, uint256 amount) external;
}
