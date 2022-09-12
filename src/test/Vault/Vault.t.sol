// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../Helpers/QuickSetup.sol";

contract VaultTest is QuickSetup {
    function setUp() public {
        quickSetup();

        vm.prank(owner);
        _mockAuthNFTAdmin.mintTo(owner);
    }

    // ---------------------- General tests ----------------------

    function test_lockMetric() public {
        console.log("Should lock Metric.");

        vm.startPrank(other);
        // Create a question and see that it is created and balance is updated.
        _metricToken.approve(address(_vault), 100e18);
        _questionAPI.createQuestion("ipfs://XYZ");
        assertEq(_vault.getMetricTotalLockedBalance(), 100e16);
        vm.stopPrank();
    }

    function test_lockMetricForSecondQuestion() public {
        console.log("Should have double the locked Metric with second deposit.");

        vm.startPrank(other);
        // Create 1st question
        _metricToken.approve(address(_vault), 100e18);
        _questionAPI.createQuestion("ipfs://XYZ");

        // Create 2nd question
        _questionAPI.createQuestion("ipfs://XYZ");
        assertEq(_vault.getMetricTotalLockedBalance(), 200e16);

        vm.stopPrank();
    }

    function test_withdrawMetric() public {
        console.log("Should withdraw Metric");
        vm.startPrank(other);

        // Create question
        _metricToken.approve(address(_vault), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");

        // Publish question
        _questionAPI.publishQuestion(questionId, 25, 1e18);

        //withdraw Metric
        _vault.withdrawMetric(questionId, STAGE.CREATE_AND_VOTE);
        assertEq(_vault.getMetricTotalLockedBalance(), 0);
        vm.stopPrank();
    }

    // function test_slashMetric() public {
    //     console.log("Should slash question when appropriate");
    //     vm.startPrank(other);
    //     // Create question
    //     _metricToken.approve(address(_vault), 100e18);
    //     uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");
    //     vm.stopPrank();

    //     //slash Metric
    //     vm.startPrank(owner);
    //     _vault.slashMetric(questionId);
    //     vm.stopPrank();

    //     // Check that Metric is slashed
    //     assertEq(_metricToken.balanceOf(other), 99.5e18);
    //     // Check treasury Metric balance
    //     assertEq(_metricToken.balanceOf(treasury), 0.5e18);
    // }

    // function test_onlyOwnerCanSlashMetric() public {
    //     console.log("Only owner should be able to slash a question");

    //     vm.startPrank(other);
    //     // Create question
    //     _metricToken.approve(address(_vault), 100e18);
    //     uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");

    //     //slash Metric
    //     vm.expectRevert("Ownable: caller is not the owner");
    //     _vault.slashMetric(questionId);
    //     vm.stopPrank();
    // }

    // function test_cannotSlashSameQuestionTwice() public {
    //     console.log("We can only slash a question once.");

    //     vm.startPrank(other);
    //     // Create question
    //     _metricToken.approve(address(_vault), 100e18);
    //     uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");
    //     vm.stopPrank();

    //     vm.startPrank(owner);
    //     // Slash
    //     _vault.slashMetric(questionId);

    //     // Slash again
    //     vm.expectRevert(Vault.AlreadySlashed.selector);
    //     _vault.slashMetric(questionId);
    //     vm.stopPrank();
    // }

    function test_cannotWithdrawUnpublishedQuestion() public {
        console.log("Should not withdraw Metric");
        vm.startPrank(other);

        // Create question
        _metricToken.approve(address(_vault), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");

        //withdraw Metric
        vm.expectRevert(Vault.QuestionNotPublished.selector);
        _vault.withdrawMetric(questionId, STAGE.CREATE_AND_VOTE);
        vm.stopPrank();
    }

    function test_cannotWithdrawSameQuestionTwice() public {
        console.log("Should not withdraw Metric twice");
        vm.startPrank(other);

        // Create question
        _metricToken.approve(address(_vault), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");

        // Publish question
        _questionAPI.publishQuestion(questionId, 25, 1e18);

        // Withdraw Metric
        _vault.withdrawMetric(questionId, STAGE.CREATE_AND_VOTE);

        // Withdraw again
        vm.expectRevert(Vault.NoMetricDeposited.selector);
        _vault.withdrawMetric(questionId, STAGE.CREATE_AND_VOTE);

        vm.stopPrank();
    }

    function test_StageVaultAccountingIsCorrect() public {
        console.log("Stage Vault Accounting is correct");
        vm.startPrank(other);

        // Create question
        _metricToken.approve(address(_vault), 100e18);
        uint256 questionIdOne = _questionAPI.createQuestion("ipfs://XYZ");

        // Verify total vault balance is correct
        assertEq(_vault.getMetricTotalLockedBalance(), 1e18);

        // Verify that question vault balance is correct
        assertEq(_vault.getLockedMetricByQuestion(questionIdOne), 1e18);

        // Verify that the right properties are set on the question
        assertEq(_vault.getUserFromProperties(questionIdOne, STAGE.CREATE_AND_VOTE, other), other);
        assertEq(_vault.getAmountFromProperties(questionIdOne, STAGE.CREATE_AND_VOTE, other), 1e18);

        // Verify that other stages arent updated
        assertEq(_vault.getUserFromProperties(questionIdOne, STAGE.CLAIM_AND_ANSWER, other), address(0x0));
        assertEq(_vault.getUserFromProperties(questionIdOne, STAGE.REVIEW, other), address(0x0));

        assertEq(_vault.getAmountFromProperties(questionIdOne, STAGE.CLAIM_AND_ANSWER, other), 0);
        assertEq(_vault.getAmountFromProperties(questionIdOne, STAGE.REVIEW, other), 0);
        vm.stopPrank();

        // Repeat the same for second user
        vm.startPrank(other2);

        // Create question
        _metricToken.approve(address(_vault), 100e18);
        uint256 questionIdTwo = _questionAPI.createQuestion("ipfs://XYZ");

        // Verify total vault balance is correct
        assertEq(_vault.getMetricTotalLockedBalance(), 2e18);

        // Verify that question vault balance is correct
        assertEq(_vault.getLockedMetricByQuestion(questionIdTwo), 1e18);

        // Verify that the right properties are set on the question
        assertEq(_vault.getUserFromProperties(questionIdTwo, STAGE.CREATE_AND_VOTE, other2), other2);
        assertEq(_vault.getAmountFromProperties(questionIdTwo, STAGE.CREATE_AND_VOTE, other2), 1e18);

        // Verify that other stages arent updated
        assertEq(_vault.getUserFromProperties(questionIdTwo, STAGE.CLAIM_AND_ANSWER, other2), address(0x0));
        assertEq(_vault.getUserFromProperties(questionIdTwo, STAGE.REVIEW, other2), address(0x0));

        assertEq(_vault.getAmountFromProperties(questionIdTwo, STAGE.CLAIM_AND_ANSWER, other2), 0);
        assertEq(_vault.getAmountFromProperties(questionIdTwo, STAGE.REVIEW, other2), 0);
        vm.stopPrank();
        vm.stopPrank();

        // Introduce a voter
        vm.startPrank(other3);

        _metricToken.approve(address(_vault), 100e18);

        _questionAPI.upvoteQuestion(questionIdOne);
        _questionAPI.upvoteQuestion(questionIdTwo);

        // Verify that total vault balance is updated
        assertEq(_vault.getMetricTotalLockedBalance(), 4e18);

        // Verify that question vault balance is correct
        assertEq(_vault.getLockedMetricByQuestion(questionIdOne), 2e18);
        assertEq(_vault.getLockedMetricByQuestion(questionIdTwo), 2e18);

        // Verify that the right properties are set on the question
        assertEq(_vault.getUserFromProperties(questionIdOne, STAGE.CREATE_AND_VOTE, other3), other3);
        assertEq(_vault.getAmountFromProperties(questionIdOne, STAGE.CREATE_AND_VOTE, other3), 1e18);

        assertEq(_vault.getUserFromProperties(questionIdTwo, STAGE.CREATE_AND_VOTE, other3), other3);
        assertEq(_vault.getAmountFromProperties(questionIdTwo, STAGE.CREATE_AND_VOTE, other3), 1e18);

        // Verify that others arent updated
        assertEq(_vault.getUserFromProperties(questionIdOne, STAGE.CREATE_AND_VOTE, other), other);
        assertEq(_vault.getAmountFromProperties(questionIdOne, STAGE.CREATE_AND_VOTE, other), 1e18);

        assertEq(_vault.getUserFromProperties(questionIdTwo, STAGE.CREATE_AND_VOTE, other2), other2);
        assertEq(_vault.getAmountFromProperties(questionIdTwo, STAGE.CREATE_AND_VOTE, other2), 1e18);
        vm.stopPrank();

        // Publish the questions
        vm.prank(owner);
        _questionAPI.publishQuestion(questionIdOne, 25, 1e18);
        vm.prank(owner);
        _questionAPI.publishQuestion(questionIdTwo, 25, 1e18);

        // Verify that everyone can withdraw and accounting is done properly.
        vm.prank(other);
        _vault.withdrawMetric(questionIdOne, STAGE.CREATE_AND_VOTE);

        // Shouldn't have anything to withdraw here
        vm.prank(other);
        vm.expectRevert(Vault.NotTheDepositor.selector);
        _vault.withdrawMetric(questionIdTwo, STAGE.CREATE_AND_VOTE);

        // Check everything is updated correctly
        // Should decrease by 1e18
        assertEq(_vault.getMetricTotalLockedBalance(), 3e18);
        assertEq(_vault.getLockedMetricByQuestion(questionIdOne), 1e18);

        // Should remain the same
        assertEq(_vault.getLockedMetricByQuestion(questionIdTwo), 2e18);

        // Should be cleared
        assertEq(_vault.getUserFromProperties(questionIdOne, STAGE.CREATE_AND_VOTE, other), other);
        assertEq(_vault.getAmountFromProperties(questionIdOne, STAGE.CREATE_AND_VOTE, other), 0);

        // Other users also withdraw
        vm.prank(other2);
        _vault.withdrawMetric(questionIdTwo, STAGE.CREATE_AND_VOTE);

        vm.prank(other3);
        _vault.withdrawMetric(questionIdOne, STAGE.CREATE_AND_VOTE);

        vm.prank(other3);
        _vault.withdrawMetric(questionIdTwo, STAGE.CREATE_AND_VOTE);

        // Check everything is updated correctly
        // Should decrease by 3e18
        assertEq(_vault.getMetricTotalLockedBalance(), 0);
        assertEq(_vault.getLockedMetricByQuestion(questionIdOne), 0);

        // Should remain the same
        assertEq(_vault.getLockedMetricByQuestion(questionIdTwo), 0);

        // Should be cleared
        assertEq(_vault.getAmountFromProperties(questionIdOne, STAGE.CREATE_AND_VOTE, other), 0);
        assertEq(_vault.getAmountFromProperties(questionIdOne, STAGE.CREATE_AND_VOTE, other3), 0);

        assertEq(_vault.getAmountFromProperties(questionIdTwo, STAGE.CREATE_AND_VOTE, other2), 0);
        assertEq(_vault.getAmountFromProperties(questionIdTwo, STAGE.CREATE_AND_VOTE, other3), 0);

        assertEq(_metricToken.balanceOf(other), 100e18);
        assertEq(_metricToken.balanceOf(other2), 100e18);
        assertEq(_metricToken.balanceOf(other3), 100e18);
    }

    function test_WithdrawAfterUnvoting() public {
        console.log("A user should be able to withdraw their funds after unvoting.");

        vm.startPrank(other);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");
        vm.stopPrank();

        vm.startPrank(other2);

        // Vote for the question
        _questionAPI.upvoteQuestion(questionId);
        assertEq(_metricToken.balanceOf(other2), 99e18);

        // Unvote the question
        _questionAPI.unvoteQuestion(questionId);

        // Verify balance updates
        _vault.withdrawMetric(questionId, STAGE.UNVOTE);

        assertEq(_metricToken.balanceOf(other2), 100e18);
        vm.stopPrank();

        vm.startPrank(other3);
        // Vote for the question
        _questionAPI.upvoteQuestion(questionId);
        assertEq(_metricToken.balanceOf(other3), 99e18);

        // Verify user cannot withdraw funds
        vm.expectRevert(Vault.UserHasNotUnvoted.selector);
        _vault.withdrawMetric(questionId, STAGE.UNVOTE);

        vm.stopPrank();
    }

    function test_withdrawAfterClaiming() public {
        console.log("A user should be able to withdraw their funds after claiming.");

        vm.startPrank(other);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");
        _questionAPI.publishQuestion(questionId, 25, 1e18);
        vm.stopPrank();

        vm.startPrank(other2);
        // Claim the question
        _questionAPI.claimQuestion(questionId);

        // Verify balance updates
        assertEq(_metricToken.balanceOf(other2), 99e18);
        assertEq(_vault.getMetricTotalLockedBalance(), 2e18);

        // Make sure we cant withdraw without question being in review.
        vm.expectRevert(Vault.QuestionNotInReview.selector);
        _vault.withdrawMetric(questionId, STAGE.CLAIM_AND_ANSWER);

        // Make sure we cant withdraw without the question first being released.
        vm.expectRevert(Vault.ClaimNotReleased.selector);
        _vault.withdrawMetric(questionId, STAGE.RELEASE_CLAIM);

        // Release the claim
        _questionAPI.releaseClaim(questionId);

        // Withdraw
        _vault.withdrawMetric(questionId, STAGE.RELEASE_CLAIM);

        // Verify balance updates
        assertEq(_metricToken.balanceOf(other2), 100e18);
        assertEq(_vault.getMetricTotalLockedBalance(), 1e18);
        vm.stopPrank();
    }

    // ---------------------- Access control tests ----------------------
    function test_onlyOwnerCanSetSensitiveAddresses() public {
        console.log("Only owner should be able to set sensitive addresses");

        vm.startPrank(other);

        vm.expectRevert("Ownable: caller is not the owner");
        _vault.setTreasury(address(0x1));

        vm.stopPrank();

        vm.startPrank(owner);
        _vault.setTreasury(address(0x1));

        assertEq(_vault.treasury(), address(0x1));
    }
}
