// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

enum STAGE {
    CREATE_AND_VOTE,
    UNVOTE,
    PUBLISH,
    CLAIM_AND_ANSWER,
    RELEASE_CLAIM,
    REVIEW
}

enum STATUS {
    UNINT,
    DEPOSITED,
    WITHDRAWN,
    SLASHED
}
