// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IClaimController {
    function initializeQuestion(uint256 questionId, uint256 claimLimit) external;
}
