// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../Helpers/QuickSetup.sol";

contract VotingTest is QuickSetup {
    function setUp() public {
        quickSetup();
    }

    // ---------------------- General tests ----------------------

    function test_CreateQuestionAndVoteForQuestionThenUnvoteForQuestion() public {
        console.log("Should correctly create a question and vote for it");

        vm.startPrank(other);
        // Create a question and see that it is created and balance is updated.
        assertEq(_metricToken.balanceOf(other), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");
        assertEq(_metricToken.balanceOf(other), 99e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(uint256(_questionStateController.getState(questionId)), uint256(STATE.VOTING));

        // Vote for the question
        vm.stopPrank();
        vm.prank(other3);
        _questionAPI.upvoteQuestion(questionId);
        vm.startPrank(other);
        assertEq(_metricToken.balanceOf(other), 99e18);
        assertEq(uint256(_questionStateController.getState(questionId)), uint256(STATE.VOTING));
        assertEq(_questionStateController.getTotalVotes(questionId), 2);

        // Question is set for the right address and values
        _questionStateController.getVoters(questionId);

        // Unvote for the question
        vm.stopPrank();
        vm.prank(other3);
        _questionAPI.unvoteQuestion(questionId);

        // Check that accounting was done properly.
        _questionStateController.getVoters(questionId);
    }

    function test_UnvotingWithoutFirstHavingVotedDoesNotWork() public {
        console.log("It should not be possible to unvote if you have not voted for the question.");

        vm.startPrank(other);
        // Create a question and see that it is created and balance is updated.
        assertEq(_metricToken.balanceOf(other), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");
        assertEq(_metricToken.balanceOf(other), 99e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(uint256(_questionStateController.getState(questionId)), uint256(STATE.VOTING));

        // Vote for the question
        vm.stopPrank();
        vm.prank(other3);
        _questionAPI.upvoteQuestion(questionId);
        vm.startPrank(other);
        assertEq(_metricToken.balanceOf(other), 99e18);
        assertEq(uint256(_questionStateController.getState(questionId)), uint256(STATE.VOTING));
        assertEq(_questionStateController.getTotalVotes(questionId), 2);

        // Question is set for the right address and values
        _questionStateController.getVoters(questionId);
        vm.stopPrank();

        vm.startPrank(owner);
        vm.expectRevert(StateEventsAndErrors.HasNotVotedForQuestion.selector);

        // Unvote for the question
        _questionAPI.unvoteQuestion(questionId);

        // Check that accounting was done properly.
        _questionStateController.getVoters(questionId);
        vm.stopPrank();
    }

    function test_CannotVoteSameQuestionMultipleTimes() public {
        console.log("It should not be possible to vote multiple times for the same question.");

        vm.startPrank(other);
        // Create a question and see that it is created and balance is updated.
        assertEq(_metricToken.balanceOf(other), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");
        assertEq(_metricToken.balanceOf(other), 99e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(uint256(_questionStateController.getState(questionId)), uint256(STATE.VOTING));

        // Vote for the question
        vm.stopPrank();
        vm.prank(other3);
        _questionAPI.upvoteQuestion(questionId);
        vm.startPrank(other);
        assertEq(_metricToken.balanceOf(other), 99e18);
        assertEq(uint256(_questionStateController.getState(questionId)), uint256(STATE.VOTING));
        assertEq(_questionStateController.getTotalVotes(questionId), 2);

        // Question is set for the right address and values
        _questionStateController.getVoters(questionId);

        // Vote for the question again
        vm.stopPrank();
        vm.prank(other3);
        vm.expectRevert(StateEventsAndErrors.HasAlreadyVotedForQuestion.selector);
        _questionAPI.upvoteQuestion(questionId);

        // Check that accounting was done properly.
        _questionStateController.getVoters(questionId);
    }

    function test_CannotVoteForOwnQuestion() public {
        console.log("It should not be possible to vote for your own question.");

        vm.startPrank(other);
        // Create a question and see that it is created and balance is updated.
        assertEq(_metricToken.balanceOf(other), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");
        assertEq(_metricToken.balanceOf(other), 99e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(uint256(_questionStateController.getState(questionId)), uint256(STATE.VOTING));

        // Vote for the question
        vm.expectRevert(ApiEventsAndErrors.CannotVoteForOwnQuestion.selector);
        _questionAPI.upvoteQuestion(questionId);
        vm.stopPrank();
    }

    function test_VoteUnvoteVote() public {
        console.log("A user should be able to vote unvote vote.");

        vm.startPrank(other);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");
        vm.stopPrank();

        vm.startPrank(other2);
        _questionAPI.upvoteQuestion(questionId);

        _questionAPI.unvoteQuestion(questionId);

        _questionAPI.upvoteQuestion(questionId);
    }

    function test_CannotWithrawForUnvotingAfterCreatingQuestion() public {
        console.log("A user should not be able to withdraw their funds after creating a question.");

        vm.startPrank(other);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");

        vm.expectRevert(VaultEventsAndErrors.CannotUnvoteOwnQuestion.selector);
        _questionAPI.withdrawFromVault(questionId, STAGE.UNVOTE);
        vm.stopPrank();
    }

    function test_TotalVotesShouldInitializeToOne() public {
        console.log("Voting should initialize to zero.");

        vm.prank(other);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");

        assertEq(_questionStateController.getTotalVotes(questionId), 1);
    }

    // ---------------------- Access control tests ----------------------
}
