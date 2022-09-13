// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ClaimEventsAndErrors {
    ///------------------------------------------------------ ERRORS

    /// @notice Throw if user tries to claim a question that is past its limit
    error ClaimLimitReached();

    /// @notice Throw if a analyst tries to answer a question that it has not claimed
    error NeedClaimToAnswer();

    /// @notice Throw if analyst tries to claim a question multiple times
    error AlreadyClaimed();

    /// @notice Throw if analyst tries to release a claim it did not claim
    error NoClaimToRelease();
}
