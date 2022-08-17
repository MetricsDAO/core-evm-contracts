//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../Enums/QuestionStateEnum.sol";

struct QuestionData {
    uint256 questionId;
    address author;
    string uri;
    // address[] voters;
    uint256 totalVotes;
    STATE questionState;
}
