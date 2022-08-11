// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../Structs/AnswerStruct.sol";

interface IClaimController {
    function initializeQuestion(uint256 questionId, uint256 claimLimit) external;

    function claim(address user, uint256 questionId) external;

    function releaseClaim(address user, uint256 questionId) external;

    function answer(
        address user,
        uint256 questionId,
        string calldata answerURL
    ) external;

    function getClaimDataForUser(uint256 questionId, address user) external view returns (Answer memory _answer);

    function getQuestionClaimState(uint256 questionId, address user) external view returns (CLAIM_STATE claimState);
}
