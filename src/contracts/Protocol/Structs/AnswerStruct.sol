// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {CLAIM_STATE} from "../Enums/ClaimEnum.sol";

struct Answer {
    CLAIM_STATE state;
    address author;
    string answerURL;
    uint256 finalGrade;
    string scoringMetaDataURI;
}
