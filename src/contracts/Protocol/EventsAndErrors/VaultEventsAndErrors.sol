// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface VaultEventsAndErrors {
    ///------------------------------------------------------ ERRORS

    /// @notice Throw if user tries to withdraw Metric from a question it does not own.
    error NotTheDepositor();

    /// @notice Throw if user tries to withdraw Metric without having first deposited.
    error NoMetricDeposited();

    /// @notice Throw if user tries to lock Metric for a question that has a different state than UNINT.
    error QuestionHasInvalidStatus();

    /// @notice Throw if user tries to claim Metric for unvoting on a question that is not in the VOTING state.
    error QuestionNotInVoting();

    /// @notice Throw if user tries to claim Metric for a question that has not been published (yet).
    error QuestionNotPublished();

    /// @notice Throw if user tries to claim Metric for a question that was not unvoted
    error UserHasNotUnvoted();

    /// @notice Throw if user tries to withdraw Metric from a question that is not in the review state.
    error QuestionNotInReview();

    /// @notice Throw if user tries to withdraw Metric from a claim that is not released.
    error ClaimNotReleased();

    /// @notice Throw if creator of question tries to unvote
    error CannotUnvoteOwnQuestion();

    /// @notice Throw if the same question is slashed twice.
    error AlreadySlashed();

    /// @notice Throw if address is equal to address(0).
    error InvalidAddress();

    /// @notice Throw if user tries to lock METRIC for a stage that does not require locking.
    error InvalidStage();

    ///------------------------------------------------------ EVENTS

    /// @notice Event emitted when Metric is withdrawn.
    event Withdraw(address indexed user, uint256 indexed amount);

    /// @notice Event emitted when a question is slashed.
    event Slashed(address indexed user, uint256 indexed questionId);
}
