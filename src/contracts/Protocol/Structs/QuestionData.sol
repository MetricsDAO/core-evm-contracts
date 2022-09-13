//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {STATE} from "../Enums/QuestionStateEnum.sol";

struct QuestionData {
    uint256 questionId;
    address author;
    string uri;
    uint256 totalVotes;
    STATE questionState;
}
