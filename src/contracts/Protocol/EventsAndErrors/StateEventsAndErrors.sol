// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface StateEventsAndErrors {
    ///------------------------------------------------------ ERRORS

    error HasNotVotedForQuestion();
    error HasAlreadyVotedForQuestion();
    error InvalidStateTransition();
    error InvalidAddress();
}
