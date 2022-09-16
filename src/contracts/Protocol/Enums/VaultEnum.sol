// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

enum STAGE {
    CREATE_AND_VOTE,
    UNVOTE,
    CLAIM_AND_ANSWER,
    RELEASE_CLAIM,
    REVIEW,
    PUBLISH
}

enum STATUS {
    UNINT,
    DEPOSITED,
    WITHDRAWN,
    SLASHED,
    PUBLISH
}
