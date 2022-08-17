//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../Enums/QuestionStateEnum.sol";

struct QuestionData {
    uint256 questionId;
    address author;
    string uri;
    // TODO this is only used for our bulk read functions and is not actively tracked, it shouldn't be here.
    uint256 totalVotes;
    STATE questionState;
}
