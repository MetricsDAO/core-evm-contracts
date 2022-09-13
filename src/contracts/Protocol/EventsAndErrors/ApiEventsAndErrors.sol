// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ApiEventsAndErrors {
    ///------------------------------------------------------ EVENTS

    /// @notice Emitted when a question is created.
    event QuestionCreated(uint256 indexed questionId, address indexed creator);

    /// @notice Emitted when a challenge is created.
    event ChallengeCreated(uint256 indexed questionId, address indexed challengeCreator);

    /// @notice Emitted when a question is published.
    event QuestionPublished(uint256 indexed questionId, address indexed publisher);

    /// @notice Emitted when a question is claimed.
    event QuestionClaimed(uint256 indexed questionId, address indexed claimant);

    /// @notice Emitted when a question is answered.
    event QuestionAnswered(uint256 indexed questionId, address indexed answerer);

    /// @notice Emitted when a question is disqualified.
    event QuestionDisqualified(uint256 indexed questionId, address indexed disqualifier);

    /// @notice Emitted when a question is upvoted.
    event QuestionUpvoted(uint256 indexed questionId, address indexed voter);

    /// @notice Emitted when a question is unvoted.
    event QuestionUnvoted(uint256 indexed questionId, address indexed voter);

    /// @notice Emitted when a challenge is proposed.
    event ChallengeProposed(uint256 indexed questionId, address indexed proposer);

    //------------------------------------------------------ ERRORS

    /// @notice Throw if analysts tries to claim a question that is not published.
    error ClaimsNotOpen();

    /// @notice Throw if a question has not reached the benchmark for being published (yet).
    error NotAtBenchmark();

    /// @notice Throw if address is equal to address(0).
    error InvalidAddress();

    /// @notice Throw if user tries to vote for own question
    error CannotVoteForOwnQuestion();

    /// @notice Throw if action is executed on a question that does not exist.
    error QuestionDoesNotExist();
}
