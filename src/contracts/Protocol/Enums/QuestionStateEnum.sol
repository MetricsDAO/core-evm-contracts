// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

enum STATE {
    UNINIT,
    VOTING,
    PENDING,
    PUBLISHED,
    DISQUALIFIED,
    COMPLETED
}
