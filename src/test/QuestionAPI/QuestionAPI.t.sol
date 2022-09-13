// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../Helpers/QuickSetup.sol";

contract QuestionAPITest is QuickSetup {
    function setUp() public {
        quickSetup();
    }

    // ---------------------- General tests ----------------------

    function test_InitialMint() public {
        console.log("Should correctly distribute initial mint");
        assertEq(_metricToken.balanceOf(owner), 1000000000e18 - 300e18);
    }

    function test_CreateQuestion() public {
        console.log("Should correctly create a question");

        vm.startPrank(other);
        // Create a question and see that it is created and balance is updated.
        assertEq(_metricToken.balanceOf(other), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");
        assertEq(_metricToken.balanceOf(other), 99e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(uint256(_questionStateController.getState(questionId)), uint256(STATE.VOTING));

        // Other cannot directly call onlyApi functions
        vm.expectRevert(OnlyApi.NotTheApi.selector);
        _costController.payForAction(other, questionId, ACTION.CREATE);

        vm.stopPrank();
    }

    function test_DisqualifyQuestion() public {
        vm.startPrank(owner);
        uint256 badQuestion = _questionAPI.createQuestion("ipfs://XYZ");
        _questionAPI.disqualifyQuestion(badQuestion);
        uint256 questionState = uint256(_questionStateController.getState(badQuestion));

        assertEq(questionState, uint256(STATE.DISQUALIFIED));
        vm.stopPrank();
    }

    function test_DisqualifyQuestionTwo() public {
        vm.startPrank(other);
        uint256 badQuestion = _questionAPI.createQuestion("ipfs://XYZ");
        vm.stopPrank();

        vm.prank(owner);
        _questionAPI.disqualifyQuestion(badQuestion);

        assertEq(uint256(_questionStateController.getState(badQuestion)), uint256(STATE.DISQUALIFIED));
    }

    function test_ProgramManagerCreateChallenge() public {
        console.log("Only a user with the ProgramManager role should be allowed to create a challenge.");

        // Check that the manager holds the nft
        assertEq(_mockAuthNFTManager.ownerOf(1), manager);

        // Create a challenge from the manager
        vm.prank(manager);
        uint256 questionId = _questionAPI.createChallenge("ipfs://XYZ", 25, 1e18);

        // Verify that challenge is published
        assertEq(uint256(_questionStateController.getState(questionId)), uint256(STATE.PUBLISHED));

        // Make sure we cannot vote for the challenge
        vm.prank(other);
        vm.expectRevert(QuestionStateController.InvalidStateTransition.selector);
        _questionAPI.upvoteQuestion(questionId);

        // Make sure that not any user can create a challenge
        vm.prank(other);
        vm.expectRevert(NFTLocked.DoesNotHold.selector);
        _questionAPI.createChallenge("ipfs://XYZ", 25, 1e18);
    }

    function test_proposeChallenge() public {
        console.log("Should correctly propose a challenge");

        // Send other enough balance
        vm.prank(owner);
        _metricToken.transfer(other2, 10_000e18);

        vm.prank(other2);
        _metricToken.approve(address(_vault), 10_000e18);

        uint256 balanceBefore = _metricToken.balanceOf(other2);

        // Propose a challenge -- bypassing the queue
        vm.prank(other2);
        uint256 challengeId = _questionAPI.proposeChallenge("ipfs://XYZ");

        // See that correct state is set
        assertEq(uint256(_questionStateController.getState(challengeId)), uint256(STATE.PENDING));

        // Check that balance is updated correctly
        assertEq(_metricToken.balanceOf(other2), balanceBefore - _costController.getActionCost(ACTION.CHALLENGE_BURN));

        // Check that tokens are burned
        assertEq(_metricToken.balanceOf(0x000000000000000000000000000000000000dEaD), _costController.getActionCost(ACTION.CHALLENGE_BURN));

        // Check that you cannot interact with the challenge as user
        vm.prank(other2);
        vm.expectRevert(QuestionAPI.CannotVoteForOwnQuestion.selector);
        _questionAPI.upvoteQuestion(challengeId);

        vm.prank(other2);
        vm.expectRevert(QuestionStateController.InvalidStateTransition.selector);
        _questionAPI.unvoteQuestion(challengeId);

        vm.prank(other2);
        vm.expectRevert(Vault.QuestionNotPublished.selector);
        _questionAPI.withdrawFromVault(challengeId, STAGE.CREATE_AND_VOTE);

        // You cannot publish question yourself
        vm.prank(other2);
        vm.expectRevert(NFTLocked.DoesNotHold.selector);
        _questionAPI.publishChallenge(challengeId, 25, 1e18);

        vm.prank(other);
        _questionAPI.publishChallenge(challengeId, 25, 1e18);
        assertEq(uint256(_questionStateController.getState(challengeId)), uint256(STATE.PUBLISHED));

        // Still cannot withdraw
        vm.prank(other2);
        vm.expectRevert(Vault.NotTheDepositor.selector);
        _questionAPI.withdrawFromVault(challengeId, STAGE.CREATE_AND_VOTE);

        // Can now claim
        vm.prank(other);
        _questionAPI.claimQuestion(challengeId);
    }

    function test_VerifyEventsEmitted() public {
        console.log("All events should be emitted correctly.");

        vm.startPrank(other);

        // Create a question
        vm.expectEmit(true, true, false, true);
        emit QuestionCreated(1, address(other));
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");

        vm.stopPrank();

        vm.startPrank(other2);
        // Upvote a question
        vm.expectEmit(true, true, false, false);
        emit QuestionUpvoted(1, address(other2));
        _questionAPI.upvoteQuestion(questionId);

        // Unvote a question
        vm.expectEmit(true, true, false, false);
        emit QuestionUnvoted(1, address(other2));
        _questionAPI.unvoteQuestion(questionId);
        vm.stopPrank();

        vm.startPrank(other);
        // Publish the question
        vm.expectEmit(true, true, false, false);
        emit QuestionPublished(questionId, address(other));
        _questionAPI.publishQuestion(questionId, 25, 1e18);

        // Claim the question
        vm.expectEmit(true, true, false, false);
        emit QuestionClaimed(questionId, address(other));
        _questionAPI.claimQuestion(questionId);

        // Question answered
        vm.stopPrank();

        // Create challenge
        vm.expectEmit(true, true, false, false);
        emit ChallengeCreated(2, address(manager));
        vm.prank(manager);
        _questionAPI.createChallenge("ipfs://XYZ", 5, 1e18);

        // Disqualify question
        vm.expectEmit(true, false, false, false);
        emit QuestionDisqualified(questionId, address(owner));
        vm.prank(owner);
        _questionAPI.disqualifyQuestion(questionId);
    }

    // ---------------------- Access control tests ----------------------
    function test_OnlyAdminCanPublishQuestion() public {
        console.log("Only the admin should be able to publish a question.");

        vm.prank(other);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");
        vm.prank(owner);
        _questionAPI.toggleLock();

        // Attempt to publish the question
        vm.prank(other2);
        vm.expectRevert(NFTLocked.DoesNotHold.selector);
        _questionAPI.publishQuestion(questionId, 25, 1e18);

        vm.prank(other);
        _questionAPI.publishQuestion(questionId, 25, 1e18);
    }

    function test_OnlyOwnerCanMintPermissionedNFTs() public {
        console.log("Only the owner should be able to mint permissioned NFTs.");

        vm.prank(other);
        vm.expectRevert("Ownable: caller is not the owner");
        _questionAPI.addHolderRole(ADMIN_ROLE, address(0));
    }

    function test_OnlyManagerCanDirectlyCreateChallenge() public {
        console.log("Only the manager should be able to directly create a challenge.");

        vm.prank(other);
        vm.expectRevert(NFTLocked.DoesNotHold.selector);
        _questionAPI.createChallenge("ipfs://XYZ", 5, 1e18);
    }

    function test_FunctionLock() public {
        console.log("All locked functions should be locked.");

        vm.prank(owner);
        _questionAPI.toggleLock();

        vm.startPrank(other);
        uint256 q = _questionAPI.createQuestion("ipfs://XYZ");
        _questionAPI.publishQuestion(q, 25, 1e18);

        vm.expectRevert(FunctionLocked.FunctionIsLocked.selector);
        _questionAPI.answerQuestion(q, "ipfs://XYZ");

        vm.stopPrank();
    }

    function test_RunningNonExistantQuestionIdsDoesNotHurt() public {
        console.log("Running non existant question ids should not hurt.");

        // Doesnt hold nft roles
        vm.prank(other2);

        vm.expectRevert(QuestionStateController.InvalidStateTransition.selector);
        _questionAPI.upvoteQuestion(777);

        vm.expectRevert(QuestionStateController.InvalidStateTransition.selector);
        _questionAPI.unvoteQuestion(777);

        vm.expectRevert(NFTLocked.DoesNotHold.selector);
        _questionAPI.publishQuestion(777, 25, 1e18);

        vm.expectRevert(NFTLocked.DoesNotHold.selector);
        _questionAPI.publishChallenge(777, 25, 1e18);

        vm.expectRevert(QuestionAPI.ClaimsNotOpen.selector);
        _questionAPI.claimQuestion(777);

        vm.expectRevert("Ownable: caller is not the owner");
        _questionAPI.disqualifyQuestion(777);
        vm.stopPrank();

        // Holds nft roles
        vm.prank(other);
        vm.expectRevert(QuestionStateController.InvalidStateTransition.selector);
        _questionAPI.publishQuestion(777, 25, 1e18);

        vm.prank(other);
        vm.expectRevert(QuestionStateController.InvalidStateTransition.selector);
        _questionAPI.publishChallenge(777, 25, 1e18);
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert(QuestionAPI.QuestionDoesNotExist.selector);
        _questionAPI.disqualifyQuestion(777);
    }

    function test_AutomaticWithdrawalsWorkAndUsersCannotWithdrawTwice() public {
        console.log("Automatic withdrawals should work and users cannot withdraw twice.");

        // Create a question
        vm.prank(other);
        uint256 q = _questionAPI.createQuestion("ipfs://XYZ");

        // Balance before
        assertEq(_metricToken.balanceOf(other2), 100e18);

        // Unvote a question
        vm.startPrank(other2);
        _questionAPI.upvoteQuestion(q);
        _questionAPI.unvoteQuestion(q);

        // Balance updated
        assertEq(_metricToken.balanceOf(other2), 100e18);

        // Nothing to withdraw
        vm.expectRevert(Vault.NoMetricDeposited.selector);
        _questionAPI.withdrawFromVault(q, STAGE.UNVOTE);
        vm.stopPrank();

        // Publish question
        vm.prank(other);
        _questionAPI.publishQuestion(q, 25, 1e18);

        // Do same for claiming and releasing claim
        vm.startPrank(other2);
        _questionAPI.claimQuestion(q);
        _questionAPI.releaseClaim(q);

        // Balance updated
        assertEq(_metricToken.balanceOf(other2), 100e18);

        // Nothing to withdraw
        vm.expectRevert(Vault.NoMetricDeposited.selector);
        _questionAPI.withdrawFromVault(q, STAGE.RELEASE_CLAIM);
        vm.stopPrank();
    }
}
