// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

enum STAGE {
    CREATE_AND_VOTE,
    UNVOTE,
    CLAIM_AND_ANSWER,
    REVIEW
}

enum STATUS {
    UNINT,
    DEPOSITED,
    WITHDRAWN,
    SLASHED
}
