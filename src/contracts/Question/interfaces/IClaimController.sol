// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IClaimController {
    function initializeQuestion(uint256 questionId, uint256 claimLimit) external;
}
