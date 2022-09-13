// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../Helpers/QuickSetup.sol";

contract ClaimTest is QuickSetup {
    function setUp() public {
        quickSetup();
    }

    // ---------------------- General tests ----------------------

    function test_CannotClaimQuestionThatIsNotPublished() public {
        console.log("A user shouldnt be able to claim an unpublished question");

        vm.startPrank(other);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");

        // Attempt claim
        vm.expectRevert(ApiEventsAndErrors.ClaimsNotOpen.selector);
        _questionAPI.claimQuestion(questionId);
        vm.stopPrank();
    }

    function test_CannotClaimMoreThanTheClaimLimit() public {
        console.log("A user shouldnt be able to claim a question that has reached its limit");

        vm.startPrank(other);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");

        // Publish the question
        _questionAPI.publishQuestion(questionId, 1, 1e18);

        // Attempt claim
        _questionAPI.claimQuestion(questionId);

        vm.stopPrank();

        vm.startPrank(other2);

        // Attempt claim again
        vm.expectRevert(ClaimEventsAndErrors.ClaimLimitReached.selector);
        _questionAPI.claimQuestion(questionId);
    }

    function test_UserCannotClaimQuestionMultipleTimes() public {
        vm.startPrank(other);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");

        // Publish the question
        _questionAPI.publishQuestion(questionId, 25, 1e18);

        // Claim the question
        _questionAPI.claimQuestion(questionId);

        // Same user tries to claim again
        vm.expectRevert(ClaimEventsAndErrors.AlreadyClaimed.selector);
        _questionAPI.claimQuestion(questionId);

        vm.stopPrank();
    }

    function test_verifyClaimingAccounting() public {
        vm.startPrank(other);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");

        // Publish the question
        _questionAPI.publishQuestion(questionId, 25, 1e18);

        // Verify that everything is updated correctly
        _claimController.getClaimDataForUser(questionId, other);

        // Claim the question
        _questionAPI.claimQuestion(questionId);

        // Verify that everything is updated correctly
        _claimController.getClaimDataForUser(questionId, other);

        vm.stopPrank();

        vm.startPrank(other2);

        _claimController.getClaimDataForUser(questionId, other2);
        _questionAPI.claimQuestion(questionId);

        // Verify that everything is updated correctly
        _claimController.getClaimDataForUser(questionId, other2);
    }

    function test_ClaimReleaseClaim() public {
        console.log("A user should be able to release their claim after claiming.");

        vm.startPrank(other);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");
        _questionAPI.publishQuestion(questionId, 25, 1e18);
        vm.stopPrank();

        vm.startPrank(other2);
        assertEq(_metricToken.balanceOf(other2), 100e18);

        // Claim the question
        _questionAPI.claimQuestion(questionId);
        assertEq(uint256(_claimController.getQuestionClaimState(questionId, other2)), uint256(CLAIM_STATE.CLAIMED));
        assertEq(_metricToken.balanceOf(other2), 99e18);

        // Release the claim
        _questionAPI.releaseClaim(questionId);
        assertEq(uint256(_claimController.getQuestionClaimState(questionId, other2)), uint256(CLAIM_STATE.RELEASED));

        _vault.withdrawMetric(questionId, STAGE.RELEASE_CLAIM);
        assertEq(_metricToken.balanceOf(other2), 100e18);

        _questionAPI.claimQuestion(questionId);
        assertEq(uint256(_claimController.getQuestionClaimState(questionId, other2)), uint256(CLAIM_STATE.CLAIMED));
        assertEq(_metricToken.balanceOf(other2), 99e18);

        vm.stopPrank();
    }

    function test_ClaimTryWithdrawWithoutRelease() public {
        console.log("A user should only be able to try to withdraw their claim after releasing.");

        vm.startPrank(other);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");
        _questionAPI.publishQuestion(questionId, 25, 1e18);
        vm.stopPrank();

        vm.startPrank(other2);
        assertEq(_metricToken.balanceOf(other2), 100e18);

        // Claim the question
        _questionAPI.claimQuestion(questionId);
        assertEq(uint256(_claimController.getQuestionClaimState(questionId, other2)), uint256(CLAIM_STATE.CLAIMED));
        assertEq(_metricToken.balanceOf(other2), 99e18);

        vm.expectRevert(VaultEventsAndErrors.ClaimNotReleased.selector);
        _vault.withdrawMetric(questionId, STAGE.RELEASE_CLAIM);

        vm.stopPrank();
    }

    function test_CannotClaimIfLowerThanThreshold() public {
        console.log("A user shouldnt be able to claim a question if they have less than the threshold.");

        vm.startPrank(other);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");
        _questionAPI.publishQuestion(questionId, 25, 777777777e18);
        vm.stopPrank();

        vm.startPrank(other2);
        assertEq(_metricToken.balanceOf(other2), 100e18);

        assertTrue(_metricToken.balanceOf(other2) < 777777777e18);

        // Claim the question
        vm.expectRevert(TokenBar.NotEnoughTokens.selector);
        _questionAPI.claimQuestion(questionId);

        vm.stopPrank();
    }

    // ---------------------- Access control tests ----------------------
}
